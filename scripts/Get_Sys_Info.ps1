<#
.SYNOPSIS
    Collects basic system information.

.DESCRIPTION
    Retrieves information such as OS details, hardware info, uptime, and memory usage.
    Optionally exports to JSON or CSV.

.PARAMETER ExportPath
    (Optional) File path to export results.

.PARAMETER OutputFormat
    Format for output: JSON (default) or CSV.

.EXAMPLE
    .\Get-SystemInfo.ps1
    Displays system info on the console.
#>

[CmdletBinding()]
param(
    [string]$ExportPath,
    [ValidateSet("JSON","CSV")]
    [string]$OutputFormat = "JSON"
)

try {
    # Start-Transcript -Path "C:\Logs\Get-SystemInfo_$(Get-Date -Format 'yyyyMMdd').log" -ErrorAction SilentlyContinue

    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor

    $systemInfo = [PSCustomObject]@{
        ComputerName        = $env:COMPUTERNAME
        OS                  = $os.Caption
        OSVersion           = $os.Version
        Manufacturer        = $cs.Manufacturer
        Model               = $cs.Model
        Processor           = $cpu.Name
        TotalPhysicalMemory = (“{0:N2} GB” -f ($cs.TotalPhysicalMemory / 1GB))
        FreePhysicalMemory  = (“{0:N2} GB” -f (($os.FreePhysicalMemory * 1KB) / 1GB))
        LastBootUpTime      = $os.LastBootUpTime
        UptimeDays          = (New-TimeSpan -Start $os.LastBootUpTime).Days
    }

    if ($ExportPath) {
        switch ($OutputFormat) {
            "JSON" {
                $systemInfo | ConvertTo-Json | Out-File $ExportPath
            }
            "CSV" {
                $systemInfo | Export-Csv -Path $ExportPath -NoTypeInformation
            }
        }
        Write-Host "System info exported to $ExportPath"
    } else {
        $systemInfo
    }

} catch {
    Write-Error "An error occurred while collecting system info: $_"
} finally {
    # Stop-Transcript -ErrorAction SilentlyContinue
}
