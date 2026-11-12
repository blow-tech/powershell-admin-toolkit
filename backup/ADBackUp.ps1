#Requires -Version 5.1
<#
Creates a local system-state backup after explicit execution approval.
Windows Server Backup must already be installed. No feature installation is performed.
Requires an elevated backup operator/administrator. Backup I/O can affect performance.
A successful command/catalog check is not a restore test.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z]:$')][string]$BackupTarget)
$ErrorActionPreference='Stop'
$feature = Get-WindowsFeature -Name Windows-Server-Backup -ErrorAction Stop
if (-not $feature.Installed) { throw 'Windows Server Backup must be installed through a separate approved change.' }
if (-not (Test-Path -LiteralPath ($BackupTarget + '\') -PathType Container)) { throw 'Backup target is unavailable.' }
$wbadmin = Join-Path $env:SystemRoot 'System32\wbadmin.exe'
if (-not (Test-Path -LiteralPath $wbadmin -PathType Leaf)) { throw 'wbadmin.exe missing.' }
if ($PSCmdlet.ShouldProcess($BackupTarget, 'Run and wait for system-state backup')) {
    & $wbadmin start systemstatebackup "-backupTarget:$BackupTarget" -quiet
    if ($LASTEXITCODE -ne 0) { throw "System-state backup failed with exit code $LASTEXITCODE" }
    $catalog = @(& $wbadmin get versions "-backupTarget:$BackupTarget")
    if ($LASTEXITCODE -ne 0 -or $catalog.Count -eq 0) { throw 'Backup completed but catalog could not be verified.' }
    $catalog
    Write-Output 'Backup command succeeded and catalog was retrieved. Verify the new version and perform a lab restore before relying on recovery.'
}
