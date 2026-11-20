#requires -Version 5.1
<#
.SYNOPSIS
  Export Entra ID users' last successful sign-in to CSV using Graph v1.0.
.DESCRIPTION
  Read-only. Uses Invoke-MgGraphRequest and follows @odata.nextLink.
  Parses Graph timestamps with invariant culture (not the Windows date locale).
  Does not require ImportExcel or Graph beta modules.
.EXAMPLE
  .\Export-EntraLastSignIn.ps1 -PreviewOnly
.EXAMPLE
  .\Export-EntraLastSignIn.ps1 -OutputPath C:\Reports\EntraLastSuccessfulSignIn.csv
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) ('EntraLastSuccessfulSignIn_{0}.csv' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))),
    [switch]$PreviewOnly
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
}

$context = Get-MgContext
if (-not $context) {
    throw 'Not signed in. Run: Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All"'
}

foreach ($scope in @('User.Read.All', 'AuditLog.Read.All')) {
    if ($context.Scopes -notcontains $scope -and $context.Scopes -notcontains 'Directory.Read.All') {
        # Directory.Read.All does NOT replace AuditLog.Read.All for sign-in activity.
        if ($scope -eq 'AuditLog.Read.All' -or ($context.Scopes -notcontains 'Directory.Read.All')) {
            throw "Missing scope: $scope. Reconnect using Connect-MgGraph -Scopes 'User.Read.All','AuditLog.Read.All'"
        }
    }
}

$pageSize = if ($PreviewOnly) { 5 } else { 500 }
$uri = 'https://graph.microsoft.com/v1.0/users?$top=' + $pageSize + '&$select=id,displayName,userPrincipalName,userType,accountEnabled,department,signInActivity'
$rows = New-Object 'System.Collections.Generic.List[object]'
$now = [DateTimeOffset]::UtcNow
$page = 0

try {
    do {
        $page++
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        if ($null -eq $response -or $null -eq $response.value) {
            throw "Graph returned an unexpected response on page $page."
        }
        foreach ($user in $response.value) {
            $raw = $user.signInActivity.lastSuccessfulSignInDateTime
            $date = [DateTimeOffset]::MinValue
            $hasDate = $false
            if (-not [string]::IsNullOrWhiteSpace([string]$raw)) {
                $hasDate = [DateTimeOffset]::TryParse(
                    [string]$raw,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::AssumeUniversal,
                    [ref]$date
                )
                if ($hasDate -and $date.Year -le 1) { $hasDate = $false }
            }
            $days = $null
            $last = ''
            $state = 'Not recorded'
            if (-not $hasDate -and -not [string]::IsNullOrWhiteSpace([string]$raw)) {
                throw "Unrecognized successful sign-in timestamp for user $($user.id): $raw"
            }
            if ($hasDate) {
                $last = $date.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
                $days = [math]::Max(0, [math]::Floor(($now - $date.ToUniversalTime()).TotalDays))
                $state = 'Recorded'
            }
            $rows.Add([PSCustomObject]@{
                DisplayName                 = $user.displayName
                UserPrincipalName           = $user.userPrincipalName
                UserType                    = $user.userType
                AccountEnabled              = $user.accountEnabled
                Department                  = $user.department
                LastSuccessfulSignInUTC     = $last
                DaysSinceLastSuccessfulSignIn = $days
                SignInRecordStatus          = $state
                UserId                      = $user.id
            })
        }
        Write-Host ("Retrieved {0} users (page {1})..." -f $rows.Count, $page)
        if ($PreviewOnly) { break }
        $uri = $response['@odata.nextLink']
    } while ($uri)

    if ($PreviewOnly) {
        $rows | Select-Object -First 5 DisplayName,UserPrincipalName,LastSuccessfulSignInUTC,DaysSinceLastSuccessfulSignIn,SignInRecordStatus | Format-Table -AutoSize
        Write-Host 'Preview only: no CSV created.' -ForegroundColor Yellow
        return
    }
    $folder = Split-Path -Parent $OutputPath
    if ($folder -and -not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    # UTF8 with BOM (Windows PowerShell 5.1) is friendly to Excel.
    $rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    Write-Host ("Done. Exported {0} users to: {1}" -f $rows.Count, $OutputPath) -ForegroundColor Green
} catch {
    Write-Error ("Export failed on page {0}: {1}. No completed report was produced." -f $page, $_.Exception.Message)
    throw
}
