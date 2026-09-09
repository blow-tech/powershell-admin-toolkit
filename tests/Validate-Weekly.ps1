# Only local fixtures and mocked commands. No operational entry point has real modules.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Assert([bool]$Condition,[string]$Message) {if (-not $Condition) {throw $Message}}
function Load-Functions([string]$Path) {
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $Path),[ref]$tokens,[ref]$errors)
    if ($errors.Count) {throw ($errors | Out-String)}
    [scriptblock]::Create(($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$false) | ForEach-Object {$_.Extent.Text}) -join "`n")
}
function Invoke-Fixture([string]$Path,[hashtable]$Arguments) {
    & ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root $Path)))) @Arguments
}
function Import-Module {}
function Send-MailMessage {throw 'UNEXPECTED SMTP'}
function Get-MgContext {[pscustomobject]@{TenantId='33333333-3333-3333-3333-333333333333';AuthType='AppOnly';Scopes=@()}}

. (Load-Functions 'ActiveDirectory/Get-LockedOutLocation.ps1')
$event=[pscustomobject]@{MachineName='dc.example.test';Id=4740;RecordId=7;TimeCreated=(Get-Date)}
$event | Add-Member ScriptMethod ToXml { '<Event><EventData><Data Name="TargetDomainName">caller</Data><Data Name="TargetSid">S-1-5-21-100</Data><Data Name="TargetUserName">alice</Data></EventData></Event>' }
Assert ($null -eq (ConvertFrom-LockoutEvent $event 'S-1-5-21-10')) 'SID prefixes must not match.'
Assert ((ConvertFrom-LockoutEvent $event 'S-1-5-21-100').LockedOutLocation -eq 'caller') 'Named event fields must survive reordering.'
$failed=$false;try {ConvertFrom-LockoutEvent $event ''} catch {$failed=$true}
Assert $failed 'Empty target SID must be rejected.'
function Get-ADUser {[pscustomobject]@{SID='S-1-5-21-100'}}
function Get-WinEvent {throw 'Denied fixture'}
$r=@(Get-LockedOutLocation -Identity alice -DomainController dc.example.test)
Assert ($r.Count -eq 1 -and $r[0].Status -eq 'UNKNOWN') 'Denied log must not appear empty/healthy.'
function Get-WinEvent {$event}
$r=@(Get-LockedOutLocation -Identity alice -DomainController dc.example.test -MaxEvents 1)
Assert ($r[0].Status -eq 'TRUNCATED' -and $r[0].Matches.Count -eq 1) 'Cap must mark incomplete coverage.'
Write-Output 'PASS: lockout SID, reordered XML, denied query and truncation.'

. (Load-Functions 'ActiveDirectory/Get-LastLogon')
$r=ConvertTo-LogonObservation ([pscustomobject]@{LastLogonDate=$null})
Assert ($r.TimestampStatus -eq 'UNKNOWN' -and $null -eq $r.LastLogonDate) 'Missing timestamp is not never logged on.'
$r=ConvertTo-LogonObservation ([pscustomobject]@{LastLogonDate=(Get-Date).AddDays(-2)})
Assert ($r.TimestampStatus -eq 'ApproximateReplicated') 'Replicated timestamps must be labelled approximate.'
Write-Output 'PASS: approximate and missing logon observations.'

. (Load-Functions 'ActiveDirectory/GetUsersLogonLogoffEvents')
$logon=[pscustomobject]@{Id=4648;MachineName='host.example.test';RecordId=9;TimeCreated=(Get-Date)}
$logon | Add-Member ScriptMethod ToXml {'<Event><EventData><Data Name="TargetUserName">alice</Data><Data Name="SubjectUserName">bob</Data></EventData></Event>'}
Assert ((ConvertFrom-LogonAuditEvent $logon).Event -eq 'ExplicitCredentialAttempt') '4648 is not a successful logon.'
$logon.Id=4647
Assert ((ConvertFrom-LogonAuditEvent $logon).Account -eq 'bob') '4647 must use SubjectUserName.'
function Get-WinEvent {throw 'Access denied fixture'}
Assert ((Get-ComputerLogonEvidence 'host.example.test' (Get-Date)).Status -eq 'UNKNOWN') 'Denied logon collection must be UNKNOWN.'
Write-Output 'PASS: localized-message-independent event decoding and failed collection.'

