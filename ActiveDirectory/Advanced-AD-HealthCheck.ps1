<# 
.SYNOPSIS
Advanced Active Directory Health Check Script with HTML Report

.DESCRIPTION
Collects a wide range of Active Directory health indicators and exports
a polished HTML report suitable for email attachment or management review.

.NOTES
Run with elevated privileges on a Domain Controller or management server
with RSAT ActiveDirectory tools installed.

Author:blow_tech
#>

[CmdletBinding()]
param(
    [string]$DomainName = "",
    [string]$ReportPath = ".\AD-Health-Report-$((Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')).html",
    [switch]$OpenReport
)

$ErrorActionPreference = "SilentlyContinue"

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Yellow
    Write-Host "===============================" -ForegroundColor Cyan
}

function Get-SeverityFromStatus {
    param([string]$Status)

    switch ($Status) {
        "PASS" { "pass" }
        "WARN" { "warn" }
        "FAIL" { "fail" }
        default { "info" }
    }
}

function New-ResultObject {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Target,
        [string]$Status,
        [string]$Details,
        [string]$Recommendation = ""
    )

    [PSCustomObject]@{
        Category       = $Category
        Check          = $Check
        Target         = $Target
        Status         = $Status
        SeverityClass  = Get-SeverityFromStatus -Status $Status
        Details        = $Details
        Recommendation = $Recommendation
    }
}

function ConvertTo-HtmlTable {
    param(
        [Parameter(Mandatory)]
        [array]$Data,
        [Parameter(Mandatory)]
        [string]$Title
    )

    if (-not $Data -or $Data.Count -eq 0) {
        return "<div class='section'><h2>$Title</h2><p class='muted'>No data returned.</p></div>"
    }

    $headers = $Data[0].PSObject.Properties.Name
    $html = "<div class='section'><h2>$Title</h2><table><thead><tr>"
    foreach ($h in $headers) {
        $html += "<th>$h</th>"
    }
    $html += "</tr></thead><tbody>"

    foreach ($row in $Data) {
        $html += "<tr>"
        foreach ($h in $headers) {
            $value = $row.$h
            if ($null -eq $value) { $value = "" }

            if ($h -eq "Status") {
                $class = Get-SeverityFromStatus -Status ([string]$value)
                $html += "<td><span class='badge $class'>$value</span></td>"
            }
            else {
                $safe = [System.Web.HttpUtility]::HtmlEncode([string]$value)
                $html += "<td>$safe</td>"
            }
        }
        $html += "</tr>"
    }

    $html += "</tbody></table></div>"
    return $html
}

function Invoke-CommandSafe {
    param([scriptblock]$ScriptBlock)
    try { & $ScriptBlock } catch { $null }
}

function Get-CommandTextOutput {
    param([string]$Command, [string]$Arguments)

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Command
        $psi.Arguments = $Arguments
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        [void]$p.Start()
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()

        [PSCustomObject]@{
            ExitCode = $p.ExitCode
            StdOut   = $stdout.Trim()
            StdErr   = $stderr.Trim()
        }
    }
    catch {
        [PSCustomObject]@{
            ExitCode = 999
            StdOut   = ""
            StdErr   = $_.Exception.Message
        }
    }
}

# Load required modules
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

Write-Section "Starting Advanced Active Directory Health Check"

$Results                = New-Object System.Collections.Generic.List[Object]
$DCInventory            = @()
$ServiceResults         = @()
$DiskResults            = @()
$ReplicationResults     = @()
$EventSummary           = @()
$DnsResults             = @()
$FsmoResults            = @()
$ShareResults           = @()
$NetworkResults         = @()
$DomainOverview         = @()
$RawCommandSections     = @()

# Identify domain
if ([string]::IsNullOrWhiteSpace($DomainName)) {
    $DomainName = (Invoke-CommandSafe { (Get-ADDomain).DNSRoot })
}

