<# Read-only evidence from one explicit DC and search base. BadPwdCount is DC-local,
not proof of a bad password or a complete forest-wide lockout assessment. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server,[Parameter(Mandatory)][string]$SearchBase)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
Get-ADUser -Server $Server -SearchBase $SearchBase -Filter * -Properties BadPwdCount,LastBadPasswordAttempt,LockedOut,pwdLastSet -ErrorAction Stop |
 Where-Object {$_.BadPwdCount -ge 1 -or $_.pwdLastSet -eq 0} |
 Select-Object ObjectGUID,SamAccountName,Name,BadPwdCount,LastBadPasswordAttempt,LockedOut,pwdLastSet,DistinguishedName,@{n='ObservationServer';e={$Server}}
