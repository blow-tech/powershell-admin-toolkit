<# Reports password changes in the requested age window; creation time is not password-change time.
Requires RSAT AD read access. Read-only; no automatic export or implicit domain. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server,[Parameter(Mandatory)][string]$SearchBase,[ValidateRange(1,3650)][int]$Days=30)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
$cutoff=[datetime]::UtcNow.AddDays(-$Days)
Get-ADUser -Server $Server -SearchBase $SearchBase -Filter * -Properties PasswordLastSet,PasswordNeverExpires -ErrorAction Stop |
 Where-Object {$null -ne $_.PasswordLastSet -and $_.PasswordLastSet.ToUniversalTime() -ge $cutoff} |
 Select-Object ObjectGUID,UserPrincipalName,Name,PasswordLastSet,PasswordNeverExpires
