<#
.SYNOPSIS
    Monitors Windows Firewall for rule changes in real-time.

.DESCRIPTION
    This script continuously monitors the Windows Firewall configuration for any changes to rules.
    It takes periodic snapshots of the firewall rules and compares them to detect modifications.
    When changes are detected, it logs the details including:
    - Timestamp of the change
    - What rules were added/modified/removed
    - Full details of the changes for auditing purposes
    
    The script runs continuously until interrupted with CTRL+C.

.PARAMETER LogFile
    Specifies the path where change logs will be written.
    Default value is "C:\FirewallChangeLog.txt"
    
.EXAMPLE
    .\Monitor-FirewallChanges.ps1
    Monitors firewall changes and logs to the default log file location.

.EXAMPLE
    .\Monitor-FirewallChanges.ps1 -LogFile "D:\Security\fw_changes.log"
    Monitors firewall changes and logs to a custom log file location.

.NOTES
    Requires:
    - Windows 8/Server 2012 or later
    - NetSecurity PowerShell module
    - Administrative privileges
    
    The script captures these rule properties:
    - DisplayName
    - Direction
    - Action
    - Enabled status
    - Profile
    - Program path

.OUTPUTS
    - Console output for real-time monitoring
    - Log file entries for all detected changes
    - Detailed comparison of rule changes when modifications are detected
#>


[CmdletBinding()]
param(
    [string]$LogFile = "C:\FirewallChangeLog.txt"
)

Write-Host "[INFO] Monitoring Windows Firewall for rule changes..."
Write-Host "[INFO] Logging to $LogFile"
Write-Host "[CTRL+C to stop]"

# Initial Snapshot
try {
    $initialRules = Get-NetFirewallRule -ErrorAction Stop
}
catch {
    Write-Error "[ERROR] Unable to retrieve firewall rules. Error: $($_.Exception.Message)"
    return
}

$initialHash = $initialRules | Select-Object DisplayName, Direction, Action, Enabled, Profile, Program | Out-String | Get-Hash

while ($true) {
    try {
        Start-Sleep -Seconds 5
        $currentRules = Get-NetFirewallRule | Select-Object DisplayName, Direction, Action, Enabled, Profile, Program
        $currentHash = $currentRules | Out-String | Get-Hash

        if ($currentHash -ne $initialHash) {
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $logMsg = "[ALERT][$timestamp] Firewall rule set changed!"

            Write-Host $logMsg
            Add-Content -Path $LogFile -Value $logMsg

            # Optionally diff the old and new sets to see what's changed
            # You could also store $currentRules in a file for full auditing
            # Example using Compare-Object:
            $changes = Compare-Object -ReferenceObject $initialRules -DifferenceObject $currentRules -Property DisplayName, Direction, Action, Enabled, Profile, Program
            if ($changes) {
                $changes | Out-String | Add-Content -Path $LogFile
            }

            # Update snapshot
            $initialRules = $currentRules
            $initialHash  = $currentHash
        }
    }
    catch {
        Write-Warning "[WARNING] Error during monitoring loop: $($_.Exception.Message)"
    }
}
