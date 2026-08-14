<#
.SYNOPSIS
    Monitors system resources in real-time with customizable thresholds and alerts.

.DESCRIPTION
    This script provides real-time monitoring of CPU, memory, disk, and network usage.
    It can generate alerts when resources exceed specified thresholds and export
    the data to various formats.

    Features:
    - Real-time monitoring of CPU, memory, disk, and network usage
    - Customizable thresholds for resource alerts
    - Configurable monitoring interval and duration
    - Export capabilities in CSV, XML, or JSON formats
    - Clean console display with color-coded alerts
    - Comprehensive error handling and logging

    The script uses Windows Performance Counters to gather accurate system metrics
    and provides a user-friendly interface for monitoring system health.

.PARAMETER Interval
    The interval in seconds between measurements. Default is 5 seconds.

.PARAMETER Duration
    How long to monitor in minutes. Default is 0 (run indefinitely).

.PARAMETER CPUThreshold
    CPU usage threshold percentage. Default is 80.

.PARAMETER MemoryThreshold
    Memory usage threshold percentage. Default is 80.

.PARAMETER DiskThreshold
    Disk usage threshold percentage. Default is 80.

.PARAMETER ExportPath
    Path to save the monitoring data. Default is "C:\Logs\SystemMonitor".

.PARAMETER ExportFormat
    Format to export the monitoring data (CSV, XML, or JSON).

.EXAMPLE
    .\Monitor-SystemResources.ps1 -Interval 10 -Duration 30
    Monitors system resources every 10 seconds for 30 minutes.

.EXAMPLE
    .\Monitor-SystemResources.ps1 -CPUThreshold 90 -MemoryThreshold 85 -ExportFormat CSV
    Monitors with custom thresholds and exports to CSV.

.NOTES
    Author: Your Name
    Version: 1.0
    Date: 2024-04-27
    Requirements: Windows PowerShell 5.1 or later
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 3600)]
    [int]$Interval = 5,

    [Parameter(Mandatory=$false)]
    [ValidateRange(0, 1440)]
    [int]$Duration = 0,

    [Parameter(Mandatory=$false)]
    [ValidateRange(0, 100)]
    [int]$CPUThreshold = 80,

    [Parameter(Mandatory=$false)]
    [ValidateRange(0, 100)]
    [int]$MemoryThreshold = 80,

    [Parameter(Mandatory=$false)]
    [ValidateRange(0, 100)]
    [int]$DiskThreshold = 80,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "C:\Logs\SystemMonitor",

    [Parameter(Mandatory=$false)]
    [ValidateSet("CSV", "XML", "JSON")]
    [string]$ExportFormat = "CSV"
)

# Ensure export directory exists
if (-not (Test-Path $ExportPath)) {
    New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$exportFile = Join-Path $ExportPath "SystemResources_$timestamp"
$monitoringData = @()
$startTime = Get-Date
$endTime = if ($Duration -gt 0) { $startTime.AddMinutes($Duration) } else { $null }

function Get-SystemMetrics {
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $memory = (Get-Counter '\Memory\% Committed Bytes In Use').CounterSamples.CookedValue
    $disk = Get-Counter '\LogicalDisk(*)\% Free Space' | 
            Where-Object { $_.CounterSamples.InstanceName -notmatch '_Total' } |
            Select-Object @{Name='Drive';Expression={$_.CounterSamples.InstanceName}},
                        @{Name='FreeSpace';Expression={100 - $_.CounterSamples.CookedValue}}
    
    $network = Get-Counter '\Network Interface(*)\Bytes Total/sec' |
               Where-Object { $_.CounterSamples.InstanceName -notmatch 'isatap' } |
               Select-Object @{Name='Interface';Expression={$_.CounterSamples.InstanceName}},
                           @{Name='BytesPerSec';Expression={$_.CounterSamples.CookedValue}}

    return @{
        Timestamp = Get-Date
        CPU = [math]::Round($cpu, 2)
        Memory = [math]::Round($memory, 2)
        Disk = $disk
        Network = $network
    }
}

function Test-Thresholds {
    param($metrics)
    
    $alerts = @()
    
    if ($metrics.CPU -gt $CPUThreshold) {
        $alerts += "CPU usage is at $($metrics.CPU)% (Threshold: $CPUThreshold%)"
    }
    if ($metrics.Memory -gt $MemoryThreshold) {
        $alerts += "Memory usage is at $($metrics.Memory)% (Threshold: $MemoryThreshold%)"
    }
    foreach ($drive in $metrics.Disk) {
        if ((100 - $drive.FreeSpace) -gt $DiskThreshold) {
            $alerts += "Drive $($drive.Drive) usage is at $([math]::Round(100 - $drive.FreeSpace, 2))% (Threshold: $DiskThreshold%)"
        }
    }
    
    return $alerts
}

try {
    Write-Host "Starting system resource monitoring..."
    Write-Host "Press Ctrl+C to stop monitoring"
    
    while (-not $endTime -or (Get-Date) -lt $endTime) {
        $metrics = Get-SystemMetrics
        $monitoringData += $metrics
        
        # Display current metrics
        Clear-Host
        Write-Host "System Resource Monitor - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host "----------------------------------------"
        Write-Host "CPU Usage: $($metrics.CPU)%"
        Write-Host "Memory Usage: $($metrics.Memory)%"
        Write-Host "Disk Usage:"
        $metrics.Disk | ForEach-Object {
            Write-Host "  $($_.Drive): $([math]::Round(100 - $_.FreeSpace, 2))% used"
        }
        Write-Host "Network Usage:"
        $metrics.Network | ForEach-Object {
            Write-Host "  $($_.Interface): $([math]::Round($_.BytesPerSec/1MB, 2)) MB/s"
        }
        
        # Check thresholds and display alerts
        $alerts = Test-Thresholds -metrics $metrics
        if ($alerts) {
            Write-Host "`nAlerts:"
            $alerts | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
        }
        
        Start-Sleep -Seconds $Interval
    }
} catch {
    Write-Error "An error occurred during monitoring: $_"
} finally {
    # Export the collected data
    if ($monitoringData) {
        switch ($ExportFormat) {
            "CSV" {
                $monitoringData | Export-Csv -Path "$exportFile.csv" -NoTypeInformation
            }
            "XML" {
                $monitoringData | Export-Clixml -Path "$exportFile.xml"
            }
            "JSON" {
                $monitoringData | ConvertTo-Json -Depth 10 | Out-File "$exportFile.json"
            }
        }
        Write-Host "`nMonitoring data exported to $exportFile.$($ExportFormat.ToLower())"
    }
} 