. (Load-Functions 'scripts/Send Password Expiry Notifications to M365 Users')
$now=[datetimeoffset]::UtcNow
$user=[pscustomobject]@{Id='44444444-4444-4444-4444-444444444444';UserPrincipalName='different@example.test';Mail='actual@example.test';AccountEnabled=$true;UserType='Member';OnPremisesSyncEnabled=$false;AssignedLicenses=@();PasswordPolicies='';LastPasswordChangeDateTime=$now.AddDays(-89)}
$domains=@{'example.test'=[pscustomobject]@{Id='example.test';AuthenticationType='Managed';PasswordValidityPeriodInDays=90}}
Assert ((Get-CloudPasswordExpiryPlan $user $domains $now 7).Status -eq 'Eligible') 'Cloud-only known policy should produce a plan.'
Assert ((Get-CloudPasswordExpiryPlan $user $domains $now 7 -LicensedUsersOnly).Status -eq 'Excluded') 'Empty license arrays are unlicensed.'
$user.PasswordPolicies='DisableStrongPassword, DisablePasswordExpiration'
Assert ((Get-CloudPasswordExpiryPlan $user $domains $now 7).Status -eq 'Excluded') 'Comma-separated never-expire policy must be honored.'
$user.PasswordPolicies=''
Assert ((Get-CloudPasswordExpiryPlan $user @{} $now 7).Status -eq 'UNKNOWN') 'Missing policy must not default to 90 days.'
$user.OnPremisesSyncEnabled=$true
Assert ((Get-CloudPasswordExpiryPlan $user $domains $now 7).Status -eq 'Excluded') 'Synchronized users require separate policy validation.'
$user.OnPremisesSyncEnabled=$false
$domains['example.test'].AuthenticationType='Federated'
Assert ((Get-CloudPasswordExpiryPlan $user $domains $now 7).Status -eq 'Excluded') 'Federated users must not be sent cloud policy notices.'
$domains['example.test'].AuthenticationType='Managed'
Write-Output 'PASS: cloud-expiry policies, licensing, synchronized and federated exclusions.'

$temp=Join-Path ([IO.Path]::GetTempPath()) ('weekly-fixtures-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $temp
try {
    function Get-MgDomain {$domains['example.test']}
    function Get-MgUser {$user}
    $script:MailCalls=0
    function Send-MgUserMail {$script:MailCalls++}
    $args=@{TenantId='33333333-3333-3333-3333-333333333333';DaysToExpiry=7}
    $path='scripts/Send Password Expiry Notifications to M365 Users'
    $r=@(Invoke-Fixture $path $args)
    Assert ($script:MailCalls -eq 0 -and $r[0].Recipient -eq 'actual@example.test') 'Default preview must use directory mail and never send.'
    $args.Send=$true;$args.FromAddress='sender@example.test';$args.StateDirectory=$temp;$args.WhatIf=$true
    $null=Invoke-Fixture $path $args
    Assert ($script:MailCalls -eq 0 -and @(Get-ChildItem $temp -Filter '*.state').Count -eq 0) 'WhatIf must not send or consume state.'
    $args.Remove('WhatIf');$args.Confirm=$false
    $null=Invoke-Fixture $path $args
    $r=@(Invoke-Fixture $path $args)
    Assert ($script:MailCalls -eq 1 -and $r[0].Status -eq 'Suppressed') 'Same-day repeat must not send twice.'
    $user.Id='55555555-5555-5555-5555-555555555555'
    function Send-MgUserMail {$script:MailCalls++;throw 'Ambiguous mail result fixture'}
    $failed=$false;try {$null=Invoke-Fixture $path $args} catch {$failed=$true}
    Assert $failed 'Failed send must terminate and retain pending evidence.'
    $null=Invoke-Fixture $path $args
    Assert ($script:MailCalls -eq 2) 'Uncertain mail result must not be automatically retried.'
    Write-Output 'PASS: mail preview, WhatIf, dedup and ambiguous failure; mocked delivery only.'

    function Get-GPO {param($Domain) [pscustomobject]@{Id=[guid]::NewGuid();DisplayName="$Domain-policy";DomainName=$Domain}}
    function Get-GPOReport {'<GPO><LinksTo><SOMPath>OU=fixture</SOMPath></LinksTo></GPO>'}
    $null=Invoke-Fixture 'scripts/Get-DomanisGPO.ps1' @{Domains=@('one.test','two.test');ExportPath=$temp}
    foreach ($domain in 'one.test','two.test') {
        $rows=@(Import-Csv -LiteralPath (Join-Path $temp "$domain-GPOReport.csv"))
        Assert ($rows.Count -eq 1 -and $rows[0].Doamin -eq $domain) 'GPO export must not include previous domains.'
    }
    Write-Output 'PASS: isolated per-domain GPO exports.'

    . (Load-Functions 'ExchangeOnline/Find_Inactive_Distrib_list.ps1')
    $HistoricalMessageTraceReportPath=Join-Path $temp 'trace.csv'
    [IO.File]::WriteAllText($HistoricalMessageTraceReportPath,"recipient_status,origin_timestamp_utc`r`ngroup@example.test##Receive,2026-01-31T12:00:00Z`r`ngroup@example.test##Receive,2026-02-01T12:00:00Z`r`n")
    $before=(Get-FileHash -LiteralPath $HistoricalMessageTraceReportPath).Hash
    $global:DistributionLists=@{'group@example.test'='group@example.test'}
    $global:InactiveDistributionLists=@{}
    GettingInactiveDistributionLists
    Assert ($global:InactiveDistributionLists['group@example.test'][0] -eq [datetime]'2026-02-01T12:00:00Z') 'Latest trace must compare dates, not day-first strings.'
    Assert ((Get-FileHash -LiteralPath $HistoricalMessageTraceReportPath).Hash -eq $before) 'Trace evidence must not be rewritten.'
    Write-Output 'PASS: trace evidence preservation and cross-month date comparison.'

    function Get-MgReportAuthenticationMethodUserRegistrationDetail {
        [pscustomobject]@{Id='one';IsMfaRegistered=$false;IsMfaCapable=$false}
        [pscustomobject]@{Id='two';IsMfaRegistered=$true;IsMfaCapable=$true}
        [pscustomobject]@{Id='unknown';IsMfaRegistered=$null;IsMfaCapable=$null}
    }
    $r=@(Invoke-Fixture 'ActiveDirectory/Get_MFA_Status.ps1' @{TenantId='33333333-3333-3333-3333-333333333333';UnregisteredOnly=$true})
    Assert ($r.Count -eq 2 -and $r[1].CollectionState -eq 'UNKNOWN' -and $r[0].EnforcementStatus -eq 'NotAssessed') 'Unknown registration is not proof of enforcement.'
    function Get-MgReportAuthenticationMethodUserRegistrationDetail {throw 'Denied registration report fixture'}
    $failed=$false;try {Invoke-Fixture 'ActiveDirectory/Get_MFA_Status.ps1' @{TenantId='33333333-3333-3333-3333-333333333333';OutputPath=(Join-Path $temp 'denied.csv')}} catch {$failed=$true}
    Assert ($failed -and -not (Test-Path (Join-Path $temp 'denied.csv'))) 'Failed MFA collection must not publish a clean report.'
    Write-Output 'PASS: MFA registration scope and collection failure.'
} finally {Remove-Item -LiteralPath $temp -Recurse -Force}

foreach ($path in 'scripts/inventory/Audit.ps1','scripts/inventory/systeminfo_report.ps1') {
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $path),[ref]$tokens,[ref]$errors)
    $commands=$ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true)
    Assert (@($commands | Where-Object {$_.Extent.Text -match 'Win32_Product'}).Count -eq 0) 'Inventory must not query the MSI product provider.'
}
Write-Output 'PASS: inventory MSI provider exclusion. All weekly fixtures passed.'

