# Read-only password-age evidence. Missing dates are UNKNOWN; no cleanup eligibility implied.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Server,
 [Parameter(Mandatory=$true)][string]$SearchBase,
 [ValidateRange(1,36500)][int]$MaxAge=180)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
$cutoff=[datetime]::UtcNow.AddDays(-$MaxAge)
Get-ADUser -Server $Server -SearchBase $SearchBase -Filter * -Properties PasswordLastSet,LastLogonDate -ErrorAction Stop |
 Where-Object {-not $_.PasswordLastSet -or $_.PasswordLastSet.ToUniversalTime() -lt $cutoff} |
 Select-Object ObjectGUID,SamAccountName,Enabled,PasswordLastSet,LastLogonDate,@{n='EvidenceState';e={if($_.PasswordLastSet){'PasswordOlderThanCutoff'}else{'UNKNOWN'}}}
