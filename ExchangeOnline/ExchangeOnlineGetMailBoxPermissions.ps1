# Portable replacement for the legacy trailing-dot Basic-auth snippet.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][guid]$TenantId,[Parameter(Mandatory=$true)][string]$OutputPath,[string[]]$UPN=@())
& (Join-Path $PSScriptRoot 'MailboxesUserCanAccess.ps1') @PSBoundParameters
