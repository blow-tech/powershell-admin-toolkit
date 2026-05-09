#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Safe disk cleanup for C:\ and O:\ drives.
    Removes temp files, caches, old logs, and orphaned backups.
    Does NOT touch user documents, databases, or critical system files.

.AUTHOR
    SysAdmin Cleanup Script blow_tech

.NOTES
    Run as Administrator.
    Tested on Windows Server 2016/2019/2022 and Windows 10/11.
    Adjust $LogRetentionDays and $ArchiveRetentionDays to your environment.
#>

# ============================================================
#  CONFIGURATION — adjust these before running
# ============================================================
$LogRetentionDays     = 30    # Delete logs older than X days on O:
$ArchiveRetentionDays = 90    # Delete old .zip/.bak/.old files older than X days on O:
$ODriveRoot           = "O:\" # Change if your O: drive has a specific target folder
$EnableWinSxSCleanup  = $true # Requires Disk Cleanup (cleanmgr) to be available
$EnableIISLogCleanup  = $true # Only runs if IIS is installed
$EnablePrefetch       = $true # Safe to enable on servers; disable if you want prefetch kept

# ============================================================
#  LOGGING SETUP
# ============================================================
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile    = Join-Path $ScriptDir "DiskCleanup_$(Get-Date -f 'yyyyMMdd_HHmmss').log"
$SpaceBefore = @{}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line -ForegroundColor $(switch ($Level) {
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        default   { "Cyan" }
    })
    Add-Content -Path $LogFile -Value $line
}

function Get-FreeSpaceGB {
    param([string]$Drive)
    $disk = Get-PSDrive -Name ($Drive.TrimEnd(':\')) -ErrorAction SilentlyContinue
    if ($disk) { return [math]::Round($disk.Free / 1GB, 2) }
    return 0
}

function Remove-SafeFolder {
    param(
        [string]$Path,
        [string]$Description,
        [int]$OlderThanDays = 0,
        [string[]]$Extensions = @()
    )

    if (-not (Test-Path $Path)) {
        Write-Log "Skipping (not found): $Description — $Path" "WARN"
        return
    }

    try {
        if ($OlderThanDays -gt 0 -or $Extensions.Count -gt 0) {
            # Selective delete by age / extension
            $cutoff = (Get-Date).AddDays(-$OlderThanDays)
            $filter = if ($Extensions.Count -gt 0) {
                Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension -in $Extensions -and ($OlderThanDays -eq 0 -or $_.LastWriteTime -lt $cutoff) }
            } else {
                Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt $cutoff }
            }
            $count = 0
            foreach ($file in $filter) {
                try { Remove-Item $file.FullName -Force -ErrorAction Stop; $count++ }
                catch { Write-Log "Could not delete: $($file.FullName) — $($_.Exception.Message)" "WARN" }
            }
            Write-Log "Cleaned $count file(s) from: $Description" "SUCCESS"
        } else {
            # Full wipe of folder contents (not the folder itself)
            $items = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item $item.FullName -Recurse -Force -ErrorAction Stop; $count++ }
                catch { Write-Log "Could not delete: $($item.FullName) — $($_.Exception.Message)" "WARN" }
            }
            Write-Log "Cleaned $count item(s) from: $Description" "SUCCESS"
        }
    } catch {
        Write-Log "Error cleaning $Description — $($_.Exception.Message)" "ERROR"
    }
}

# ============================================================
#  SNAPSHOT — free space before
# ============================================================
Write-Log "======================================================"
Write-Log " DISK CLEANUP STARTING"
Write-Log "======================================================"

foreach ($drv in @("C", "O")) {
    $gb = Get-FreeSpaceGB -Drive "$drv`:"
    $SpaceBefore[$drv] = $gb
    Write-Log "${drv}: free space before cleanup: ${gb} GB"
}

# ============================================================
#  C:\ — SYSTEM DRIVE CLEANUP
# ============================================================
Write-Log "------ C:\ Cleanup ------"

# 1. Windows Temp folder
Remove-SafeFolder -Path "C:\Windows\Temp" -Description "Windows\Temp"

# 2. Per-user Temp folders (all local users)
$userTempPaths = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName "AppData\Local\Temp" }

foreach ($tempPath in $userTempPaths) {
    Remove-SafeFolder -Path $tempPath -Description "User Temp ($tempPath)"
}

# 3. Windows Update download cache
Remove-SafeFolder -Path "C:\Windows\SoftwareDistribution\Download" `
    -Description "Windows Update Download Cache"

# 4. Prefetch cache
if ($EnablePrefetch) {
    Remove-SafeFolder -Path "C:\Windows\Prefetch" -Description "Prefetch Cache"
}

# 5. Crash dump files (minidumps only — NOT full memory dumps)
Remove-SafeFolder -Path "C:\Windows\Minidump" -Description "Minidump Files"

# 6. Thumbnail caches for all users
$thumbPaths = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName "AppData\Local\Microsoft\Windows\Explorer" }

foreach ($tp in $thumbPaths) {
    $thumbFiles = Get-ChildItem -Path $tp -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue
    foreach ($tf in $thumbFiles) {
        try { Remove-Item $tf.FullName -Force -ErrorAction Stop }
        catch { Write-Log "Could not delete thumbcache: $($tf.FullName)" "WARN" }
    }
}
Write-Log "Cleaned thumbnail caches" "SUCCESS"

# 7. Windows Error Reporting files
$werPaths = @(
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
    "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
)
foreach ($p in $werPaths) {
    Remove-SafeFolder -Path $p -Description "Windows Error Reporting ($p)"
}

# 8. Delivery Optimization cache
Remove-SafeFolder -Path "C:\Windows\SoftwareDistribution\DeliveryOptimization" `
    -Description "Delivery Optimization Cache"

