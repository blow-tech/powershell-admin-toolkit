# Runs in a disposable CI runner. Parses scripts and uses only local fixtures/mocks.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Get-FunctionDefinitions([string]$RelativePath) {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $RelativePath),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
    $functions=$ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$false)
    [scriptblock]::Create(($functions | ForEach-Object { $_.Extent.Text }) -join "`n")
}
$parseFailures=@()
$files=@(Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and ($_.Extension -eq '.ps1' -or ($_.Extension -eq '' -and $_.Name -ne 'LICENSE'))
})
foreach ($file in $files) {
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    foreach ($errorRecord in $errors) { $parseFailures += "$($file.FullName):$($errorRecord.Extent.StartLineNumber) $($errorRecord.Message)" }
}
if ($parseFailures.Count) { throw ($parseFailures -join "`n") }
Write-Output "PASS: parsed $($files.Count) PowerShell sources (including extensionless scripts)."

. (Get-FunctionDefinitions 'ActiveDirectory/Check_suspicious_tasks.ps1')
function Get-ScheduledTask { throw 'Access denied fixture' }
$r=Invoke-TaskAssessment
Assert (-not $r.Succeeded -and $r.TasksChecked -eq 0) 'Denied task query must be UNKNOWN.'
function Get-ScheduledTask { @() }
Assert (-not (Invoke-TaskAssessment).Succeeded) 'Empty task scope must not be clean.'
function Get-ScheduledTask {
    [pscustomobject]@{TaskName='Update';TaskPath='\';Actions=@([pscustomobject]@{Execute='C:\Windows\System32\cmd.exe';Arguments='/c echo ok'},[pscustomobject]@{Execute='powershell.exe';Arguments='-EncodedCommand AAAA'})}
}
$r=Invoke-TaskAssessment
Assert ($r.Succeeded -and $r.TasksChecked -eq 1 -and $r.Findings.Count -eq 1) 'Every task action must be checked.'
$com=Get-TaskAnalysis ([pscustomobject]@{TaskName='COM';TaskPath='\';Actions=@([pscustomobject]@{ClassId='{fixture}'})})
Assert $com.Suspicious 'COM handlers must require review.'
function Get-ScheduledTask { [pscustomobject]@{TaskName='Bad';TaskPath='\';Actions=@([pscustomobject]@{Other='bad'})} }
Assert (-not (Invoke-TaskAssessment).Succeeded) 'Malformed action must not be clean.'
Write-Output 'PASS: task collection, empty scope, multiple actions, COM and malformed action fixtures.'

. (Get-FunctionDefinitions 'ActiveDirectory/Advanced-AD-HealthCheck.ps1')
$r=Invoke-Collection { throw 'Access denied' }
Assert (-not $r.Succeeded) 'Collection errors must not be successful empty results.'
$r=Invoke-Collection { @() }
Assert ($r.Succeeded -and $r.Data.Count -eq 0) 'Successful empty collection should remain distinguishable.'
. (Get-FunctionDefinitions 'ActiveDirectory/Environment Health-Check')
function Get-WinEvent { throw 'RPC denied fixture' }
$events=@(Get-EventLogSummaryChecks)
Assert (@($events | Where-Object Status -ne 'UNKNOWN').Count -eq 0) 'Unavailable event queries must be UNKNOWN.'
$html=New-HtmlReport -Results @([pscustomobject]@{Category='Backup';Item='Status';Status='UNKNOWN';Detail='Unavailable'}) -ComputerName 'fixture' -RunTime (Get-Date)
Assert ($html -match '<div class="overall">UNKNOWN</div>') 'Unknown mandatory checks must prevent green report.'
Write-Output 'PASS: collection and UNKNOWN health-report fixtures.'

. (Get-FunctionDefinitions 'ActiveDirectory/AutomateCompromisedAccount.ps1')
foreach ($i in 1..30) {
    $secret=New-RemediationPassword
    Assert ($secret.Length -ge 24 -and $secret -cmatch '[A-Z]' -and $secret -cmatch '[a-z]' -and $secret -match '[0-9]' -and $secret -match '[!@#$%*_=+\-]') 'Generated password must meet baseline character requirements.'
}
$secret=$null
Write-Output 'PASS: cryptographic password generator shape (secrets not printed).'

. (Get-FunctionDefinitions 'ActiveDirectory/Send-PasswordExpiry')
$now=[datetime]::UtcNow
$user=[pscustomobject]@{ObjectGUID=[guid]::NewGuid();mail='actual@example.test';SamAccountName='different';PasswordNeverExpires=$false;pwdLastSet=1;'msDS-UserPasswordExpiryTimeComputed'=$now.AddHours(3).ToFileTimeUtc()}
$notice=Get-PasswordExpiryPlan $user $now @(1)
Assert ($notice.Recipient -eq 'actual@example.test' -and -not $notice.Expired -and $notice.DaysUntilExpiry -eq 1) 'Use actual mail and do not round future expiry into expired.'
$user.'msDS-UserPasswordExpiryTimeComputed'=[long]::MaxValue
Assert ($null -eq (Get-PasswordExpiryPlan $user $now @(1))) 'Never-expiring sentinel must be skipped.'
Write-Output 'PASS: password expiry address, rounding and sentinel fixtures.'

. (Get-FunctionDefinitions 'ActiveDirectory/Montor_FirewallChanges.ps1')
$a=[pscustomobject]@{Records=@{one='a';two='b'}}
$b=[pscustomobject]@{Records=@{two='b';one='a'}}
Assert (@(Compare-FirewallSnapshot $a $b).Count -eq 0) 'Reordering must not be a firewall change.'
$b.Records.one='new'; $b.Records.Remove('two'); $b.Records.three='added'
$changes=@(Compare-FirewallSnapshot $a $b)
Assert ($changes.Count -eq 3 -and @($changes.Change | Sort-Object -Unique).Count -eq 3) 'Add/remove/modify must be detected.'
Write-Output 'PASS: firewall diff fixtures.'

. (Get-FunctionDefinitions 'ActiveDirectory/Manage Active Directory Groups.ps1')
$script:ChangeCmdlet=New-Object psobject
$script:AllowChange=$false
$script:ChangeCmdlet | Add-Member ScriptMethod ShouldProcess {param($Target,$Action) return $script:AllowChange}
$credParams=@{}
$script:ProtectionWrites=New-Object 'System.Collections.Generic.List[bool]'
function Get-ADGroup { [pscustomobject]@{ObjectGUID=[guid]'11111111-1111-1111-1111-111111111111';ProtectedFromAccidentalDeletion=$true;DistinguishedName='CN=Fixture,DC=example,DC=test'} }
function Get-ADOrganizationalUnit { [pscustomobject]@{ObjectGUID=[guid]'22222222-2222-2222-2222-222222222222';DistinguishedName='OU=Target,DC=example,DC=test'} }
function Set-ADObject { param($Identity,[bool]$ProtectedFromAccidentalDeletion) $script:ProtectionWrites.Add($ProtectedFromAccidentalDeletion) }
function Move-ADObject { throw 'Injected move failure' }
Move-ADGroupToOU -GroupDN 'fixture' -TargetOU 'target'
Assert ($script:ProtectionWrites.Count -eq 0) 'Denied/WhatIf move must not disable protection.'
$script:AllowChange=$true
$failed=$false
try { Move-ADGroupToOU -GroupDN 'fixture' -TargetOU 'target' } catch { $failed=$true }
Assert ($failed -and $script:ProtectionWrites.Count -eq 2 -and -not $script:ProtectionWrites[0] -and $script:ProtectionWrites[1]) 'Failed move must restore original protection.'
Write-Output 'PASS: AD move preview and failure rollback fixtures.'

$temp=Join-Path ([IO.Path]::GetTempPath()) ('script-safety-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $temp
try {
    $allowed=Join-Path $temp 'allowed'; $null=New-Item -ItemType Directory -Path $allowed
    $candidate=Join-Path $allowed 'old.tmp'; [IO.File]::WriteAllText($candidate,'temporary fixture')
    [IO.File]::SetLastWriteTimeUtc($candidate,[datetime]::UtcNow.AddDays(-60))
    $backup=Join-Path $allowed 'important.bak'; [IO.File]::WriteAllText($backup,'retain')
    [IO.File]::SetLastWriteTimeUtc($backup,[datetime]::UtcNow.AddDays(-60))
    $cleanup=Join-Path $root 'scripts/cleanup/DiskCleanup.ps1'
    $inventory=@(& $cleanup -AllowedPath $allowed)
    Assert ($inventory.Count -eq 1 -and (Test-Path -LiteralPath $candidate) -and (Test-Path -LiteralPath $backup)) 'Default cleanup must inventory only and exclude backups.'
    $manifest=Join-Path $temp 'manifest.csv'; $inventory | Export-Csv -LiteralPath $manifest -NoTypeInformation
    $digest=(Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash
    & $cleanup -AllowedPath $allowed -Execute -ManifestPath $manifest -ManifestSha256 $digest -WhatIf
    Assert (Test-Path -LiteralPath $candidate) '-WhatIf must preserve candidate.'
    [IO.File]::AppendAllText($candidate,'changed')
    $failed=$false
    try { & $cleanup -AllowedPath $allowed -Execute -ManifestPath $manifest -ManifestSha256 $digest -Confirm:$false } catch { $failed=$true }
    Assert ($failed -and (Test-Path -LiteralPath $candidate)) 'Stale manifest must fail before deletion.'
    Write-Output 'PASS: cleanup inventory, protected fixture, WhatIf and stale-manifest checks.'
} finally {
    # Only this test-created directory is removed, never a repository or host data path.
    Remove-Item -LiteralPath $temp -Recurse -Force
}
Write-Output 'All isolated checks passed. No AD/CA/Graph/Exchange/firewall/production operation was executed.'