if ([string]::IsNullOrWhiteSpace($DomainName)) {
    throw "Unable to determine domain name. Please provide -DomainName."
}

$Now = Get-Date

Write-Section "Collecting Forest and Domain Information"

$Forest = Invoke-CommandSafe { Get-ADForest }
$Domain = Invoke-CommandSafe { Get-ADDomain }

if ($Forest -and $Domain) {
    $DomainOverview += [PSCustomObject]@{
        ForestName              = $Forest.Name
        RootDomain              = $Forest.RootDomain
        DomainName              = $Domain.DNSRoot
        NetBIOSName             = $Domain.NetBIOSName
        ForestMode              = $Forest.ForestMode
        DomainMode              = $Domain.DomainMode
        DomainsInForest         = ($Forest.Domains -join ", ")
        Sites                   = ($Forest.Sites -join ", ")
        GlobalCatalogs          = ($Forest.GlobalCatalogs -join ", ")
        RecycleBinEnabled       = [bool]$Forest.RecycleBinEnabled
        TombstoneLifetimeDays   = $Forest.TombStoneLifetime
    }

    $Results.Add((New-ResultObject -Category "Directory" -Check "Forest Discovery" -Target $Forest.Name -Status "PASS" -Details "Forest and domain information collected successfully." -Recommendation "No action required."))
}
else {
    $Results.Add((New-ResultObject -Category "Directory" -Check "Forest Discovery" -Target $DomainName -Status "FAIL" -Details "Unable to retrieve forest/domain information." -Recommendation "Verify Active Directory module availability and required permissions."))
}

Write-Section "Enumerating Domain Controllers"

$DomainControllers = Invoke-CommandSafe { Get-ADDomainController -Filter * -Server $DomainName | Sort-Object HostName }

if ($DomainControllers) {
    foreach ($dc in $DomainControllers) {
        $boot = Invoke-CommandSafe { (Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $dc.HostName).LastBootUpTime }
        $os = Invoke-CommandSafe { (Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $dc.HostName).Caption }
        $ip = Invoke-CommandSafe { (Resolve-DnsName $dc.HostName -Type A -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty IPAddress) }

        $DCInventory += [PSCustomObject]@{
            HostName         = $dc.HostName
            Site             = $dc.Site
            IPv4Address      = $dc.IPv4Address
            ResolvedIP       = $ip
            OS               = $os
            IsGlobalCatalog  = $dc.IsGlobalCatalog
            IsReadOnly       = $dc.IsReadOnly
            OperationMasterRoles = (($dc.OperationMasterRoles | ForEach-Object { $_.ToString() }) -join ", ")
            LastBootUpTime   = $boot
        }

        $ping = Test-Connection -ComputerName $dc.HostName -Count 1 -Quiet
        if ($ping) {
            $Results.Add((New-ResultObject -Category "Connectivity" -Check "DC Reachability" -Target $dc.HostName -Status "PASS" -Details "Host reachable by ICMP ping." -Recommendation "No action required."))
        }
        else {
            $Results.Add((New-ResultObject -Category "Connectivity" -Check "DC Reachability" -Target $dc.HostName -Status "FAIL" -Details "Host not reachable by ICMP ping." -Recommendation "Check firewall, routing, NIC, DNS registration, or server availability."))
        }
    }
}
else {
    $Results.Add((New-ResultObject -Category "Directory" -Check "Domain Controller Enumeration" -Target $DomainName -Status "FAIL" -Details "No domain controllers returned." -Recommendation "Validate AD connectivity and domain discovery."))
}

Write-Section "Checking DNS Resolution"

