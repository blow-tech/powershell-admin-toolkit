# Compatibility entry point; shares the canonical collector and parameters.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][guid]$TenantId,[Parameter(Mandatory=$true)][string]$OutputPath,
    [ValidateSet('UserMailbox','SharedMailbox','RoomMailbox','EquipmentMailbox')][string[]]$RecipientTypeDetails=@())
& (Join-Path $PSScriptRoot 'GetMailboxes.ps1') @PSBoundParameters
