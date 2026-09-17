#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Monitor Active Directory

.DESCRIPTION
    Monitoring script for Windows Active Directory Domain Services.
    Configures comprehensive monitoring including health monitoring,
    performance monitoring, event monitoring, and alerting.

.PARAMETER ServerName
    Name of the server to monitor

.PARAMETER DomainName
    Name of the domain to monitor

.PARAMETER MonitoringLevel
    Level of monitoring to configure

.PARAMETER AlertLevel
    Level of alerting to configure

.PARAMETER AlertTypes
    Types of alerts to configure

.PARAMETER SmtpServer
    SMTP server for email alerts

.PARAMETER SmtpPort
    SMTP port for email alerts

.PARAMETER SmtpUsername
    SMTP username for email alerts

.PARAMETER SmtpPassword
    SMTP password for email alerts

.PARAMETER Recipients
    Email recipients for alerts

.PARAMETER WebhookUrl
    Webhook URL for alerts

.PARAMETER SmsProvider
    SMS provider for alerts

.PARAMETER SmsApiKey
    SMS API key for alerts

.PARAMETER SmsApiSecret
    SMS API secret for alerts

.PARAMETER SmsFromNumber
    SMS from number for alerts

.PARAMETER SmsRecipients
    SMS recipients for alerts

.PARAMETER ReportType
    Type of report to generate

.PARAMETER DaysBack
    Number of days back for reports

.PARAMETER OutputFormat
    Output format for reports

.PARAMETER OutputPath
    Output path for reports

.PARAMETER GenerateReport
    Generate monitoring report

.PARAMETER ReportFormat
    Format for monitoring report

.PARAMETER ReportPath
    Path for monitoring report

.EXAMPLE
    .\Monitor-ActiveDirectory.ps1 -ServerName "DC-SERVER01" -DomainName "contoso.com" -MonitoringLevel "Standard"

.EXAMPLE
    .\Monitor-ActiveDirectory.ps1 -ServerName "DC-SERVER01" -DomainName "contoso.com" -MonitoringLevel "Comprehensive" -AlertLevel "High" -AlertTypes @("Email", "SMS", "Webhook") -SmtpServer "smtp.contoso.com" -SmtpPort 587 -SmtpUsername "alerts@contoso.com" -SmtpPassword "SecurePassword123" -Recipients @("admin@contoso.com", "ops@contoso.com") -WebhookUrl "https://webhook.contoso.com/alerts" -SmsProvider "Twilio" -SmsApiKey "your-api-key" -SmsApiSecret "your-api-secret" -SmsFromNumber "+1234567890" -SmsRecipients @("+1234567890", "+0987654321") -ReportType "Comprehensive" -DaysBack 7 -OutputFormat "HTML" -OutputPath "C:\Reports\AD-Monitoring-Report.html" -GenerateReport -ReportFormat "PDF" -ReportPath "C:\Reports\AD-Monitoring-Report.pdf"

.NOTES
    Author: Adrian Johnson (adrian207@gmail.com)
    Version: 1.0.0
    Date: October 2025
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerName,
    
    [Parameter(Mandatory = $true)]
    [string]$DomainName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Basic", "Standard", "Comprehensive", "Maximum")]
    [string]$MonitoringLevel = "Standard",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Basic", "Standard", "High", "Maximum")]
    [string]$AlertLevel = "Standard",
    
    [Parameter(Mandatory = $false)]
    [string[]]$AlertTypes = @("Email", "Webhook"),
    
    [Parameter(Mandatory = $false)]
    [string]$SmtpServer,
    
    [Parameter(Mandatory = $false)]
    [int]$SmtpPort = 587,
    
    [Parameter(Mandatory = $false)]
    [string]$SmtpUsername,
    
    [Parameter(Mandatory = $false)]
    [string]$SmtpPassword,
    
    [Parameter(Mandatory = $false)]
    [string[]]$Recipients = @(),
    
    [Parameter(Mandatory = $false)]
    [string]$WebhookUrl,
    
    [Parameter(Mandatory = $false)]
    [string]$SmsProvider,
    
    [Parameter(Mandatory = $false)]
    [string]$SmsApiKey,
    
    [Parameter(Mandatory = $false)]
    [string]$SmsApiSecret,
    
    [Parameter(Mandatory = $false)]
    [string]$SmsFromNumber,
    
    [Parameter(Mandatory = $false)]
    [string[]]$SmsRecipients = @(),
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Health", "Performance", "Security", "Compliance", "Summary", "Comprehensive")]
    [string]$ReportType = "Comprehensive",
    
    [Parameter(Mandatory = $false)]
    [int]$DaysBack = 7,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("HTML", "PDF", "CSV", "JSON", "XML")]
    [string]$OutputFormat = "HTML",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateReport,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("HTML", "PDF", "CSV", "JSON", "XML")]
    [string]$ReportFormat = "PDF",
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath
)

