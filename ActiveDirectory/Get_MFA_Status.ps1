#Requires -Version 5.1
<#
.SYNOPSIS
Graph MFA registration observations, not Conditional Access enforcement.
.DESCRIPTION
Requires an existing expected-tenant session and Microsoft.Graph.Reports with
AuditLog.Read.All plus the appropriate delegated role/application grant.
Disabled users are outside this API's coverage. Registration can be delayed.
No passwords, module installation, interactive popups or session removal.
Replaces the legacy AdminDroid Community MSOnline entry point.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [string]$OutputPath,
    [switch]$UnregisteredOnly
)
$ErrorActionPreference='Stop'
$context=Get-MgContext -ErrorAction Stop
if ($null -eq $context -or $context.TenantId -ne $TenantId.ToString()) {throw 'Connect separately to the expected tenant.'}
if ($context.AuthType -eq 'Delegated' -and $context.Scopes -notcontains 'AuditLog.Read.All') {throw 'AuditLog.Read.All consent and a supported directory role are required.'}
$observed=[datetimeoffset]::UtcNow.ToString('o')
$records=@(Get-MgReportAuthenticationMethodUserRegistrationDetail -All -ErrorAction Stop)
$results=@(foreach ($record in $records) {
    if ($UnregisteredOnly -and $record.IsMfaRegistered -eq $true) {continue}
    [pscustomobject]@{
        UserId=$record.Id;UserPrincipalName=$record.UserPrincipalName;DisplayName=$record.UserDisplayName
        IsMfaRegistered=$record.IsMfaRegistered;IsMfaCapable=$record.IsMfaCapable
        MethodsRegistered=($record.MethodsRegistered -join ';');LastUpdatedDateTime=$record.LastUpdatedDateTime
        ObservedAtUtc=$observed;EnforcementStatus='NotAssessed'
        CollectionState=if ($null -eq $record.IsMfaRegistered) {'UNKNOWN'} else {'Collected'}
    }
})
if ($OutputPath) {
    if (Test-Path -LiteralPath $OutputPath) {throw 'Output already exists; choose a new report path.'}
    $results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
}
$results
Write-Warning 'Registration is not proof of MFA enforcement. Disabled users are not covered; verify report freshness and Conditional Access separately.'
