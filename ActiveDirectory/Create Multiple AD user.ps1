# Creates disabled accounts only. Activate separately after access/secret review.
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$true)][string]$ExcelPath,
    [Parameter(Mandatory=$true)][string]$Server,
    [Parameter(Mandatory=$true)][string]$OU,
    [Parameter(Mandatory=$true)][string]$UpnSuffix,
    [switch]$Execute,
    [scriptblock]$PasswordProvider
)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module ImportExcel -ErrorAction Stop
$domain=Get-ADDomain -Server $Server -ErrorAction Stop
$forest=Get-ADForest -Server $Server -ErrorAction Stop
if ((@($domain.DNSRoot)+@($forest.UPNSuffixes)) -notcontains $UpnSuffix) { throw 'UPN suffix is not approved in this forest.' }
$null=Get-ADOrganizationalUnit -Identity $OU -Server $Server -ErrorAction Stop
$data=@(Import-Excel -Path $ExcelPath -ErrorAction Stop)
if (-not $data.Count) { throw 'Workbook has no rows.' }
if (@($data | Where-Object { $_.PSObject.Properties.Name -contains 'Password' }).Count) { throw 'Remove the plaintext Password column. Use PasswordProvider returning SecureString.' }
$plan=New-Object 'System.Collections.Generic.List[object]'; $seen=@{}
foreach ($row in $data) {
    $sam=(([string]$row.FirstName)+'.'+([string]$row.LastName)).ToLowerInvariant()
    if (-not $row.FirstName -or -not $row.LastName -or $sam -notmatch '^[a-z0-9][a-z0-9._-]{0,19}$' -or $seen.ContainsKey($sam)) { throw "Invalid or duplicate username: $sam" }
    $seen[$sam]=$true; $upn="$sam@$UpnSuffix"
    # Values are validated before filter interpolation. Escape the UPN literal.
    $escapedUpn=$upn.Replace("'","''")
    $existing=@(Get-ADUser -Filter "SamAccountName -eq '$sam' -or UserPrincipalName -eq '$escapedUpn'" -Server $Server -ErrorAction Stop)
    if ($existing.Count) { throw "Account already exists; no changes made: $sam" }
    $groups=@()
    foreach ($g in (([string]$row.Groups) -split ';')) {
        if ($g.Trim()) { $groups+= (Get-ADGroup -Identity $g.Trim() -Server $Server -ErrorAction Stop).ObjectGUID }
    }
    $plan.Add([pscustomobject]@{SamAccountName=$sam;UPN=$upn;FirstName=[string]$row.FirstName;LastName=[string]$row.LastName;Groups=@($groups | Select-Object -Unique);OU=$OU;Enabled=$false})
}
if (-not $Execute) { $plan; return }
if (-not $PasswordProvider) { throw 'Execution requires PasswordProvider returning SecureString.' }
foreach ($p in $plan) {
    if ($PSCmdlet.ShouldProcess($p.SamAccountName,'Create disabled account and assign reviewed groups')) {
        $secret=& $PasswordProvider $p.SamAccountName
        if ($secret -isnot [Security.SecureString] -or $secret.Length -eq 0) { throw 'PasswordProvider must return one nonempty SecureString.' }
        try {
            $new=New-ADUser -Name ($p.FirstName+' '+$p.LastName) -GivenName $p.FirstName -Surname $p.LastName -SamAccountName $p.SamAccountName -UserPrincipalName $p.UPN -Path $OU -Server $Server -AccountPassword $secret -Enabled $false -ChangePasswordAtLogon $true -PassThru -ErrorAction Stop
            if (-not $new.ObjectGUID) { throw 'Creation returned no immutable identity; group assignment stopped.' }
            foreach ($g in $p.Groups) { Add-ADGroupMember -Identity $g -Members $new.ObjectGUID -Server $Server -ErrorAction Stop }
            [pscustomobject]@{SamAccountName=$p.SamAccountName;ObjectGUID=$new.ObjectGUID;Status='CreatedDisabled'}
        } finally { $secret=$null }
    }
}