# Import required modules
$modulePath = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesPath = Join-Path $modulePath "..\..\Modules"

Import-Module "$modulesPath\AD-Core.psm1" -Force -ErrorAction Stop
Import-Module "$modulesPath\AD-Security.psm1" -Force -ErrorAction Stop
Import-Module "$modulesPath\AD-Monitoring.psm1" -Force -ErrorAction Stop
Import-Module "$modulesPath\AD-Troubleshooting.psm1" -Force -ErrorAction Stop

# Logging function
function Write-MonitoringLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [AD-Monitoring] $Message"
    
    switch ($Level) {
        "Error" { Write-Host $logMessage -ForegroundColor Red }
        "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
        "Success" { Write-Host $logMessage -ForegroundColor Green }
        "Info" { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage -ForegroundColor White }
    }
}

# Error handling
$ErrorActionPreference = "Stop"

try {
    Write-MonitoringLog "Starting Active Directory monitoring configuration on $ServerName" "Info"
    Write-MonitoringLog "Domain Name: $DomainName" "Info"
    Write-MonitoringLog "Monitoring Level: $MonitoringLevel" "Info"
    Write-MonitoringLog "Alert Level: $AlertLevel" "Info"
    Write-MonitoringLog "Alert Types: $($AlertTypes -join ', ')" "Info"
    
    # Monitoring results
    $monitoringResults = @{
        ServerName = $ServerName
        DomainName = $DomainName
        MonitoringLevel = $MonitoringLevel
        AlertLevel = $AlertLevel
        AlertTypes = $AlertTypes
        Timestamp = Get-Date
        MonitoringSteps = @()
        Issues = @()
        Recommendations = @()
        OverallResult = "Unknown"
    }
    
    # Configure monitoring based on level
    switch ($MonitoringLevel) {
        "Basic" {
            Write-MonitoringLog "Applying basic monitoring configuration..." "Info"
            
            # Step 1: Configure basic health monitoring
            try {
                $healthMonitoring = Get-ADHealthMonitoring -ServerName $ServerName -IncludeDetails -IncludeReplication -IncludeFSMO -IncludeDNS -IncludeTimeSync
                
                if ($healthMonitoring) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Basic Health Monitoring"
                        Status = "Completed"
                        Details = "Basic health monitoring configured successfully"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Basic health monitoring configured successfully" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Basic Health Monitoring"
                        Status = "Failed"
                        Details = "Failed to configure basic health monitoring"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure basic health monitoring"
                    $monitoringResults.Recommendations += "Check health monitoring configuration parameters"
                    Write-MonitoringLog "Failed to configure basic health monitoring" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Basic Health Monitoring"
                    Status = "Failed"
                    Details = "Exception during basic health monitoring configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during basic health monitoring configuration"
                $monitoringResults.Recommendations += "Check error logs and health monitoring parameters"
                Write-MonitoringLog "Exception during basic health monitoring configuration: $($_.Exception.Message)" "Error"
            }
        }
        
        "Standard" {
            Write-MonitoringLog "Applying standard monitoring configuration..." "Info"
            
            # Step 1: Configure health monitoring
            try {
                $healthMonitoring = Get-ADHealthMonitoring -ServerName $ServerName -IncludeDetails -IncludeReplication -IncludeFSMO -IncludeDNS -IncludeTimeSync
                
                if ($healthMonitoring) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Health Monitoring (Standard)"
                        Status = "Completed"
                        Details = "Health monitoring configured with standard settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Health monitoring configured with standard settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Health Monitoring (Standard)"
                        Status = "Failed"
                        Details = "Failed to configure health monitoring"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure health monitoring"
                    $monitoringResults.Recommendations += "Check health monitoring configuration parameters"
                    Write-MonitoringLog "Failed to configure health monitoring" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Health Monitoring (Standard)"
                    Status = "Failed"
                    Details = "Exception during health monitoring configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during health monitoring configuration"
                $monitoringResults.Recommendations += "Check error logs and health monitoring parameters"
                Write-MonitoringLog "Exception during health monitoring configuration: $($_.Exception.Message)" "Error"
            }
            
            # Step 2: Configure performance monitoring
            try {
                $performanceMonitoring = Get-ADPerformanceMonitoring -ServerName $ServerName -DurationMinutes 60 -Metrics @("CPU", "Memory", "Disk", "Network")
                
                if ($performanceMonitoring) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Performance Monitoring (Standard)"
                        Status = "Completed"
                        Details = "Performance monitoring configured with standard settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Performance monitoring configured with standard settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Performance Monitoring (Standard)"
                        Status = "Failed"
                        Details = "Failed to configure performance monitoring"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure performance monitoring"
                    $monitoringResults.Recommendations += "Check performance monitoring configuration parameters"
                    Write-MonitoringLog "Failed to configure performance monitoring" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Performance Monitoring (Standard)"
                    Status = "Failed"
                    Details = "Exception during performance monitoring configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during performance monitoring configuration"
                $monitoringResults.Recommendations += "Check error logs and performance monitoring parameters"
                Write-MonitoringLog "Exception during performance monitoring configuration: $($_.Exception.Message)" "Error"
            }
            
            # Step 3: Configure alerting
            try {
                $alertingResult = Set-ADAlerting -ServerName $ServerName -AlertLevel $AlertLevel -AlertTypes $AlertTypes -SmtpServer $SmtpServer -SmtpPort $SmtpPort -SmtpUsername $SmtpUsername -SmtpPassword $SmtpPassword -Recipients $Recipients -WebhookUrl $WebhookUrl -SmsProvider $SmsProvider -SmsApiKey $SmsApiKey -SmsApiSecret $SmsApiSecret -SmsFromNumber $SmsFromNumber -SmsRecipients $SmsRecipients
                
                if ($alertingResult) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Alerting (Standard)"
                        Status = "Completed"
                        Details = "Alerting configured with standard settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Alerting configured with standard settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Alerting (Standard)"
                        Status = "Failed"
                        Details = "Failed to configure alerting"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure alerting"
                    $monitoringResults.Recommendations += "Check alerting configuration parameters"
                    Write-MonitoringLog "Failed to configure alerting" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Alerting (Standard)"
                    Status = "Failed"
                    Details = "Exception during alerting configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during alerting configuration"
                $monitoringResults.Recommendations += "Check error logs and alerting parameters"
                Write-MonitoringLog "Exception during alerting configuration: $($_.Exception.Message)" "Error"
            }
        }
        
        "Comprehensive" {
            Write-MonitoringLog "Applying comprehensive monitoring configuration..." "Info"
            
            # Step 1: Configure health monitoring
            try {
                $healthMonitoring = Get-ADHealthMonitoring -ServerName $ServerName -IncludeDetails -IncludeReplication -IncludeFSMO -IncludeDNS -IncludeTimeSync
                
                if ($healthMonitoring) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Health Monitoring (Comprehensive)"
                        Status = "Completed"
                        Details = "Health monitoring configured with comprehensive settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Health monitoring configured with comprehensive settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Health Monitoring (Comprehensive)"
                        Status = "Failed"
                        Details = "Failed to configure health monitoring"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure health monitoring"
                    $monitoringResults.Recommendations += "Check health monitoring configuration parameters"
                    Write-MonitoringLog "Failed to configure health monitoring" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Health Monitoring (Comprehensive)"
                    Status = "Failed"
                    Details = "Exception during health monitoring configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during health monitoring configuration"
                $monitoringResults.Recommendations += "Check error logs and health monitoring parameters"
                Write-MonitoringLog "Exception during health monitoring configuration: $($_.Exception.Message)" "Error"
            }
            
            # Step 2: Configure performance monitoring
            try {
                $performanceMonitoring = Get-ADPerformanceMonitoring -ServerName $ServerName -DurationMinutes 60 -Metrics @("CPU", "Memory", "Disk", "Network")
                
                if ($performanceMonitoring) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Performance Monitoring (Comprehensive)"
                        Status = "Completed"
                        Details = "Performance monitoring configured with comprehensive settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Performance monitoring configured with comprehensive settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Performance Monitoring (Comprehensive)"
                        Status = "Failed"
                        Details = "Failed to configure performance monitoring"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure performance monitoring"
                    $monitoringResults.Recommendations += "Check performance monitoring configuration parameters"
                    Write-MonitoringLog "Failed to configure performance monitoring" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Performance Monitoring (Comprehensive)"
                    Status = "Failed"
                    Details = "Exception during performance monitoring configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during performance monitoring configuration"
                $monitoringResults.Recommendations += "Check error logs and performance monitoring parameters"
                Write-MonitoringLog "Exception during performance monitoring configuration: $($_.Exception.Message)" "Error"
            }
            
            # Step 3: Configure event monitoring
            try {
                $eventMonitoring = Get-ADEventMonitoring -ServerName $ServerName -LogLevel "All" -MaxEvents 1000 -HoursBack 24
                
                if ($eventMonitoring) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Event Monitoring (Comprehensive)"
                        Status = "Completed"
                        Details = "Event monitoring configured with comprehensive settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Event monitoring configured with comprehensive settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Event Monitoring (Comprehensive)"
                        Status = "Failed"
                        Details = "Failed to configure event monitoring"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure event monitoring"
                    $monitoringResults.Recommendations += "Check event monitoring configuration parameters"
                    Write-MonitoringLog "Failed to configure event monitoring" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Event Monitoring (Comprehensive)"
                    Status = "Failed"
                    Details = "Exception during event monitoring configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during event monitoring configuration"
                $monitoringResults.Recommendations += "Check error logs and event monitoring parameters"
                Write-MonitoringLog "Exception during event monitoring configuration: $($_.Exception.Message)" "Error"
            }
            
            # Step 4: Configure alerting
            try {
                $alertingResult = Set-ADAlerting -ServerName $ServerName -AlertLevel $AlertLevel -AlertTypes $AlertTypes -SmtpServer $SmtpServer -SmtpPort $SmtpPort -SmtpUsername $SmtpUsername -SmtpPassword $SmtpPassword -Recipients $Recipients -WebhookUrl $WebhookUrl -SmsProvider $SmsProvider -SmsApiKey $SmsApiKey -SmsApiSecret $SmsApiSecret -SmsFromNumber $SmsFromNumber -SmsRecipients $SmsRecipients
                
                if ($alertingResult) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Alerting (Comprehensive)"
                        Status = "Completed"
                        Details = "Alerting configured with comprehensive settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Alerting configured with comprehensive settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Alerting (Comprehensive)"
                        Status = "Failed"
                        Details = "Failed to configure alerting"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure alerting"
                    $monitoringResults.Recommendations += "Check alerting configuration parameters"
                    Write-MonitoringLog "Failed to configure alerting" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Alerting (Comprehensive)"
                    Status = "Failed"
                    Details = "Exception during alerting configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during alerting configuration"
                $monitoringResults.Recommendations += "Check error logs and alerting parameters"
                Write-MonitoringLog "Exception during alerting configuration: $($_.Exception.Message)" "Error"
            }
            
            # Step 5: Generate monitoring report
            try {
                $monitoringReport = Get-ADMonitoringReport -ServerName $ServerName -ReportType $ReportType -DaysBack $DaysBack -OutputFormat $OutputFormat -OutputPath $OutputPath
                
                if ($monitoringReport) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Generate Monitoring Report (Comprehensive)"
                        Status = "Completed"
                        Details = "Monitoring report generated with comprehensive settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Monitoring report generated with comprehensive settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Generate Monitoring Report (Comprehensive)"
                        Status = "Failed"
                        Details = "Failed to generate monitoring report"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to generate monitoring report"
                    $monitoringResults.Recommendations += "Check monitoring report configuration parameters"
                    Write-MonitoringLog "Failed to generate monitoring report" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Generate Monitoring Report (Comprehensive)"
                    Status = "Failed"
                    Details = "Exception during monitoring report generation: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during monitoring report generation"
                $monitoringResults.Recommendations += "Check error logs and monitoring report parameters"
                Write-MonitoringLog "Exception during monitoring report generation: $($_.Exception.Message)" "Error"
            }
        }
        
        "Maximum" {
            Write-MonitoringLog "Applying maximum monitoring configuration..." "Info"
            
            # Step 1: Configure health monitoring
            try {
                $healthMonitoring = Get-ADHealthMonitoring -ServerName $ServerName -IncludeDetails -IncludeReplication -IncludeFSMO -IncludeDNS -IncludeTimeSync
                
                if ($healthMonitoring) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Health Monitoring (Maximum)"
                        Status = "Completed"
                        Details = "Health monitoring configured with maximum settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Health monitoring configured with maximum settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Health Monitoring (Maximum)"
                        Status = "Failed"
                        Details = "Failed to configure health monitoring"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure health monitoring"
                    $monitoringResults.Recommendations += "Check health monitoring configuration parameters"
                    Write-MonitoringLog "Failed to configure health monitoring" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Health Monitoring (Maximum)"
                    Status = "Failed"
                    Details = "Exception during health monitoring configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during health monitoring configuration"
                $monitoringResults.Recommendations += "Check error logs and health monitoring parameters"
                Write-MonitoringLog "Exception during health monitoring configuration: $($_.Exception.Message)" "Error"
            }
            
            # Step 2: Configure performance monitoring
            try {
                $performanceMonitoring = Get-ADPerformanceMonitoring -ServerName $ServerName -DurationMinutes 60 -Metrics @("CPU", "Memory", "Disk", "Network")
                
                if ($performanceMonitoring) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Performance Monitoring (Maximum)"
                        Status = "Completed"
                        Details = "Performance monitoring configured with maximum settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Performance monitoring configured with maximum settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Performance Monitoring (Maximum)"
                        Status = "Failed"
                        Details = "Failed to configure performance monitoring"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure performance monitoring"
                    $monitoringResults.Recommendations += "Check performance monitoring configuration parameters"
                    Write-MonitoringLog "Failed to configure performance monitoring" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Performance Monitoring (Maximum)"
                    Status = "Failed"
                    Details = "Exception during performance monitoring configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during performance monitoring configuration"
                $monitoringResults.Recommendations += "Check error logs and performance monitoring parameters"
                Write-MonitoringLog "Exception during performance monitoring configuration: $($_.Exception.Message)" "Error"
            }
            
            # Step 3: Configure event monitoring
            try {
                $eventMonitoring = Get-ADEventMonitoring -ServerName $ServerName -LogLevel "All" -MaxEvents 1000 -HoursBack 24
                
                if ($eventMonitoring) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Event Monitoring (Maximum)"
                        Status = "Completed"
                        Details = "Event monitoring configured with maximum settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Event monitoring configured with maximum settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Event Monitoring (Maximum)"
                        Status = "Failed"
                        Details = "Failed to configure event monitoring"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure event monitoring"
                    $monitoringResults.Recommendations += "Check event monitoring configuration parameters"
                    Write-MonitoringLog "Failed to configure event monitoring" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Event Monitoring (Maximum)"
                    Status = "Failed"
                    Details = "Exception during event monitoring configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during event monitoring configuration"
                $monitoringResults.Recommendations += "Check error logs and event monitoring parameters"
                Write-MonitoringLog "Exception during event monitoring configuration: $($_.Exception.Message)" "Error"
            }
            
            # Step 4: Configure alerting
            try {
                $alertingResult = Set-ADAlerting -ServerName $ServerName -AlertLevel $AlertLevel -AlertTypes $AlertTypes -SmtpServer $SmtpServer -SmtpPort $SmtpPort -SmtpUsername $SmtpUsername -SmtpPassword $SmtpPassword -Recipients $Recipients -WebhookUrl $WebhookUrl -SmsProvider $SmsProvider -SmsApiKey $SmsApiKey -SmsApiSecret $SmsApiSecret -SmsFromNumber $SmsFromNumber -SmsRecipients $SmsRecipients
                
                if ($alertingResult) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Alerting (Maximum)"
                        Status = "Completed"
                        Details = "Alerting configured with maximum settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Alerting configured with maximum settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Configure Alerting (Maximum)"
                        Status = "Failed"
                        Details = "Failed to configure alerting"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to configure alerting"
                    $monitoringResults.Recommendations += "Check alerting configuration parameters"
                    Write-MonitoringLog "Failed to configure alerting" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Configure Alerting (Maximum)"
                    Status = "Failed"
                    Details = "Exception during alerting configuration: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during alerting configuration"
                $monitoringResults.Recommendations += "Check error logs and alerting parameters"
                Write-MonitoringLog "Exception during alerting configuration: $($_.Exception.Message)" "Error"
            }
            
            # Step 5: Generate monitoring report
            try {
                $monitoringReport = Get-ADMonitoringReport -ServerName $ServerName -ReportType $ReportType -DaysBack $DaysBack -OutputFormat $OutputFormat -OutputPath $OutputPath
                
                if ($monitoringReport) {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Generate Monitoring Report (Maximum)"
                        Status = "Completed"
                        Details = "Monitoring report generated with maximum settings"
                        Severity = "Info"
                    }
                    Write-MonitoringLog "Monitoring report generated with maximum settings" "Success"
                } else {
                    $monitoringResults.MonitoringSteps += @{
                        Step = "Generate Monitoring Report (Maximum)"
                        Status = "Failed"
                        Details = "Failed to generate monitoring report"
                        Severity = "Error"
                    }
                    $monitoringResults.Issues += "Failed to generate monitoring report"
                    $monitoringResults.Recommendations += "Check monitoring report configuration parameters"
                    Write-MonitoringLog "Failed to generate monitoring report" "Error"
                }
            }
            catch {
                $monitoringResults.MonitoringSteps += @{
                    Step = "Generate Monitoring Report (Maximum)"
                    Status = "Failed"
                    Details = "Exception during monitoring report generation: $($_.Exception.Message)"
                    Severity = "Error"
                }
                $monitoringResults.Issues += "Exception during monitoring report generation"
                $monitoringResults.Recommendations += "Check error logs and monitoring report parameters"
                Write-MonitoringLog "Exception during monitoring report generation: $($_.Exception.Message)" "Error"
            }
        }
        
        default {
            Write-MonitoringLog "Unknown monitoring level: $MonitoringLevel" "Error"
            $monitoringResults.MonitoringSteps += @{
                Step = "Monitoring Level Validation"
                Status = "Failed"
                Details = "Unknown monitoring level: $MonitoringLevel"
                Severity = "Error"
            }
            $monitoringResults.Issues += "Unknown monitoring level: $MonitoringLevel"
            $monitoringResults.Recommendations += "Use a valid monitoring level"
        }
    }
    
    # Determine overall result
    $failedSteps = $monitoringResults.MonitoringSteps | Where-Object { $_.Status -eq "Failed" }
    if ($failedSteps.Count -eq 0) {
        $monitoringResults.OverallResult = "Success"
    } elseif ($failedSteps.Count -lt $monitoringResults.MonitoringSteps.Count / 2) {
        $monitoringResults.OverallResult = "Partial Success"
    } else {
        $monitoringResults.OverallResult = "Failed"
    }
    
    # Summary
    Write-MonitoringLog "=== MONITORING CONFIGURATION SUMMARY ===" "Info"
    Write-MonitoringLog "Server Name: $ServerName" "Info"
    Write-MonitoringLog "Domain Name: $DomainName" "Info"
    Write-MonitoringLog "Monitoring Level: $MonitoringLevel" "Info"
    Write-MonitoringLog "Alert Level: $AlertLevel" "Info"
    Write-MonitoringLog "Alert Types: $($AlertTypes -join ', ')" "Info"
    Write-MonitoringLog "Overall Result: $($monitoringResults.OverallResult)" "Info"
    Write-MonitoringLog "Monitoring Steps: $($monitoringResults.MonitoringSteps.Count)" "Info"
    Write-MonitoringLog "Issues: $($monitoringResults.Issues.Count)" "Info"
    Write-MonitoringLog "Recommendations: $($monitoringResults.Recommendations.Count)" "Info"
    
    if ($monitoringResults.Issues.Count -gt 0) {
        Write-MonitoringLog "Issues:" "Warning"
        foreach ($issue in $monitoringResults.Issues) {
            Write-MonitoringLog "  - $issue" "Warning"
        }
    }
    
    if ($monitoringResults.Recommendations.Count -gt 0) {
        Write-MonitoringLog "Recommendations:" "Info"
        foreach ($recommendation in $monitoringResults.Recommendations) {
            Write-MonitoringLog "  - $recommendation" "Info"
        }
    }
    
    Write-MonitoringLog "Active Directory monitoring configuration completed" "Success"
    
    return $monitoringResults
}
catch {
    Write-MonitoringLog "Active Directory monitoring configuration failed: $($_.Exception.Message)" "Error"
    Write-MonitoringLog "Stack Trace: $($_.ScriptStackTrace)" "Error"
    throw
}

