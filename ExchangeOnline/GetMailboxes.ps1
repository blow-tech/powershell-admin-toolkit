# Canonical mailbox inventory. Existing expected-tenant session required.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][guid]$TenantId,[Parameter(Mandatory=$true)][string]$OutputPath,
    [ValidateSet('UserMailbox','SharedMailbox','RoomMailbox','EquipmentMailbox')][string[]]$RecipientTypeDetails=@())
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/common/ReportSafety.ps1')
Assert-ExchangeTenant $TenantId
$argsExo=@{ResultSize='Unlimited';ErrorAction='Stop';Properties=@('EmailAddresses')}
if ($RecipientTypeDetails.Count) { $argsExo.RecipientTypeDetails=$RecipientTypeDetails }
$rows=@(Get-EXOMailbox @argsExo | Select-Object DisplayName,UserPrincipalName,ExternalDirectoryObjectId,RecipientTypeDetails,PrimarySmtpAddress,@{n='EmailAddresses';e={$_.EmailAddresses -join ';'}})
Export-NewReport $rows $OutputPath
[pscustomobject]@{Status='Complete';Count=$rows.Count;OutputPath=$OutputPath;TenantId=$TenantId}