foreach ($dc in $DomainControllers) {
    $dnsA = Invoke-CommandSafe { Resolve-DnsName $dc.HostName -Type A -ErrorAction Stop }
    if ($dnsA) {
        $DnsResults += [PSCustomObject]@{
            Target  = $dc.HostName
            Type    = "A Record"
            Status  = "PASS"
            Details = (($dnsA | Select-Object -ExpandProperty IPAddress) -join ", ")
        }
        $Results.Add((New-ResultObject -Category "DNS" -Check "DC Host Record" -Target $dc.HostName -Status "PASS" -Details "A record resolved successfully." -Recommendation "No action required."))
    }
    else {
        $DnsResults += [PSCustomObject]@{
            Target  = $dc.HostName
            Type    = "A Record"
            Status  = "FAIL"
            Details = "Unable to resolve A record."
        }
        $Results.Add((New-ResultObject -Category "DNS" -Check "DC Host Record" -Target $dc.HostName -Status "FAIL" -Details "Unable to resolve A record for domain controller." -Recommendation "Review DNS registration, zone replication, and NIC DNS configuration."))
    }
}

Write-Section "Checking Critical Services"

$CriticalServices = "NTDS","DNS","Netlogon","DFSR","W32Time","KDC","ADWS"
foreach ($dc in $DomainControllers) {
    foreach ($svc in $CriticalServices) {
        $service = Invoke-CommandSafe { Get-Service -ComputerName $dc.HostName -Name $svc }
        if ($service) {
            $status = if ($service.Status -eq "Running") { "PASS" } else { "FAIL" }

            $ServiceResults += [PSCustomObject]@{
                DomainController = $dc.HostName
                Service          = $service.Name
                DisplayName      = $service.DisplayName
                Status           = $status
                CurrentState     = $service.Status
                StartType        = (Invoke-CommandSafe { (Get-CimInstance Win32_Service -ComputerName $dc.HostName -Filter "Name='$svc'").StartMode })
            }

            $Results.Add((New-ResultObject -Category "Services" -Check $service.Name -Target $dc.HostName -Status $status -Details "Service state: $($service.Status)." -Recommendation "Ensure service is set correctly and investigate dependencies if not running."))
        }
        else {
            $ServiceResults += [PSCustomObject]@{
                DomainController = $dc.HostName
                Service          = $svc
                DisplayName      = $svc
                Status           = "WARN"
                CurrentState     = "Unknown"
                StartType        = "Unknown"
            }

            $Results.Add((New-ResultObject -Category "Services" -Check $svc -Target $dc.HostName -Status "WARN" -Details "Unable to query service." -Recommendation "Verify RPC/WMI access and permissions."))
        }
    }
}

Write-Section "Checking SYSVOL and NETLOGON Shares"

foreach ($dc in $DomainControllers) {
    $shares = Invoke-CommandSafe { Get-SmbShare -CimSession $dc.HostName | Where-Object { $_.Name -in @("SYSVOL","NETLOGON") } }
    $present = @($shares.Name)

    foreach ($required in "SYSVOL","NETLOGON") {
        $status = if ($present -contains $required) { "PASS" } else { "FAIL" }
        $detail = if ($status -eq "PASS") { "$required share is present." } else { "$required share missing." }

        $ShareResults += [PSCustomObject]@{
            DomainController = $dc.HostName
            Share            = $required
            Status           = $status
            Details          = $detail
        }

        $Results.Add((New-ResultObject -Category "SYSVOL" -Check "$required Share" -Target $dc.HostName -Status $status -Details $detail -Recommendation "If missing, review SYSVOL replication, DFSR health, Netlogon, and dcdiag output."))
    }
}

Write-Section "Checking FSMO Role Holders"

$fsmo = Invoke-CommandSafe { netdom query fsmo }
if ($fsmo) {
    $FsmoResults += [PSCustomObject]@{
        Command = "netdom query fsmo"
        Output  = ($fsmo | Out-String).Trim()
    }
    $Results.Add((New-ResultObject -Category "Operations" -Check "FSMO Role Query" -Target $DomainName -Status "PASS" -Details "FSMO role holders returned successfully." -Recommendation "Validate holders are online and backed up."))
}
else {
    $Results.Add((New-ResultObject -Category "Operations" -Check "FSMO Role Query" -Target $DomainName -Status "FAIL" -Details "Unable to retrieve FSMO role holders." -Recommendation "Verify RSAT tools and domain connectivity."))
}

