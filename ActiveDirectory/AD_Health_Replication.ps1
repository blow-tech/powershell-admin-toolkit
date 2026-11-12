# Compatibility entry point; original Ali Tajran attribution retained in Git history.
# The former forest-wide collector mixed unavailable checks with informational results.
# Uses the maintained scoped collector. Extended diagnostics and restore readiness remain unassessed.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$DomainName,
 [Parameter(Mandatory=$true)][string]$ReportPath)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'Advanced-AD-HealthCheck.ps1') @PSBoundParameters
