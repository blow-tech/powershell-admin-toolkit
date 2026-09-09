#Requires -Version 5.1
# Read-only GPO inventory. One independent output per explicit domain.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][Alias('Domians')][ValidateNotNullOrEmpty()][string[]]$Domains,
    [Parameter(Mandatory)][string]$ExportPath
)
$ErrorActionPreference='Stop'
$directory=Get-Item -LiteralPath $ExportPath -ErrorAction Stop
if (-not $directory.PSIsContainer -or $directory.PSProvider.Name -ne 'FileSystem') {throw 'Existing output directory required.'}
$plan=@(foreach ($domain in ($Domains | Sort-Object -Unique)) {
    if ($domain -notmatch '^(?=.{1,253}$)[a-zA-Z0-9]+([.-][a-zA-Z0-9]+)*$') {throw "Invalid domain: $domain"}
    $path=Join-Path $directory.FullName "$domain-GPOReport.csv"
    if (Test-Path -LiteralPath $path) {throw "Output already exists: $path"}
    [pscustomobject]@{Domain=$domain;Path=$path}
})
foreach ($item in $plan) {
    $domain=$item.Domain
    $results=@(foreach ($gpo in (Get-GPO -All -Domain $domain -ErrorAction Stop)) {
        [xml]$report=Get-GPOReport -Guid $gpo.Id -ReportType Xml -Domain $domain -ErrorAction Stop
        if ($null -eq $report.GPO) {throw "Invalid GPO report in $domain"}
        [pscustomobject]@{
            GPO_Name=$gpo.DisplayName; Doamin=$gpo.DomainName
            GPO_Assigned=[bool]$report.GPO.LinksTo; Created=$gpo.CreationTime
            Last_Modified=$gpo.ModificationTime; Linked_OU=($report.GPO.LinksTo.SOMPath -join ',')
        }
    })
    $results | Export-Csv -LiteralPath $item.Path -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
    [pscustomobject]@{Domain=$domain;Count=$results.Count;OutputPath=$item.Path;Status='Collected'}
}