Write-Section "Checking Replication Summary"

$replSummary = Get-CommandTextOutput -Command "repadmin.exe" -Arguments "/replsummary"
$showrepl    = Get-CommandTextOutput -Command "repadmin.exe" -Arguments "/showrepl * /csv"
$dcdiagQ     = Get-CommandTextOutput -Command "dcdiag.exe" -Arguments "/q"
$dcdiagE     = Get-CommandTextOutput -Command "dcdiag.exe" -Arguments "/e /test:Advertising /test:Services /test:Replications /test:SysVolCheck /test:NetLogons /test:DNS"

$RawCommandSections += [PSCustomObject]@{ Title = "repadmin /replsummary"; Output = $replSummary.StdOut; ExitCode = $replSummary.ExitCode }
$RawCommandSections += [PSCustomObject]@{ Title = "dcdiag /q"; Output = $dcdiagQ.StdOut; ExitCode = $dcdiagQ.ExitCode }
$RawCommandSections += [PSCustomObject]@{ Title = "dcdiag /e /test:Advertising /test:Services /test:Replications /test:SysVolCheck /test:NetLogons /test:DNS"; Output = $dcdiagE.StdOut; ExitCode = $dcdiagE.ExitCode }

if ($replSummary.ExitCode -eq 0 -or $replSummary.StdOut) {
    $status = if ($replSummary.StdOut -match "fails|error" -or $replSummary.ExitCode -ne 0) { "WARN" } else { "PASS" }
    $Results.Add((New-ResultObject -Category "Replication" -Check "repadmin /replsummary" -Target $DomainName -Status $status -Details "Replication summary executed." -Recommendation "Review largest delta, failed partners, and lingering replication issues."))
}
else {
    $Results.Add((New-ResultObject -Category "Replication" -Check "repadmin /replsummary" -Target $DomainName -Status "FAIL" -Details $replSummary.StdErr -Recommendation "Ensure repadmin is installed and run with required permissions."))
}

$AdReplFailures = Invoke-CommandSafe { Get-ADReplicationFailure -Target * -Scope Forest }
if ($AdReplFailures) {
    foreach ($failure in $AdReplFailures) {
        $ReplicationResults += [PSCustomObject]@{
            Server           = $failure.Server
            FirstFailureTime = $failure.FirstFailureTime
            FailureCount     = $failure.FailureCount
            Partner          = $failure.Partner
            Status           = "FAIL"
            Details          = $failure.LastErrorMessage
        }

        $Results.Add((New-ResultObject -Category "Replication" -Check "AD Replication Failure" -Target $failure.Server -Status "FAIL" -Details $failure.LastErrorMessage -Recommendation "Resolve name resolution, RPC, authentication, or topology issues blocking replication."))
    }
}
else {
    $ReplicationResults += [PSCustomObject]@{
        Server           = $DomainName
        FirstFailureTime = ""
        FailureCount     = 0
        Partner          = ""
        Status           = "PASS"
        Details          = "No replication failures returned."
    }

    $Results.Add((New-ResultObject -Category "Replication" -Check "AD Replication Failure" -Target $DomainName -Status "PASS" -Details "No replication failures detected." -Recommendation "No action required."))
}

Write-Section "Checking Time Service"

foreach ($dc in $DomainControllers) {
    $timeSource = Get-CommandTextOutput -Command "w32tm.exe" -Arguments "/query /computer:$($dc.HostName) /source"
    $timeConfig = Get-CommandTextOutput -Command "w32tm.exe" -Arguments "/query /computer:$($dc.HostName) /configuration"

    $status = if ($timeSource.ExitCode -eq 0 -and $timeSource.StdOut) { "PASS" } else { "WARN" }
    $NetworkResults += [PSCustomObject]@{
        DomainController = $dc.HostName
        Check            = "Time Source"
        Status           = $status
        Details          = $timeSource.StdOut
    }

    $Results.Add((New-ResultObject -Category "Time" -Check "Time Source" -Target $dc.HostName -Status $status -Details $timeSource.StdOut -Recommendation "Ensure PDC Emulator has an authoritative time source and all other DCs sync properly."))
}

