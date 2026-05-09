# Script Name: ADBackUp.ps1
# Description: Checks for Windows Server Backup feature, installs if missing, initiates AD backup, then exits
# Author: blow_Tech
# Date: 05-05-2026
# Version: 1.0

# Define backup destination and paths
$backupDestination = "E:"
$wbadminPath = "C:\Windows\System32\wbadmin.exe"

# Function to check and install Windows Server Backup feature if not present
function Ensure-WindowsServerBackup {
    Write-Host "Checking for Windows Server Backup feature..." -ForegroundColor Cyan
    $feature = Get-WindowsFeature -Name Windows-Server-Backup

    if ($feature.Installed -eq $false) {
        Write-Host "Windows Server Backup feature is not installed. Installing..." -ForegroundColor Yellow
        Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools -Verbose
        Write-Host "Windows Server Backup feature installed successfully." -ForegroundColor Green
    } else {
        Write-Host "Windows Server Backup feature is already installed." -ForegroundColor Green
    }
}

# Check if the backup destination exists
if (-not (Test-Path -Path $backupDestination)) {
    Write-Host "Backup destination does not exist. Please check the path and try again." -ForegroundColor Red
    exit
}

# Ensure Windows Server Backup is installed
Ensure-WindowsServerBackup

# Verify if wbadmin exists
if (-not (Test-Path -Path $wbadminPath)) {
    Write-Host "wbadmin executable not found at $wbadminPath. Ensure Windows Server Backup is installed." -ForegroundColor Red
    exit
}

# All checks passed message
Write-Host "All checks passed. Initiating the backup process..." -ForegroundColor Green

# Start the backup process in a new command window and exit PowerShell
Start-Process -FilePath $wbadminPath -ArgumentList "start systemstatebackup -backupTarget:$backupDestination -quiet"
Write-Host "Backup process initiated. You can monitor the backup in the new command window."
exit
