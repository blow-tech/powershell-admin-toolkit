#Requires -Version 5.1
<# Requires an existing Exchange Online session in the explicitly expected organization. #>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)][string]$CSVPath,
    [Parameter(Mandatory)][guid]$ExpectedTenantId
)
$ErrorActionPreference='Stop'
$organization = @(Get-OrganizationConfig -ErrorAction Stop)
if ($organization.Count -ne 1 -or [string]$organization[0].ExternalDirectoryOrganizationId -ne $ExpectedTenantId.ToString()) { throw 'Exchange tenant mismatch or unavailable session.' }
$rows = @(Import-Csv -LiteralPath $CSVPath -ErrorAction Stop)
if ($rows.Count -eq 0) { throw 'CSV is empty; expected UPN header.' }
$seen=@{}
$plan = foreach ($row in $rows) {
    if ([string]::IsNullOrWhiteSpace($row.UPN) -or $row.UPN -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'Missing/invalid UPN in CSV.' }
    if ($seen.ContainsKey($row.UPN)) { throw "Duplicate UPN: $($row.UPN)" }
    $seen[$row.UPN]=$true
    $mailbox=Get-Mailbox -Identity $row.UPN -ErrorAction Stop
    if ($mailbox.RecipientTypeDetails -notin 'UserMailbox','SharedMailbox') { throw "Unsupported mailbox type: $($row.UPN)" }
    $mailbox
}
foreach ($mailbox in $plan) {
    if ($mailbox.RecipientTypeDetails -eq 'SharedMailbox') { continue }
    if ($PSCmdlet.ShouldProcess("$($mailbox.UserPrincipalName) [$($mailbox.ExchangeGuid)]", 'Convert user mailbox to shared')) {
        Set-Mailbox -Identity $mailbox.ExchangeGuid.ToString() -Type Shared -ErrorAction Stop
        if ((Get-Mailbox -Identity $mailbox.ExchangeGuid.ToString() -ErrorAction Stop).RecipientTypeDetails -ne 'SharedMailbox') { throw 'Mailbox conversion verification failed.' }
        [pscustomobject]@{ Identity=$mailbox.ExchangeGuid; Status='Converted' }
    }
}