Write-Section "Checking Disk Capacity"

foreach ($dc in $DomainControllers) {
    $drives = Invoke-CommandSafe {
        Get-CimInstance Win32_LogicalDisk -ComputerName $dc.HostName -Filter "DriveType=3" |
        Select-Object DeviceID,
                      @{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}},
                      @{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,2)}},
                      @{N='FreePercent';E={[math]::Round(($_.FreeSpace/$_.Size)*100,2)}}
    }

    foreach ($drive in $drives) {
        $status = if ($drive.FreePercent -lt 10) { "FAIL" } elseif ($drive.FreePercent -lt 20) { "WARN" } else { "PASS" }

        $DiskResults += [PSCustomObject]@{
            DomainController = $dc.HostName
            Drive            = $drive.DeviceID
            SizeGB           = $drive.SizeGB
            FreeGB           = $drive.FreeGB
            FreePercent      = $drive.FreePercent
            Status           = $status
        }

        $Results.Add((New-ResultObject -Category "Capacity" -Check "Disk Free Space" -Target "$($dc.HostName) $($drive.DeviceID)" -Status $status -Details "Free space: $($drive.FreeGB) GB ($($drive.FreePercent)%)." -Recommendation "Maintain adequate free space for AD database, logs, SYSVOL, and OS patching."))
    }
}

Write-Section "Checking Event Logs"

$CriticalLogNames = @("Directory Service","DNS Server","System","DFS Replication")
foreach ($dc in $DomainControllers) {
    foreach ($logName in $CriticalLogNames) {
        $events = Invoke-CommandSafe {
            Get-WinEvent -ComputerName $dc.HostName -FilterHashtable @{
                LogName   = $logName
                Level     = 1,2,3
                StartTime = (Get-Date).AddDays(-1)
            } -MaxEvents 50
        }

        $count = @($events).Count
        $status = if ($count -eq 0) { "PASS" } elseif ($count -le 10) { "WARN" } else { "FAIL" }

        $EventSummary += [PSCustomObject]@{
            DomainController = $dc.HostName
            LogName          = $logName
            EventsLast24Hrs  = $count
            Status           = $status
        }

        $detail = "$count warning/error/critical events in last 24 hours from log '$logName'."
        $recommendation = "Review recurring event IDs, correlate with replication, DNS, DFSR, and service failures."

        $Results.Add((New-ResultObject -Category "Events" -Check $logName -Target $dc.HostName -Status $status -Details $detail -Recommendation $recommendation))
    }
}

Write-Section "Checking Secure Channel and Core Networking"

foreach ($dc in $DomainControllers) {
    $nl = Get-CommandTextOutput -Command "nltest.exe" -Arguments "/server:$($dc.HostName) /dsgetdc:$DomainName"
    $status = if ($nl.ExitCode -eq 0) { "PASS" } else { "WARN" }

    $NetworkResults += [PSCustomObject]@{
        DomainController = $dc.HostName
        Check            = "DC Locator"
        Status           = $status
        Details          = if ($nl.StdOut) { $nl.StdOut } else { $nl.StdErr }
    }

    $Results.Add((New-ResultObject -Category "Connectivity" -Check "nltest /dsgetdc" -Target $dc.HostName -Status $status -Details (if ($nl.StdOut) { $nl.StdOut } else { $nl.StdErr }) -Recommendation "Validate SRV records, site/subnet mappings, and locator functionality."))
}

Write-Section "Checking AD Database and SYSVOL Paths"

