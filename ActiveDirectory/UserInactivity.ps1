# Compatibility entry point. Default is read-only; see REMEDIATION-2026-11.md.
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [Parameter(Mandatory=$true)][string]$Server,
 [Parameter(Mandatory=$true)][string]$SearchBase,
 [ValidateRange(1,36500)][int]$InactiveDays=90
)
& (Join-Path $PSScriptRoot 'CleanupInactiveUsers.ps1') -Server $Server -SearchBase $SearchBase -InactiveDays $InactiveDays -Action Report
