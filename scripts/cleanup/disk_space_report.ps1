<# Read-only disk evidence; CSV replaces the unsafe legacy HTML graph. Requires CIM access.
New OutputPath in an existing protected parent. Missing/invalid evidence aborts publication. #>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateCount(1,32)][string[]]$ComputerName,[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'common/ReportSafety.ps1')
$rows=@(foreach($computer in ($ComputerName | Sort-Object -Unique)){
 $disks=@(Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $computer -Filter 'DriveType=3' -OperationTimeoutSec 30 -ErrorAction Stop)
 if(-not $disks.Count){throw "UNKNOWN: no fixed disks returned for $computer"}
 foreach($d in $disks){
  if($null -eq $d.Size -or $d.Size -le 0 -or $null -eq $d.FreeSpace -or $d.FreeSpace -lt 0 -or $d.FreeSpace -gt $d.Size){throw "UNKNOWN: invalid capacity for $computer $($d.DeviceID)"}
  [pscustomobject]@{ComputerName=$computer;DeviceID=$d.DeviceID;SizeBytes=$d.Size;FreeBytes=$d.FreeSpace;FreePercent=[math]::Round(100*$d.FreeSpace/$d.Size,2)}
 }
})
Export-NewReport -Rows $rows -Path $OutputPath