foreach ($dc in $DomainControllers) {
    $ntdsReg = Invoke-CommandSafe {
        Invoke-Command -ComputerName $dc.HostName -ScriptBlock {
            Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" |
            Select-Object "DSA Database file","Database log files path"
        }
    }

    if ($ntdsReg) {
        $Results.Add((New-ResultObject -Category "Database" -Check "NTDS Paths" -Target $dc.HostName -Status "PASS" -Details "Database and log file paths collected." -Recommendation "Ensure database and logs reside on healthy volumes with sufficient free space."))
    }
    else {
        $Results.Add((New-ResultObject -Category "Database" -Check "NTDS Paths" -Target $dc.HostName -Status "WARN" -Details "Unable to retrieve NTDS database/log paths." -Recommendation "Verify remote registry/PowerShell remoting permissions."))
    }
}

Write-Section "Checking AD Optional Features, Trusts, and Privileged Groups"

$optionalFeatures = Invoke-CommandSafe { Get-ADOptionalFeature -Filter * }
$trusts           = Invoke-CommandSafe { Get-ADTrust -Filter * }
$privGroups       = @("Domain Admins","Enterprise Admins","Schema Admins","Administrators")

foreach ($group in $privGroups) {
    $members = Invoke-CommandSafe { Get-ADGroupMember -Identity $group -Recursive | Select-Object -ExpandProperty SamAccountName }
    if ($members) {
        $memberCount = @($members).Count
        $status = if ($memberCount -gt 15) { "WARN" } else { "PASS" }
        $Results.Add((New-ResultObject -Category "Security" -Check "Privileged Group Membership" -Target $group -Status $status -Details "$memberCount members detected." -Recommendation "Review least privilege and remove stale privileged accounts."))
    }
    else {
        $Results.Add((New-ResultObject -Category "Security" -Check "Privileged Group Membership" -Target $group -Status "WARN" -Details "Unable to enumerate members or group is empty." -Recommendation "Validate permissions and confirm intended membership."))
    }
}

if ($Forest -and $Forest.RecycleBinEnabled) {
    $Results.Add((New-ResultObject -Category "Recovery" -Check "AD Recycle Bin" -Target $Forest.Name -Status "PASS" -Details "Recycle Bin is enabled." -Recommendation "No action required."))
}
else {
    $Results.Add((New-ResultObject -Category "Recovery" -Check "AD Recycle Bin" -Target $DomainName -Status "WARN" -Details "Recycle Bin is not enabled or could not be confirmed." -Recommendation "Consider enabling AD Recycle Bin after change review."))
}

if ($trusts) {
    foreach ($trust in $trusts) {
        $Results.Add((New-ResultObject -Category "Trusts" -Check "Trust Relationship" -Target $trust.Name -Status "PASS" -Details "Trust type: $($trust.TrustType); Direction: $($trust.Direction)." -Recommendation "Validate trust health periodically using netdom and secure channel tests."))
    }
}
else {
    $Results.Add((New-ResultObject -Category "Trusts" -Check "Trust Relationship Enumeration" -Target $DomainName -Status "WARN" -Details "No trusts found or unable to query trusts." -Recommendation "If trusts exist, validate AD permissions and trust query access."))
}

Write-Section "Generating Summary"

$PassCount = @($Results | Where-Object Status -eq "PASS").Count
$WarnCount = @($Results | Where-Object Status -eq "WARN").Count
$FailCount = @($Results | Where-Object Status -eq "FAIL").Count
$TotalChecks = @($Results).Count

$OverallStatus = if ($FailCount -gt 0) { "FAIL" } elseif ($WarnCount -gt 0) { "WARN" } else { "PASS" }

$Recommendations = $Results |
    Where-Object { $_.Status -in @("WARN","FAIL") } |
    Select-Object Category, Check, Target, Status, Recommendation

$TopFindings = $Results |
    Where-Object { $_.Status -in @("FAIL","WARN") } |
    Select-Object -First 15 Category, Check, Target, Status, Details, Recommendation

