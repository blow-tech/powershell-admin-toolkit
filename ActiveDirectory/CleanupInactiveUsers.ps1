<#
Read-only inactivity plan by default. Replaces the earlier AdminDroid community
cleanup implementation; attribution remains in repository history.
Missing observations are UNKNOWN and never eligible for mutation. Even complete
lastLogon observations do not prove a service or privileged account is unused.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$true)][string]$Server,
    [Parameter(Mandatory=$true)][Alias('OU')][string]$SearchBase,
    [Parameter(Mandatory=$true)][ValidateRange(1,36500)][int]$InactiveDays,
    [guid[]]$ExcludeGuid=@(),
    [ValidateSet('Report','Disable','Move','Delete')][string]$Action='Report',
    [string]$MoveToOU,
    [string]$ManifestPath,
    [ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ManifestSha256
)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
function Get-InactivityPlan {
    param([string]$Server,[string]$SearchBase,[int]$InactiveDays,[guid[]]$ExcludeGuid)
    $now=[datetime]::UtcNow; $cutoff=$now.AddDays(-$InactiveDays)
    $dcs=@(Get-ADDomainController -Filter * -Server $Server -ErrorAction Stop)
    if (-not $dcs.Count -or @($dcs | Where-Object { -not $_.HostName }).Count) { throw 'Incomplete DC discovery.' }
    $names=@($dcs.HostName | Sort-Object -Unique)
    if ($names.Count -ne $dcs.Count) { throw 'Ambiguous DC discovery.' }
    $users=@(Get-ADUser -Filter * -Server $Server -SearchBase $SearchBase -Properties whenCreated,adminCount,servicePrincipalName -ErrorAction Stop)
    $observations=@{}
    foreach ($dc in $names) {
        # Buffer each complete DC result before accepting any evidence.
        $rows=@(Get-ADUser -Filter * -Server $dc -SearchBase $SearchBase -Properties lastLogon -ErrorAction Stop)
        $map=@{}
        foreach ($u in $rows) {
            $id=[string]$u.ObjectGUID
            if (-not $id -or $map.ContainsKey($id)) { throw "Ambiguous identity returned by $dc" }
            $map[$id]=$u.lastLogon
        }
        $observations[$dc]=$map
    }
    foreach ($u in $users) {
        $id=[string]$u.ObjectGUID; $times=@(); $complete=$true
        foreach ($dc in $names) {
            if (-not $observations[$dc].ContainsKey($id) -or $null -eq $observations[$dc][$id]) { $complete=$false; continue }
            try {
                $v=[long]$observations[$dc][$id]
                if ($v -lt 0) { throw 'Negative timestamp' }
                if ($v -gt 0) { $times+=([datetime]::FromFileTimeUtc($v)) }
            } catch { $complete=$false }
        }
        $last=$times | Sort-Object -Descending | Select-Object -First 1
        $reason='Eligible'
        if (-not $complete -or -not $last -or $last -gt $now) { $reason='UNKNOWN' }
        elseif (-not $u.whenCreated -or ([datetime]$u.whenCreated).ToUniversalTime() -ge $cutoff -or $last -ge $cutoff) { $reason='Recent' }
        elseif ($u.adminCount -eq 1 -or @($u.servicePrincipalName).Count -gt 0 -or $ExcludeGuid -contains [guid]$u.ObjectGUID -or [string]$u.SID -match '-(500|501|502)$') { $reason='Excluded' }
        [pscustomobject]@{ObjectGUID=$id;SamAccountName=$u.SamAccountName;DistinguishedName=$u.DistinguishedName;Enabled=$u.Enabled;LastLogonUtc=$last;Status=$reason;DomainControllers=($names -join ';')}
    }
}
$null=Get-ADOrganizationalUnit -Identity $SearchBase -Server $Server -ErrorAction Stop
$plan=@(Get-InactivityPlan $Server $SearchBase $InactiveDays $ExcludeGuid)
if ($Action -eq 'Report') { $plan; return }
if (-not $ManifestPath -or -not $ManifestSha256) { throw 'Execution requires a reviewed CSV manifest and its SHA256.' }
# Read exactly the bytes that are hashed, avoiding separate hash/import reads.
$bytes=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $ManifestPath).ProviderPath)
$sha=[Security.Cryptography.SHA256]::Create()
try { $hash=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') } finally { $sha.Dispose() }
if ($hash -ne $ManifestSha256) { throw 'Manifest digest mismatch.' }
$approved=@([Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) | ConvertFrom-Csv)
if (-not $approved.Count) { throw 'Manifest is empty.' }
$selected=New-Object 'System.Collections.Generic.List[object]'; $seen=@{}
foreach ($row in $approved) {
    $id=([guid]$row.ObjectGUID).ToString()
    if ($seen.ContainsKey($id)) { throw 'Duplicate GUID in manifest.' }; $seen[$id]=$true
    $match=@($plan | Where-Object { $_.ObjectGUID -eq $id -and $_.Status -eq 'Eligible' })
    if ($match.Count -ne 1) { throw "Manifest identity is not currently eligible: $id" }
    $selected.Add($match[0])
}
if ($Action -eq 'Move') {
    if (-not $MoveToOU) { throw 'Move requires MoveToOU.' }
    $null=Get-ADOrganizationalUnit -Identity $MoveToOU -Server $Server -ErrorAction Stop
}
foreach ($u in $selected) {
    if ($PSCmdlet.ShouldProcess($u.ObjectGUID,"$Action inactive user")) {
        switch ($Action) {
            'Disable' { Disable-ADAccount -Identity ([guid]$u.ObjectGUID) -Server $Server -ErrorAction Stop }
            'Move' { Move-ADObject -Identity ([guid]$u.ObjectGUID) -TargetPath $MoveToOU -Server $Server -ErrorAction Stop }
            'Delete' { Remove-ADUser -Identity ([guid]$u.ObjectGUID) -Server $Server -Confirm:$false -ErrorAction Stop }
        }
        [pscustomobject]@{ObjectGUID=$u.ObjectGUID;Action=$Action;Status='CommandSucceeded'}
    }
}
