#Requires -Version 5.1
<#
Compatibility entry point for the maintained AD health collector.
The former inline checks could report success after collection failure and sent
email to hard-coded addresses. Supply an explicit output path; delivery belongs
in a separately configured/approved notification job.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ReportPath,
    [string]$DomainName='',
    [switch]$OpenReport
)
$ErrorActionPreference='Stop'
$collector=Join-Path (Split-Path $PSScriptRoot -Parent) 'ActiveDirectory/Advanced-AD-HealthCheck.ps1'
& $collector -ReportPath $ReportPath -DomainName $DomainName -OpenReport:$OpenReport
