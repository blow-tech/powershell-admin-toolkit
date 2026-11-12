# Read-only bounded CIM evidence. Legacy console/JSON schemas are retired; see REMEDIATION-2026-11.md.
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateCount(1,32)][string[]]$ComputerName,[Parameter(Mandatory)][string]$OutputPath)
& (Join-Path $PSScriptRoot 'inventory/Audit.ps1') -ComputerName $ComputerName -OutputPath $OutputPath
