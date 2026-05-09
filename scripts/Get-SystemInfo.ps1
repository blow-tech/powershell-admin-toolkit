<#
.SYNOPSIS
Collects basic system information from a Windows machine.

.DESCRIPTION
This script performs read-only checks and displays OS, CPU, memory,
disk, and network information.

.NOTES
Safe to run. Does not modify the system.
#>

Write-Host "=== System Information ==="

Get-ComputerInfo | Select-Object `
    CsName,
    WindowsProductName,
    WindowsVersion,
    OsArchitecture,
    CsManufacturer,
    CsModel

Write-Host "`n=== CPU ==="
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors

Write-Host "`n=== Memory ==="
Get-CimInstance Win32_ComputerSystem | Select-Object `
    @{Name="TotalMemoryGB";Expression={[math]::Round($_.TotalPhysicalMemory / 1GB, 2)}}

Write-Host "`n=== Disks ==="
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object `
    DeviceID,
    VolumeName,
    @{Name="SizeGB";Expression={[math]::Round($_.Size / 1GB, 2)}},
    @{Name="FreeGB";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}}

Write-Host "`n=== Network ==="
Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway, DNSServer