foreach ($path in 'ExchangeOnline/Audit PIM role.ps1','ExchangeOnline/Trace Emails Sent to External Domains','ExchangeOnline/Export All Mailboxes in Microsoft 365 .ps1','ExchangeOnline/Shared Mailbox Size Report','ExchangeOnline/Find_Inactive_Distrib_list.ps1') {
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $path),[ref]$tokens,[ref]$errors)
    $names=@($ast.ParamBlock.Parameters | ForEach-Object {$_.Name.VariablePath.UserPath})
    Assert ($names -notcontains 'Password' -and $names -contains 'Credential') 'EXO entry points must not accept plaintext Password arguments.'
}
Write-Output 'PASS: EXO plaintext credential parameter removal.'

. (Load-Functions 'scripts/inventory/Monitor_SystemResources.ps1')
function Get-Counter {
    param($Counter)
    $samples=if ($Counter -like '*LogicalDisk*') {
        @([pscustomobject]@{InstanceName='_Total';CookedValue=50},[pscustomobject]@{InstanceName='c:';CookedValue=10},[pscustomobject]@{InstanceName='d:';CookedValue=80})
    } elseif ($Counter -like '*Network*') {
        @([pscustomobject]@{InstanceName='ethernet';CookedValue=1024})
    } else {@([pscustomobject]@{InstanceName='_Total';CookedValue=20})}
    [pscustomobject]@{CounterSamples=$samples}
}
$metrics=Get-SystemMetrics
$CPUThreshold=80;$MemoryThreshold=80;$DiskThreshold=80
$alerts=@(Test-Thresholds $metrics)
Assert ($metrics.Disk.Count -eq 2 -and $alerts.Count -eq 1 -and $alerts[0] -match 'c:.*90') 'Disk free-percent must be expanded by drive and inverted exactly once.'
function Get-Counter {throw 'Counters unavailable'}
$failed=$false;try {Get-SystemMetrics} catch {$failed=$true}
Assert $failed 'Unavailable counters must not become zero usage.'
Write-Output 'PASS: per-instance disk thresholds and unavailable counters.'