$css = @"
<style>
body {
    font-family: Segoe UI, Arial, sans-serif;
    background: #0b1220;
    color: #e8edf7;
    margin: 0;
    padding: 0;
}
.wrapper {
    width: 96%;
    margin: 20px auto;
}
.header {
    background: linear-gradient(135deg, #111b33, #1b2d52);
    border: 1px solid #2e477b;
    border-radius: 14px;
    padding: 24px;
    box-shadow: 0 6px 22px rgba(0,0,0,0.35);
}
.brand {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 10px;
}
h1 {
    margin: 0;
    font-size: 34px;
    color: #ffffff;
}
.subtitle {
    margin-top: 8px;
    color: #b7c6e4;
    font-size: 14px;
}
.meta {
    margin-top: 12px;
    color: #d8e2f7;
    font-size: 13px;
}
.cards {
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
    margin: 20px 0;
}
.card {
    flex: 1 1 180px;
    background: #121c31;
    border: 1px solid #27385f;
    border-radius: 12px;
    padding: 18px;
    box-shadow: 0 4px 18px rgba(0,0,0,0.28);
}
.card h3 {
    margin: 0 0 8px 0;
    font-size: 14px;
    color: #bcd0f5;
    text-transform: uppercase;
    letter-spacing: .5px;
}
.card .value {
    font-size: 34px;
    font-weight: 700;
}
.pass-text { color: #30d158; }
.warn-text { color: #ffb020; }
.fail-text { color: #ff5d5d; }
.info-text { color: #72b4ff; }
.section {
    background: #11192c;
    border: 1px solid #263556;
    border-radius: 12px;
    padding: 18px;
    margin: 18px 0;
    box-shadow: 0 3px 14px rgba(0,0,0,0.22);
}
.section h2 {
    margin-top: 0;
    font-size: 21px;
    color: #ffffff;
    border-left: 5px solid #5aa9ff;
    padding-left: 10px;
}
table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 12px;
}
th {
    background: #1d2b49;
    color: #ffffff;
    text-align: left;
    padding: 10px;
    font-size: 13px;
    border-bottom: 1px solid #31456e;
}
td {
    padding: 10px;
    font-size: 13px;
    color: #e8edf7;
    border-bottom: 1px solid #21304e;
    vertical-align: top;
}
tr:nth-child(even) td {
    background: #0f1728;
}
.badge {
    display: inline-block;
    padding: 4px 10px;
    border-radius: 999px;
    font-size: 12px;
    font-weight: 700;
    min-width: 48px;
    text-align: center;
}
.badge.pass { background: rgba(48,209,88,0.16); color: #5be37c; border: 1px solid rgba(48,209,88,0.35); }
.badge.warn { background: rgba(255,176,32,0.16); color: #ffc35b; border: 1px solid rgba(255,176,32,0.35); }
.badge.fail { background: rgba(255,93,93,0.16); color: #ff8484; border: 1px solid rgba(255,93,93,0.35); }
.badge.info { background: rgba(114,180,255,0.16); color: #9cccff; border: 1px solid rgba(114,180,255,0.35); }
pre {
    white-space: pre-wrap;
    word-break: break-word;
    background: #0a1020;
    border: 1px solid #243459;
    color: #e0ebff;
    padding: 12px;
    border-radius: 10px;
    overflow-x: auto;
    font-size: 12px;
}
.footer {
    margin: 24px 0 40px 0;
    font-size: 12px;
    color: #9eb1d6;
    text-align: center;
}
.muted { color: #9fb0cf; }
.hero-status {
    font-size: 16px;
    margin-top: 12px;
}
.logo-box {
    text-align: right;
    font-size: 13px;
    color: #dbe6fb;
}
.logo-box strong {
    display: block;
    font-size: 16px;
    color: #ffffff;
}
</style>
"@

$headerHtml = @"
<div class='header'>
    <div class='brand'>
        <div>
            <h1>Advanced Active Directory Health Check Report</h1>
            <div class='subtitle'>Professional HTML report for AD DS monitoring, replication, services, DNS, SYSVOL, security, and operational health.</div>
            <div class='meta'>
                <strong>Domain:</strong> $DomainName |
                <strong>Generated:</strong> $Now |
                <strong>Overall Status:</strong> <span class='badge $(Get-SeverityFromStatus -Status $OverallStatus)'>$OverallStatus</span>
            </div>
            <div class='hero-status'>This report is designed to be email-ready, management-friendly, and suitable for regular AD health review.</div>
        </div>
        <div class='logo-box'>
            <strong>YouTube - blow tech </strong>
            blow_tech h<br/>
            blow_tech@gmail.com
        </div>
    </div>
</div>
"@

$cardsHtml = @"
<div class='cards'>
    <div class='card'>
        <h3>Total Checks</h3>
        <div class='value info-text'>$TotalChecks</div>
    </div>
    <div class='card'>
        <h3>Passed</h3>
        <div class='value pass-text'>$PassCount</div>
    </div>
    <div class='card'>
        <h3>Warnings</h3>
        <div class='value warn-text'>$WarnCount</div>
    </div>
    <div class='card'>
        <h3>Failures</h3>
        <div class='value fail-text'>$FailCount</div>
    </div>
</div>
"@

$rawHtml = ""
foreach ($section in $RawCommandSections) {
    $safeTitle = [System.Web.HttpUtility]::HtmlEncode($section.Title)
    $safeOut = [System.Web.HttpUtility]::HtmlEncode($section.Output)
    $rawHtml += "<div class='section'><h2>Raw Command Output - $safeTitle</h2><div class='muted'>Exit Code: $($section.ExitCode)</div><pre>$safeOut</pre></div>"
}

$htmlParts = @()
$htmlParts += "<html><head><title>AD Health Check Report - $DomainName</title>$css</head><body><div class='wrapper'>"
$htmlParts += $headerHtml
$htmlParts += $cardsHtml
$htmlParts += ConvertTo-HtmlTable -Data $TopFindings -Title "Top Findings"
$htmlParts += ConvertTo-HtmlTable -Data $Recommendations -Title "Recommendations"
$htmlParts += ConvertTo-HtmlTable -Data $DomainOverview -Title "Forest and Domain Overview"
$htmlParts += ConvertTo-HtmlTable -Data $DCInventory -Title "Domain Controller Inventory"
$htmlParts += ConvertTo-HtmlTable -Data $ServiceResults -Title "Critical Service Status"
$htmlParts += ConvertTo-HtmlTable -Data $ShareResults -Title "SYSVOL and NETLOGON Share Validation"
$htmlParts += ConvertTo-HtmlTable -Data $ReplicationResults -Title "Replication Failures"
$htmlParts += ConvertTo-HtmlTable -Data $DiskResults -Title "Disk Capacity Review"
$htmlParts += ConvertTo-HtmlTable -Data $DnsResults -Title "DNS Resolution Checks"
$htmlParts += ConvertTo-HtmlTable -Data $EventSummary -Title "Critical Event Log Summary (Last 24 Hours)"
$htmlParts += ConvertTo-HtmlTable -Data $NetworkResults -Title "Time and Connectivity Checks"
$htmlParts += ConvertTo-HtmlTable -Data $Results -Title "Complete Health Check Results"
$htmlParts += $rawHtml
$htmlParts += "<div class='footer'>Generated by Advanced AD Health Check Script | Ready for email attachment and periodic operational review.</div>"
$htmlParts += "</div></body></html>"

$html = $htmlParts -join "`r`n"
Set-Content -Path $ReportPath -Value $html -Encoding UTF8

Write-Host ""
Write-Host "===============================" -ForegroundColor Green
Write-Host "Health Check Complete" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green
Write-Host "Report saved to: $ReportPath" -ForegroundColor Cyan

if ($OpenReport) {
    Start-Process $ReportPath
}
