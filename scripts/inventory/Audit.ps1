# Read-only bounded CIM inventory. Windows/WinRM and least-privilege CIM read access required.
# Migrated from legacy WMI/HTML collection; no MSI provider, software installation or event clearing.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateCount(1,32)][string[]]$ComputerName,
 [Parameter(Mandatory=$true)][string]$OutputPath,
 [ValidateRange(5,120)][int]$OperationTimeoutSeconds=30)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../common/ReportSafety.ps1')
function Get-InventoryEvidence {
 param([string[]]$Targets,[int]$TimeoutSeconds)
 $classes=@{
  Win32_OperatingSystem=@('Caption','Version','BuildNumber','LastBootUpTime','TotalVisibleMemorySize','FreePhysicalMemory')
  Win32_ComputerSystem=@('Name','Domain','Manufacturer','Model','TotalPhysicalMemory')
  Win32_Processor=@('Name','NumberOfCores','NumberOfLogicalProcessors')
  Win32_LogicalDisk=@('DeviceID','DriveType','Size','FreeSpace','FileSystem')
  Win32_PhysicalMemory=@('DeviceLocator','Capacity','Speed')
  Win32_NetworkAdapterConfiguration=@('Description','IPAddress','IPSubnet','DefaultIPGateway','DNSServerSearchOrder')
  Win32_BIOS=@('Manufacturer','SMBIOSBIOSVersion','SerialNumber')
  Win32_QuickFixEngineering=@('HotFixID','InstalledOn','Description')
 }
 foreach($target in ($Targets | Select-Object -Unique)){
  foreach($class in ($classes.Keys | Sort-Object)){
   try{
    $query=@{ComputerName=$target;ClassName=$class;OperationTimeoutSec=$TimeoutSeconds;ErrorAction='Stop'}
    if($class -eq 'Win32_LogicalDisk'){$query.Filter='DriveType=3'}
    if($class -eq 'Win32_NetworkAdapterConfiguration'){$query.Filter='IPEnabled=True'}
    $data=@(Get-CimInstance @query | Select-Object -Property $classes[$class])
    $state=if($data.Count){'Collected'}elseif($class -eq 'Win32_QuickFixEngineering'){'Empty'}else{'UNKNOWN'}
    [pscustomobject]@{ComputerName=$target;Section=$class;CollectionState=$state;CollectedUtc=[datetime]::UtcNow.ToString('o');DataJson=(ConvertTo-Json -InputObject $data -Depth 6 -Compress);Error=$null}
   }catch{
    [pscustomobject]@{ComputerName=$target;Section=$class;CollectionState='UNKNOWN';CollectedUtc=[datetime]::UtcNow.ToString('o');DataJson='[]';Error=$_.Exception.Message}
   }
  }
 }
}
$rows=@(Get-InventoryEvidence $ComputerName $OperationTimeoutSeconds)
Export-NewReport $rows $OutputPath
if(@($rows | Where-Object CollectionState -eq 'UNKNOWN').Count){throw "Inventory is incomplete; inspect explicit UNKNOWN sections in $OutputPath"}
[pscustomobject]@{Path=$OutputPath;Sections=$rows.Count;Scope='Selected CIM inventory; application/patch compliance not assessed'}
