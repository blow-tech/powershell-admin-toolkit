<#
.SYNOPSIS
    Advanced Active Directory Health Check Report
    Saves to: C:\AD-Monitoring\
#>

# --- Configuration & Path Setup ---
$DirectoryPath = "C:\AD-Monitoring"
$ReportPath = "$DirectoryPath\AD_HealthReport_$(Get-Date -Format 'yyyyMMdd_HHmm').html"
$Domain = (Get-ADDomain).NetBIOSName
$Forest = (Get-ADForest).Name

# Create the directory if it doesn't exist
if (!(Test-Path $DirectoryPath)) {
    New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null
}

# --- CSS Styling for Professional Look ---
$Header = @"
<style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f7f6; color: #333; margin: 20px; }
    h1 { color: #004a99; border-bottom: 2px solid #004a99; padding-bottom: 10px; }
    h2 { background-color: #004a99; color: white; padding: 10px; border-radius: 5px; margin-top: 30px; margin-bottom: 10px; font-size: 1.2em; }
    table { border-collapse: collapse; width: 100%; background: white; margin-bottom: 20px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); border-radius: 8px; overflow: hidden; }
    th { background-color: #0056b3; color: white; padding: 12px; text-align: left; }
    td { padding: 10px; border-bottom: 1px solid #eee; font-size: 0.9em; }
    tr:nth-child(even) { background-color: #f9f9f9; }
    tr:hover { background-color: #f1f1f1; }
    .status-pass { color: #28a745; font-weight: bold; }
    .status-fail { color: #dc3545; font-weight: bold; }
    pre { background: #2d2d2d; color: #f8f8f2; padding: 15px; border-radius: 5px; overflow-x: auto; font-family: 'Consolas', monospace; }
</style>
"@

$ReportContent = "<h1>Active Directory Health Executive Summary</h1>"
$ReportContent += "<p><strong>Forest:</strong> $Forest | <strong>Domain:</strong> $(Get-ADDomain).DNSRoot</p>"
$ReportContent += "<p><strong>Generated on:</strong> $(Get-Date)</p>"

# --- 1. FSMO Role Holders ---
$ReportContent += "<h2>FSMO Role Infrastructure</h2>"
$Roles = Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster
$DomRoles = Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
$FSMOTable = [PSCustomObject]@{
    "Schema Master"     = $Roles.SchemaMaster
    "Domain Naming"     = $Roles.DomainNamingMaster
    "PDC Emulator"      = $DomRoles.PDCEmulator
    "RID Master"        = $DomRoles.RIDMaster
    "Infrastructure"    = $DomRoles.InfrastructureMaster
}
$ReportContent += ($FSMOTable | ConvertTo-Html -Fragment)

# --- 2. DC Connectivity & Critical Services ---
$ReportContent += "<h2>Domain Controller Health Status</h2>"
$DCResults = foreach ($DC in (Get-ADDomainController -Filter *)) {
    $Ping = Test-Connection -ComputerName $DC.HostName -Count 1 -Quiet
    $Services = Get-Service -ComputerName $DC.HostName -Name NTDS, DNS, Netlogon, DFSR, W32Time, KDC -ErrorAction SilentlyContinue
    
    $StatusClass = "status-pass"
    $StatusText = "Healthy"
    
    if ($Services.Status -contains "Stopped" -or !$Ping) {
        $StatusClass = "status-fail"
        $StatusText = "ISSUE DETECTED"
    }
    
    [PSCustomObject]@{
        "Server Name" = $DC.HostName
        "Site"        = $DC.Site
        "IP Address"  = $DC.IPv4Address
        "Connectivity" = if ($Ping) { "Online" } else { "OFFLINE" }
        "AD Services" = $StatusText
        "OS Version"  = $DC.OperatingSystem
    }
}
$ReportContent += ($DCResults | ConvertTo-Html -Fragment)

# --- 3. Replication Summary ---
$ReportContent += "<h2>Forest Replication Summary</h2>"
$ReplSummary = repadmin /replsummary /errorsonly
if ([string]::IsNullOrWhiteSpace($ReplSummary)) {
    $ReportContent += "<p class='status-pass'>✔ All replication partners are synchronized. No errors found.</p>"
} else {
    $ReportContent += "<pre>$ReplSummary</pre>"
}

# --- 4. Detailed Replication Failures ---
$ReportContent += "<h2>Metadata & Replication Failures</h2>"
$ReplFailures = Get-ADReplicationFailure -Target * -Scope Forest -ErrorAction SilentlyContinue
if ($ReplFailures) {
    $ReportContent += ($ReplFailures | Select-Object Server, LastError, LastExpiryTime, Partner | ConvertTo-Html -Fragment)
} else {
    $ReportContent += "<p class='status-pass'>✔ Zero replication failures reported via Get-ADReplicationFailure.</p>"
}

# --- 5. DNS & Sysvol Health (DCDIAG) ---
$ReportContent += "<h2>Critical Diagnostics (DCDIAG)</h2>"
$DCDiag = dcdiag /test:Connectivity /test:DNS /test:SysVolCheck /q 2>&1
if ($DCDiag) {
    $ReportContent += "<pre style='color:#ff6b6b;'>$DCDiag</pre>"
} else {
    $ReportContent += "<p class='status-pass'>✔ DCDIAG connectivity and DNS checks passed successfully.</p>"
}

# --- 6. Time Hierarchy ---
$ReportContent += "<h2>Time Convergence</h2>"
$TimeSource = w32tm /query /source
$ReportContent += "<p>Primary Time Source: <strong>$TimeSource</strong></p>"

# --- Final Assembly and Export ---
$FullHTML = ConvertTo-Html -Head $Header -Body $ReportContent -Title "AD Health Report"
$FullHTML | Out-File $ReportPath

Write-Host "Success! Report saved to: $ReportPath" -ForegroundColor Green
$MailParams = @{
    To          = "admin@blow_tech.in"
    From        = "AD-Monitor@blow_tech.in"
    Subject     = "Daily AD Health Report - $Forest"
    Body        = "Please find the attached Active Directory Health Report for $Forest."
    Attachments = $ReportPath
    SmtpServer  = "smtp.@blow_tech.in"
}
Send-MailMessage @MailParams
