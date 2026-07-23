<#
.SYNOPSIS
    Analyzes Windows Scheduled Tasks for potentially suspicious configurations and behaviors.

.DESCRIPTION
    This script examines all scheduled tasks on a Windows system and analyzes them for 
    potentially suspicious indicators like:
    - Use of temp directories
    - Encoded/obfuscated PowerShell commands
    - Suspiciously short or random task names
    - Execution of script files (.js, .vbs, .ps1, etc.)
    
    The script provides detailed output about any suspicious tasks found and can optionally
    show analysis of all tasks regardless of suspicion level.

.PARAMETER VerboseOutput
    When specified, displays analysis results for all tasks, not just suspicious ones.
    
.EXAMPLE
    .\Check-SuspiciousScheduledTasks.ps1
    Analyzes scheduled tasks and displays only those flagged as suspicious.

.EXAMPLE
    .\Check-SuspiciousScheduledTasks.ps1 -VerboseOutput
    Analyzes and displays results for all scheduled tasks, suspicious or not.

.NOTES
    Requires:
    - Windows 8/Server 2012 or later
    - ScheduledTasks PowerShell module
    - Administrative privileges recommended

.OUTPUTS
    Displays a formatted table of suspicious tasks (or all tasks with -VerboseOutput)
    including task name, path, action, triggers, state and suspicious findings.
#>

[CmdletBinding()]
param(
    [switch]$VerboseOutput
)

function Get-ScheduledTaskInfo {
    Write-Error "[ERROR] No tasks found or unable to retrieve scheduled tasks."
    return
}

$analysisResults = foreach ($t in $allTasks) {
    Analyze-Task -TaskObject $t
}

if ($VerboseOutput) {
    $analysisResults | Format-Table -AutoSize
}
else {
    $suspiciousTasks = $analysisResults | Where-Object {$_.Suspicious -eq $true}
    if ($suspiciousTasks) {
        Write-Host "`n[RESULT] Suspicious tasks detected:"
        $suspiciousTasks | Format-Table -AutoSize
    }
    else {
        Write-Host "`n[RESULT] No suspicious tasks found."
    }
}

# Optional: Export the full analysis if needed
# $analysisResults | Export-Csv -Path .\ScheduledTasksAnalysis.csv -NoTypeInformation