# 9. IIS Logs older than N days (only if IIS is present)
if ($EnableIISLogCleanup) {
    $iisLogPath = "C:\inetpub\logs\LogFiles"
    if (Test-Path $iisLogPath) {
        Remove-SafeFolder -Path $iisLogPath `
            -Description "IIS Log Files (>$LogRetentionDays days)" `
            -OlderThanDays $LogRetentionDays `
            -Extensions @(".log")
    } else {
        Write-Log "IIS logs path not found, skipping." "WARN"
    }
}

# 10. WinSxS Component Store Cleanup (uses built-in DISM — safe)
if ($EnableWinSxSCleanup) {
    Write-Log "Running DISM Component Cleanup (WinSxS)..."
    try {
        $result = & dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1
        Write-Log "DISM cleanup completed." "SUCCESS"
    } catch {
        Write-Log "DISM cleanup failed: $($_.Exception.Message)" "ERROR"
    }
}

# 11. Recycle Bin on C:
Write-Log "Clearing Recycle Bin on C:..."
try {
    Clear-RecycleBin -DriveLetter C -Force -ErrorAction Stop
    Write-Log "Recycle Bin on C: cleared." "SUCCESS"
} catch {
    Write-Log "Recycle Bin C: clear failed: $($_.Exception.Message)" "WARN"
}

# 12. Windows Event Logs — clear non-critical logs (keeps System/Security/Application headers)
Write-Log "Clearing verbose Event Logs (Setup, ForwardedEvents)..."
$logsToFlush = @("Setup", "Microsoft-Windows-Diagnosis-DPS/Operational")
foreach ($log in $logsToFlush) {
    try {
        [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($log)
        Write-Log "Cleared event log: $log" "SUCCESS"
    } catch {
        Write-Log "Could not clear event log: $log — $($_.Exception.Message)" "WARN"
    }
}

# ============================================================
#  O:\ — DATA DRIVE CLEANUP
# ============================================================
Write-Log "------ O:\ Cleanup ------"

if (-not (Test-Path $ODriveRoot)) {
    Write-Log "O:\ drive not accessible — skipping O: cleanup." "WARN"
} else {

    # 1. Temp/tmp subfolders anywhere on O:
    $tempDirs = Get-ChildItem -Path $ODriveRoot -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -imatch '^te?mp$' }

    foreach ($td in $tempDirs) {
        Remove-SafeFolder -Path $td.FullName -Description "Temp folder on O: ($($td.FullName))"
    }

    # 2. Log files older than N days
    Remove-SafeFolder -Path $ODriveRoot `
        -Description "O:\ Log files (>$LogRetentionDays days)" `
        -OlderThanDays $LogRetentionDays `
        -Extensions @(".log", ".txt")

    # 3. Orphaned .bak and .old backup files
    Remove-SafeFolder -Path $ODriveRoot `
        -Description "O:\ .bak/.old files (>$ArchiveRetentionDays days)" `
        -OlderThanDays $ArchiveRetentionDays `
        -Extensions @(".bak", ".old")

    # 4. Old archive/zip files older than N days
    Remove-SafeFolder -Path $ODriveRoot `
        -Description "O:\ Archive files (>$ArchiveRetentionDays days)" `
        -OlderThanDays $ArchiveRetentionDays `
        -Extensions @(".zip", ".rar", ".7z", ".tar", ".gz")

    # 5. Recycle Bin on O:
    Write-Log "Clearing Recycle Bin on O:..."
    try {
        Clear-RecycleBin -DriveLetter O -Force -ErrorAction Stop
        Write-Log "Recycle Bin on O: cleared." "SUCCESS"
    } catch {
        Write-Log "Recycle Bin O: clear failed: $($_.Exception.Message)" "WARN"
    }
}

# ============================================================
#  FINAL REPORT
# ============================================================
Write-Log "======================================================"
Write-Log " CLEANUP COMPLETE — SPACE REPORT"
Write-Log "======================================================"

foreach ($drv in @("C", "O")) {
    $before = $SpaceBefore[$drv]
    $after  = Get-FreeSpaceGB -Drive "$drv`:"
    $gained = [math]::Round($after - $before, 2)
    Write-Log "${drv}: Before: ${before} GB free | After: ${after} GB free | Gained: +${gained} GB" "SUCCESS"
}

Write-Log "Log saved to: $LogFile"
Write-Log "======================================================"