<#
.NOTES
    Author: Adrian Johnson (adrian207@gmail.com)
    Version: 1.0.0
    Date: October 2025
    
    This script configures comprehensive monitoring for Windows Active Directory Domain Services
    including health monitoring, performance monitoring, event monitoring, and alerting.
    
    Features:
    - Basic Monitoring Configuration
    - Standard Monitoring Configuration
    - Comprehensive Monitoring Configuration
    - Maximum Monitoring Configuration
    - Health Monitoring
    - Performance Monitoring
    - Event Monitoring
    - Alerting Configuration
    - Monitoring Report Generation
    
    Prerequisites:
    - Windows Server 2016 or later
    - Active Directory Domain Services
    - Administrative privileges
    - Network connectivity
    - Sufficient storage space
    - Sufficient memory and CPU resources
    
    Dependencies:
    - AD-Core.psm1
    - AD-Security.psm1
    - AD-Monitoring.psm1
    - AD-Troubleshooting.psm1
    
    Usage Examples:
    .\Monitor-ActiveDirectory.ps1 -ServerName "DC-SERVER01" -DomainName "contoso.com" -MonitoringLevel "Standard"
    .\Monitor-ActiveDirectory.ps1 -ServerName "DC-SERVER01" -DomainName "contoso.com" -MonitoringLevel "Comprehensive" -AlertLevel "High" -AlertTypes @("Email", "SMS", "Webhook") -SmtpServer "smtp.contoso.com" -SmtpPort 587 -SmtpUsername "alerts@contoso.com" -SmtpPassword "SecurePassword123" -Recipients @("admin@contoso.com", "ops@contoso.com") -WebhookUrl "https://webhook.contoso.com/alerts" -SmsProvider "Twilio" -SmsApiKey "your-api-key" -SmsApiSecret "your-api-secret" -SmsFromNumber "+1234567890" -SmsRecipients @("+1234567890", "+0987654321") -ReportType "Comprehensive" -DaysBack 7 -OutputFormat "HTML" -OutputPath "C:\Reports\AD-Monitoring-Report.html" -GenerateReport -ReportFormat "PDF" -ReportPath "C:\Reports\AD-Monitoring-Report.pdf"
    
    Output:
    - Console logging with color-coded messages
    - Monitoring configuration results summary
    - Detailed monitoring configuration steps
    - Issues and recommendations
    - Comprehensive error handling
    
    Security Considerations:
    - Requires administrative privileges
    - Configures secure monitoring settings
    - Implements monitoring baselines
    - Enables monitoring logging
    - Configures monitoring compliance settings
    
    Performance Impact:
    - Minimal impact during monitoring configuration
    - Non-destructive operations
    - Configurable monitoring scope
    - Resource-aware monitoring configuration
#>
