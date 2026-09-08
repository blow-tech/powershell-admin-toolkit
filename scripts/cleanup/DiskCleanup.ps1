#Requires -Version 5.1
<#
.SYNOPSIS
Inventory explicitly allowlisted temporary files; deletion requires a reviewed manifest.
.DESCRIPTION
Default and -WhatIf never delete files. Only .tmp files older than MinimumAgeDays
inside explicit non-root directories are eligible. No logs, backups, documents,
event logs, crash dumps, prefetch or Windows component store operations are included.
Use directories whose contents/ancestors cannot be modified by untrusted users.
Export the default output to CSV, review it, then pin its SHA256 for -Execute.
Deletion has no automatic rollback; retain a verified backup if recovery is needed.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)][string[]]$AllowedPath,
    [ValidateRange(1,3650)][int]$MinimumAgeDays = 30,
    [string]$ManifestPath,
    [string]$ManifestSha256,
    [switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-SafeCleanupPath {
    param([string]$LiteralPath)
    $item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    if ($item.PSProvider.Name -ne 'FileSystem') { throw 'Only filesystem paths are supported.' }
    $current = $item
    while ($null -ne $current) {
        if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point refused: $($current.FullName)" }
        if ($current -is [IO.FileInfo]) { $current = $current.Directory } else { $current = $current.Parent }
    }
    return $item
}
function Get-CleanupCandidate {
    param([string]$LiteralPath, [string[]]$Roots, [datetime]$Cutoff)
    $file = Assert-SafeCleanupPath $LiteralPath
    if ($file.PSIsContainer -or $file.Extension -ine '.tmp' -or $file.LastWriteTimeUtc -ge $Cutoff) {
        throw "Ineligible cleanup file: $LiteralPath"
    }
    $inside = $false
    foreach ($root in $Roots) {
        if ($file.FullName.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { $inside = $true }
    }
    if (-not $inside) { throw "Outside approved directories: $LiteralPath" }
    [pscustomobject]@{ Path=$file.FullName; Length=$file.Length; LastWriteTimeUtc=$file.LastWriteTimeUtc.ToString('o'); SHA256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
}
$roots = @($AllowedPath | ForEach-Object {
    $dir = Assert-SafeCleanupPath $_
    if (-not $dir.PSIsContainer -or $null -eq $dir.Parent) { throw 'Volume roots and files are not allowed as cleanup roots.' }
    $dir.FullName.TrimEnd([IO.Path]::DirectorySeparatorChar)
} | Select-Object -Unique)
$cutoff = [datetime]::UtcNow.AddDays(-$MinimumAgeDays)
if (-not $Execute) {
    # Explicit traversal refuses junctions before entering them.
    $pending = New-Object 'System.Collections.Generic.Queue[string]'
    foreach ($root in $roots) { $pending.Enqueue($root) }
    while ($pending.Count -gt 0) {
        $directory = Assert-SafeCleanupPath $pending.Dequeue()
        foreach ($entry in Get-ChildItem -LiteralPath $directory.FullName -Force) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($entry.PSIsContainer) { $pending.Enqueue($entry.FullName) }
            elseif ($entry.Extension -ieq '.tmp' -and $entry.LastWriteTimeUtc -lt $cutoff) {
                Get-CleanupCandidate $entry.FullName $roots $cutoff
            }
        }
    }
    return
}
if (-not $ManifestPath -or $ManifestSha256 -notmatch '^[a-fA-F0-9]{64}$') { throw '-Execute requires -ManifestPath and its reviewed -ManifestSha256.' }
$manifest = Assert-SafeCleanupPath $ManifestPath
if ((Get-FileHash -LiteralPath $manifest.FullName -Algorithm SHA256).Hash -ne $ManifestSha256) { throw 'Manifest digest changed.' }
$rows = @(Import-Csv -LiteralPath $manifest.FullName)
if ($rows.Count -eq 0) { throw 'Empty manifest.' }
$seen = @{}
# Validate every row before the first deletion.
foreach ($row in $rows) {
    if ($seen.ContainsKey($row.Path)) { throw "Duplicate manifest path: $($row.Path)" }
    $seen[$row.Path] = $true
    $candidate = Get-CleanupCandidate $row.Path $roots $cutoff
    if ($candidate.SHA256 -ne $row.SHA256 -or $candidate.Length -ne [long]$row.Length -or $candidate.LastWriteTimeUtc -ne $row.LastWriteTimeUtc) { throw "File changed: $($row.Path)" }
}
foreach ($row in $rows) {
    if ($PSCmdlet.ShouldProcess($row.Path, 'Permanently delete reviewed temporary file')) {
        $candidate = Get-CleanupCandidate $row.Path $roots $cutoff
        if ($candidate.SHA256 -ne $row.SHA256 -or $candidate.Length -ne [long]$row.Length -or $candidate.LastWriteTimeUtc -ne $row.LastWriteTimeUtc) { throw "File changed: $($row.Path)" }
        Remove-Item -LiteralPath $row.Path -ErrorAction Stop
        [pscustomobject]@{ Path=$row.Path; Status='Deleted'; TimeUtc=[datetime]::UtcNow }
    }
}
