# Compatibility wrapper for the maintained CIM evidence collector. CSV schema changed.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateCount(1,32)][string[]]$ComputerName,
 [Parameter(Mandatory=$true)][string]$OutputPath,
 [ValidateRange(5,120)][int]$OperationTimeoutSeconds=30)
& (Join-Path $PSScriptRoot 'Audit.ps1') @PSBoundParameters
