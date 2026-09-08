#Requires -Version 5.1
[CmdletBinding()]
param([switch]$VerboseOutput)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-TaskAnalysis {
    param([Parameter(Mandatory)]$Task)
    $indicators = New-Object 'System.Collections.Generic.List[string]'
    $actions = @($Task.Actions)
    if ($actions.Count -eq 0) { throw "Task has no analyzable actions: $($Task.TaskName)" }
    $commands = foreach ($action in $actions) {
        if ($null -eq $action) { throw 'Null task action.' }
        if ($action.PSObject.Properties['ClassId']) {
            $indicators.Add('COM handler: manual review required')
            "COM:$($action.ClassId)"
        } elseif ($action.PSObject.Properties['Execute'] -and -not [string]::IsNullOrWhiteSpace($action.Execute)) {
            $arguments = if ($action.PSObject.Properties['Arguments']) { [string]$action.Arguments } else { '' }
            $command = "$($action.Execute) $arguments"
            if ($command -match '(?i)(\\temp\\|%temp%|\\appdata\\|\\downloads\\)') { $indicators.Add('Execution from a user-writable location') }
            if ($command -match '(?i)(-e(n(c(odedcommand)?)?)?\s+|FromBase64String|DownloadString|Invoke-Expression|\biex\b)') { $indicators.Add('Encoded or dynamic command') }
            if ($command -match '(?i)(\.(ps1|vbs|js|hta)\b|\b(mshta|wscript|cscript)(\.exe)?\b)') { $indicators.Add('Script execution: review purpose and origin') }
            $command
        } else { throw "Unsupported or malformed action in $($Task.TaskName)" }
    }
    [pscustomobject]@{ TaskName=$Task.TaskName; TaskPath=$Task.TaskPath; Actions=($commands -join '; '); Suspicious=($indicators.Count -gt 0); Indicators=@($indicators.ToArray()) }
}
function Invoke-TaskAssessment {
    try {
        $tasks = @(Get-ScheduledTask -ErrorAction Stop)
        if ($tasks.Count -eq 0) { throw 'No tasks retrieved; expected scope cannot be verified.' }
        $results = @($tasks | ForEach-Object { Get-TaskAnalysis -Task $_ })
        [pscustomobject]@{ Succeeded=$true; TasksChecked=$results.Count; Findings=@($results | Where-Object Suspicious); Results=$results; Error=$null }
    } catch {
        [pscustomobject]@{ Succeeded=$false; TasksChecked=0; Findings=@(); Results=@(); Error=$_.Exception.Message }
    }
}
$result = Invoke-TaskAssessment
$result
if (-not $result.Succeeded) { throw "Task assessment UNKNOWN: $($result.Error)" }
if ($VerboseOutput) { $result.Results | Format-Table -AutoSize }
Write-Information "Evaluated $($result.TasksChecked) tasks. Indicators are heuristic; this is not proof that a host is clean." -InformationAction Continue
