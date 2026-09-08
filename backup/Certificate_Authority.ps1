#Requires -Version 5.1
<#
Dot-source, then call Backup-CertificationAuthority -Path <existing-protected-directory>
-BackupKey -Password (Read-Host -AsSecureString). Full backup is default.
Every run uses a new version directory. No previous backup or CA log is removed.
The protected parent directory and recovery password must be provisioned separately.
Uses the supported ADCSAdministration API rather than unmanaged handles.
https://learn.microsoft.com/powershell/module/adcsadministration/backup-caroleservice
#>
function Backup-CertificationAuthority {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Full','Incremental')][string]$Type='Full',
        [Security.SecureString]$Password,
        [switch]$BackupKey,
        [switch]$KeepLog,
        [switch]$Force,
        [switch]$Extended
    )
    $ErrorActionPreference = 'Stop'
    if ($Force) { Write-Warning '-Force is obsolete: existing backups are always preserved.' }
    if ($Extended) { throw '-Extended is unsupported; use the documented full or incremental backup.' }
    $root = Get-Item -LiteralPath $Path -Force
    if (-not $root.PSIsContainer -or $root.PSProvider.Name -ne 'FileSystem') { throw 'Supply an existing protected filesystem directory.' }
    for ($ancestor=$root; $null -ne $ancestor; $ancestor=$ancestor.Parent) {
        if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse points are not supported.' }
    }
    if ($BackupKey -and ($null -eq $Password -or $Password.Length -eq 0)) { throw 'Provide a nonempty SecureString password for the key backup.' }
    Import-Module ADCSAdministration -ErrorAction Stop
    if ((Get-Service CertSvc -ErrorAction Stop).Status -ne 'Running') { throw 'CA service is not running.' }
    $destination = Join-Path $root.FullName ('CA-' + (Get-Date -Format 'yyyyMMddTHHmmss') + '-' + [guid]::NewGuid().ToString('N'))
    if (-not $PSCmdlet.ShouldProcess($destination, "Create $Type CA backup, preserving CA logs and all prior backups")) { return }
    $null = New-Item -ItemType Directory -Path $destination -ErrorAction Stop
    try {
        $options = @{ Path=$destination; DatabaseOnly=$true; KeepLog=$true; ErrorAction='Stop' }
        if ($Type -eq 'Incremental') { $options.Incremental=$true }
        Backup-CARoleService @options
        if ($BackupKey) { Backup-CARoleService -Path $destination -KeyOnly -Password $Password -ErrorAction Stop }
        $regFile = Join-Path $destination 'CARegistryConfiguration.reg'
        & reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration' $regFile
        if ($LASTEXITCODE -ne 0) { throw "Registry export failed: $LASTEXITCODE" }
        $databaseFiles = @(Get-ChildItem -LiteralPath (Join-Path $destination 'Database') -File -Recurse -ErrorAction Stop)
        if ($databaseFiles.Count -eq 0 -or @($databaseFiles | Where-Object Length -eq 0).Count -gt 0) { throw 'Database backup is empty or contains empty files.' }
        if ($BackupKey -and @(Get-ChildItem -LiteralPath $destination -File | Where-Object { $_.Extension -in '.p12','.pfx' -and $_.Length -gt 0 }).Count -eq 0) { throw 'Private-key backup artifact missing.' }
        if ((Get-Item -LiteralPath $regFile).Length -eq 0) { throw 'Empty registry export.' }
        $files = @(Get-ChildItem -LiteralPath $destination -File -Recurse)
        $files | Get-FileHash -Algorithm SHA256 | Export-Csv -LiteralPath (Join-Path $destination 'checksums.csv') -NoTypeInformation
        Set-Content -LiteralPath (Join-Path $destination 'BACKUP-COMPLETE.txt') -Value 'Backup commands succeeded; artifact checks passed. A lab restore remains required.'
        [pscustomobject]@{ Succeeded=$true; Path=$destination; Type=$Type; RestoreValidated=$false; KeyIncluded=[bool]$BackupKey }
    } catch {
        # Preserve partial artifacts and every prior version; never publish a complete marker.
        throw "CA backup failed; partial evidence retained at $destination. $($_.Exception.Message)"
    }
}
