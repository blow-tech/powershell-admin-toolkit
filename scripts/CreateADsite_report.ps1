<# Read-only forest configuration evidence queried via explicit Server. Requires AD read permissions.
A successful empty query is distinct from a denied query; no report is published after failure. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server,[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
. (Join-Path $PSScriptRoot 'common/ReportSafety.ps1')
$rows=@(Get-ADReplicationSite -Server $Server -Filter * -Properties Description,AutomaticInterSiteTopologyGenerationEnabled,AutomaticTopologyGenerationEnabled,gpLink,interSiteTopologyGenerator,whenCreated,whenChanged -ErrorAction Stop |
 Select-Object ObjectGUID,Name,Description,AutomaticInterSiteTopologyGenerationEnabled,AutomaticTopologyGenerationEnabled,gpLink,interSiteTopologyGenerator,whenCreated,whenChanged,DistinguishedName)
Export-NewReport -Rows $rows -Path $OutputPath
