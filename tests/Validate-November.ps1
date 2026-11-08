# All directory/cloud commands below are mocks, never imported live modules.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Assert($ok,$message) { if(-not $ok){throw $message} }
function Functions($path) {
 $t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $path),[ref]$t,[ref]$e)
 if($e.Count){throw ($e|Out-String)}
 [scriptblock]::Create(($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$false).Extent.Text -join "`n"))
}
. (Functions 'ActiveDirectory/CleanupInactiveUsers.ps1')
$script:deny=$false;$script:missing=$false;$script:zero=$false
function Get-ADDomainController { @([pscustomobject]@{HostName='dc-a'},[pscustomobject]@{HostName='dc-b'}) }
function Get-ADUser {
 param($Server)
 if($script:deny -and $Server -eq 'dc-b'){throw 'Denied fixture'}
 if($script:missing -and $Server -eq 'dc-b'){return}
 [pscustomobject]@{ObjectGUID=[guid]'11111111-1111-1111-1111-111111111111';SamAccountName='fixture';SID='S-1-5-21-1-2-3-1001';whenCreated=[datetime]::UtcNow.AddDays(-300);adminCount=0;servicePrincipalName=@();lastLogon=$(if($script:zero){0}else{[datetime]::UtcNow.AddDays(-200).ToFileTimeUtc()});Enabled=$true;DistinguishedName='CN=fixture,OU=fixture,DC=example,DC=test'}
}
$r=@(Get-InactivityPlan 'dc-a' 'fixture' 90 @());Assert ($r[0].Status -eq 'Eligible') 'Complete stale fixture must be eligible.'
$script:missing=$true;$r=@(Get-InactivityPlan 'dc-a' 'fixture' 90 @());Assert ($r[0].Status -eq 'UNKNOWN') 'Missing DC identity must remain unknown.'
$script:missing=$false;$script:zero=$true;$r=@(Get-InactivityPlan 'dc-a' 'fixture' 90 @());Assert ($r[0].Status -eq 'UNKNOWN') 'Zero timestamps are not inactivity evidence.'
$script:zero=$false;$script:deny=$true;$failed=$false
try { Get-InactivityPlan 'dc-a' 'fixture' 90 @() } catch {$failed=$true};Assert $failed 'DC failure must abort.'
$script:deny=$false
$r=@(Get-InactivityPlan 'dc-a' 'fixture' 90 @([guid]'11111111-1111-1111-1111-111111111111'));Assert ($r[0].Status -eq 'Excluded') 'Reviewed exclusion must win.'
Write-Output 'PASS inactivity complete/missing/zero/failed/excluded evidence.'
function Import-Module {}
function Get-ADDomain { [pscustomobject]@{DNSRoot='example.test'} }
function Get-ADForest { [pscustomobject]@{UPNSuffixes=@()} }
function Get-ADOrganizationalUnit { [pscustomobject]@{DistinguishedName='OU=fixture,DC=example,DC=test'} }
function Import-Excel { [pscustomobject]@{FirstName='Test';LastName='User';Groups='fixture'} }
function Get-ADGroup { [pscustomobject]@{ObjectGUID=[guid]'22222222-2222-2222-2222-222222222222'} }
$script:groupWrites=0;$script:newWrites=0
function Add-ADGroupMember { $script:groupWrites++ }
function New-ADUser { $script:newWrites++;throw 'Denied create fixture' }
$create=Join-Path $root 'ActiveDirectory/Create Multiple AD user.ps1'
# Existing fixture identity must abort before creating or modifying groups.
$failed=$false
try { & $create -ExcelPath fixture -Server fixture -OU fixture -UpnSuffix example.test -Execute -PasswordProvider {ConvertTo-SecureString 'MockOnly!1234' -AsPlainText -Force} -Confirm:$false } catch {$failed=$true}
Assert ($failed -and $script:groupWrites -eq 0 -and $script:newWrites -eq 0) 'Collision must not mutate.'
function Get-ADUser { @() }
& $create -ExcelPath fixture -Server fixture -OU fixture -UpnSuffix example.test | Out-Null
Assert ($script:newWrites -eq 0) 'Default must preview.'
$failed=$false
try { & $create -ExcelPath fixture -Server fixture -OU fixture -UpnSuffix example.test -Execute -PasswordProvider {ConvertTo-SecureString 'MockOnly!1234' -AsPlainText -Force} -Confirm:$false } catch {$failed=$true}
Assert ($failed -and $script:newWrites -eq 1 -and $script:groupWrites -eq 0) 'Denied creation must not assign groups.'
Write-Output 'PASS creation collision, preview and failure mutation boundaries.'
. (Join-Path $root 'scripts/common/ReportSafety.ps1')
function Get-ConnectionInformation { [pscustomobject]@{State='Connected';TenantID='33333333-3333-3333-3333-333333333333';ModulePrefix=''} }
Assert-ExchangeTenant ([guid]'33333333-3333-3333-3333-333333333333')
$failed=$false;try {Assert-ExchangeTenant ([guid]'44444444-4444-4444-4444-444444444444')}catch{$failed=$true};Assert $failed 'Wrong tenant must fail.'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('report-fixture-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $temp
try {
 $path=Join-Path $temp 'report.csv';Export-NewReport @([pscustomobject]@{Value='original'}) $path
 $failed=$false;try { Export-NewReport @([pscustomobject]@{Value='replacement'}) $path } catch {$failed=$true}
 Assert ($failed -and (Import-Csv $path).Value -eq 'original') 'Publication must preserve existing report.'
} finally {Remove-Item -LiteralPath $temp -Recurse -Force}
Write-Output 'PASS tenant validation and no-overwrite publication.'
