[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Server,[Parameter(Mandatory=$true)][string]$SearchBase,[string]$OutputPath)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
if ($OutputPath -and (Test-Path -LiteralPath $OutputPath)) { throw 'Output already exists.' }
$rows=@(Get-ADComputer -Server $Server -SearchBase $SearchBase -Filter 'OperatingSystem -like "*server*" -and Enabled -eq $true' -Properties OperatingSystem,OperatingSystemVersion,IPv4Address -ErrorAction Stop | Sort-Object OperatingSystem | Select-Object Name,OperatingSystem,OperatingSystemVersion,IPv4Address)
if ($OutputPath) { $rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -NoClobber -Encoding UTF8 -ErrorAction Stop }
$rows
