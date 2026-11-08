[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Identity,[Parameter(Mandatory=$true)][string]$Server,[string]$OutputPath,[switch]$Recursive)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
if ($OutputPath -and (Test-Path -LiteralPath $OutputPath)) { throw 'Output already exists.' }
$members=@(Get-ADGroupMember -Identity $Identity -Server $Server -Recursive:$Recursive -ErrorAction Stop | Select-Object Name,SamAccountName,ObjectClass,ObjectGUID,DistinguishedName)
if ($OutputPath) { $members | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -NoClobber -Encoding UTF8 -ErrorAction Stop }
$members
