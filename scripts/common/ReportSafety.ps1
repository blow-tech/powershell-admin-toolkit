# Shared local publication and existing-session validation. Dot source only.
function Assert-ExchangeTenant {
    param([guid]$TenantId)
    $connections=@(Get-ConnectionInformation -ErrorAction Stop | Where-Object { $_.State -eq 'Connected' })
    if ($connections.Count -ne 1 -or [string]$connections[0].TenantID -ne $TenantId.ToString() -or $connections[0].ModulePrefix) {
        throw 'Exactly one connected, unprefixed Exchange session in the expected tenant is required.'
    }
}
function Export-NewReport {
    param([object[]]$Rows,[string]$Path)
    $full=[IO.Path]::GetFullPath($Path); $parent=[IO.Path]::GetDirectoryName($full)
    if (-not [IO.Directory]::Exists($parent) -or [IO.File]::Exists($full)) { throw 'Use an existing protected output parent and a new filename.' }
    $temp=Join-Path $parent ('.report-'+[guid]::NewGuid().ToString('N')+'.partial')
    try {
        if ($Rows.Count) { $Rows | Export-Csv -LiteralPath $temp -NoTypeInformation -Encoding UTF8 -ErrorAction Stop }
        else { [IO.File]::WriteAllText($temp,'') }
        [IO.File]::Move($temp,$full) # No overwrite; same-filesystem publication.
    } catch { throw "Report publication failed. Any partial evidence remains at $temp. $($_.Exception.Message)" }
}
