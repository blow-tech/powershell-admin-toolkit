# Replaces the nonfunctional community entry point with a maintained read-only collector.
# Original attribution: Adrian Johnson; original source retained in Git history.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReportPath,[Parameter(Mandatory=$true)][string]$DomainName)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot '../scripts/AD_Monitoring.ps1') -ReportPath $ReportPath -DomainName $DomainName
