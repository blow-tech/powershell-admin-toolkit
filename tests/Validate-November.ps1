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
$global:FixtureGroupWrites=0;$global:FixtureNewWrites=0
function Add-ADGroupMember { $global:FixtureGroupWrites++ }
function New-ADUser { $global:FixtureNewWrites++;throw 'Denied create fixture' }
$create=Join-Path $root 'ActiveDirectory/Create Multiple AD user.ps1'
# Existing fixture identity must abort before creating or modifying groups.
$failed=$false
try { & $create -ExcelPath fixture -Server fixture -OU fixture -UpnSuffix example.test -Execute -PasswordProvider {ConvertTo-SecureString 'MockOnly!1234' -AsPlainText -Force} -Confirm:$false } catch {$failed=$true}
Assert ($failed -and $global:FixtureGroupWrites -eq 0 -and $global:FixtureNewWrites -eq 0) 'Collision must not mutate.'
function Get-ADUser { @() }
& $create -ExcelPath fixture -Server fixture -OU fixture -UpnSuffix example.test | Out-Null
Assert ($global:FixtureNewWrites -eq 0) 'Default must preview.'
$failed=$false
try { & $create -ExcelPath fixture -Server fixture -OU fixture -UpnSuffix example.test -Execute -PasswordProvider {ConvertTo-SecureString 'MockOnly!1234' -AsPlainText -Force} -Confirm:$false } catch {$failed=$true}
Assert ($failed -and $global:FixtureNewWrites -eq 1 -and $global:FixtureGroupWrites -eq 0) 'Denied creation must not assign groups.'
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
. (Functions 'ExchangeOnline/Audit PIM role.ps1')
$global:FixtureAuditPage=0
function Search-UnifiedAuditLog {
 param($StartDate,$EndDate,$SessionId,$SessionCommand,$Operations,$ResultSize)
 $global:FixtureAuditPage++
 if($global:FixtureAuditPage -le 2){
  [pscustomobject]@{AuditData=(@{Id=('audit-'+$global:FixtureAuditPage);CreationTime='2026-01-01T12:00:00Z';Operation='Add member to role';UserId='fixture'} | ConvertTo-Json);ResultCount=2}
 }
}
$start=([datetimeoffset]'2026-01-01T00:00:00Z').UtcDateTime;$end=$start.AddDays(1)
$r=@(Get-RoleAuditEvidence $start $end @('Add member to role'))
Assert ($r.Count -eq 2 -and $global:FixtureAuditPage -eq 3) 'Audit must continue after a short page until empty.'
function Search-UnifiedAuditLog {[pscustomobject]@{ResultCount=50000;AuditData='{}'}}
$failed=$false;try{Get-RoleAuditEvidence $start $end @('Add member to role')}catch{$failed=$true};Assert $failed 'Truncated audit must fail.'
function Search-UnifiedAuditLog {[pscustomobject]@{ResultCount=1;AuditData='{"Id":"repeat","CreationTime":"2026-01-01T12:00:00Z"}'}}
$failed=$false;try{Get-RoleAuditEvidence $start $end @('Add member to role')}catch{$failed=$true};Assert $failed 'Repeated audit page must fail.'
. (Functions 'ExchangeOnline/Trace Emails Sent to External Domains')
function Start-Sleep {}
$global:FixtureTracePage=0
function Get-MessageTraceV2 {
 $global:FixtureTracePage++
 if($global:FixtureTracePage -le 2){[pscustomobject]@{MessageTraceId=('trace-'+$global:FixtureTracePage);RecipientAddress='recipient@example.test';Received=$start.AddHours(15-$global:FixtureTracePage)}}
}
$r=@(Get-TraceEvidence $start $end @{} 100)
Assert ($r.Count -eq 2 -and $global:FixtureTracePage -eq 3) 'Trace must continue after short page.'
function Get-MessageTraceV2 {[pscustomobject]@{MessageTraceId='repeat';RecipientAddress='recipient@example.test';Received=$start.AddHours(12)}}
$failed=$false;try{Get-TraceEvidence $start $end @{} 100}catch{$failed=$true};Assert $failed 'Repeated trace cursor must fail.'
Write-Output 'PASS short audit/trace pages, audit cap and repeated pagination.'
. (Functions 'scripts/inventory/Audit.ps1')
function Get-CimInstance {
 param($ComputerName,$ClassName,$OperationTimeoutSec)
 Assert ($ComputerName -eq 'fixture' -and $OperationTimeoutSec -eq 30) 'Inventory target/budget must remain explicit.'
 if($ClassName -eq 'Win32_BIOS'){throw 'Denied fixture'}
 if($ClassName -eq 'Win32_QuickFixEngineering'){return}
 [pscustomobject]@{Name='fixture';Caption='<script>fixture</script>'}
}
$r=@(Get-InventoryEvidence @('fixture') 30)
Assert ($r.Count -eq 8 -and @($r | Where-Object CollectionState -eq UNKNOWN).Count -eq 1) 'Inventory must expose failed section.'
Assert (($r | Where-Object Section -eq Win32_QuickFixEngineering).CollectionState -eq 'Empty') 'Successful empty optional section must remain distinct.'
. (Functions 'scripts/inventory/Break Glass Account Report.ps1')
$r=Get-ScoreSummary @([pscustomobject]@{Result='Pass';Weight=2},[pscustomobject]@{Result='Error';Weight=2},[pscustomobject]@{Result='Manual';Weight=4})
Assert ($r.Percent -eq 25 -and $r.Completeness -eq 'Incomplete' -and $r.Readiness -eq 'NotCertified') 'Missing/manual evidence cannot inflate readiness score.'
Write-Output 'PASS scoped CIM unknown/empty evidence and conservative break-glass score.'
. (Functions 'ExchangeOnline/GetAllSharingLinks.ps1')
$Connection='fixture';$Site='https://fixture.sharepoint.com';$SnapshotUtc=([datetimeoffset]'2026-01-01T12:00:00Z').UtcDateTime
$ActiveLinks=[switch]$false;$ExpiredLinks=[switch]$true;$LinksWithExpiration=[switch]$false;$NeverExpiresLinks=[switch]$false;$SoonToExpireInDays=0
$GetAnyoneLinks=[switch]$false;$GetCompanyLinks=[switch]$false;$GetSpecificPeopleLinks=[switch]$false
$ResultsBuffer=New-Object 'System.Collections.Generic.List[object]'
function Get-PnPList {[pscustomobject]@{Title='Fixture';Hidden=$false;BaseType='DocumentLibrary'}}
function Get-PnPListItem {[pscustomobject]@{FieldValues=@{FileLeafRef='fixture';FileRef='/fixture';File_x0020_Type='txt'};FileSystemObjectType='File'}}
function Get-PnPFileSharingLink {[pscustomobject]@{Link=@{Scope='Anonymous';Type='View';WebUrl='https://example.test/fixture'};Roles=@('read');ExpirationDateTime='2026-01-01T11:59:00Z'}}
Get-SharedLinks
Assert ($ResultsBuffer.Count -eq 1 -and $ResultsBuffer[0].'Link Status' -eq 'Expired') 'Earlier today must be expired against one UTC instant.'
function Get-PnPFileSharingLink {throw 'Denied fixture'}
$failed=$false;try{Get-SharedLinks}catch{$failed=$true};Assert $failed 'Sharing query failure must propagate.'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('mailbox-fixture-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $temp
try {
 function Get-Mailbox {[pscustomobject]@{Guid=[guid]'55555555-5555-5555-5555-555555555555';ExternalDirectoryObjectId='mailbox-id';PrimarySmtpAddress='box@example.test';GrantSendOnBehalfTo=@()}}
 $global:FixtureRecipientCalls=0
 function Get-Recipient {$global:FixtureRecipientCalls++;[pscustomobject]@{ExternalDirectoryObjectId='principal-id'}}
 function Get-MailboxPermission {[pscustomobject]@{User='literal[1]';AccessRights=@('ReadPermission');Deny=$false;IsInherited=$false}}
 function Get-RecipientPermission {[pscustomobject]@{Trustee='literal[1]';AccessRights=@('SendAs');AccessControlType='Deny';IsInherited=$true}}
 $path=Join-Path $temp 'assignments.csv'
 & (Join-Path $root 'ExchangeOnline/MailboxesUserCanAccess.ps1') -TenantId '33333333-3333-3333-3333-333333333333' -OutputPath $path | Out-Null
 $r=@(Import-Csv $path)
 Assert ($r.Count -eq 2 -and $r[0].Right -eq 'ReadPermission' -and $r[1].Deny -eq 'True' -and $global:FixtureRecipientCalls -eq 1) 'Keep actual rights/deny and cache literal principal.'
 function Get-MailboxPermission {throw 'Denied fixture'}
 $path=Join-Path $temp 'denied.csv';$failed=$false
 try{& (Join-Path $root 'ExchangeOnline/MailboxesUserCanAccess.ps1') -TenantId '33333333-3333-3333-3333-333333333333' -OutputPath $path}catch{$failed=$true}
 Assert ($failed -and -not (Test-Path $path)) 'Denied permissions must not publish completed report.'
} finally {Remove-Item -LiteralPath $temp -Recurse -Force}
Write-Output 'PASS same-day sharing expiry, denied collections and literal permission identity/rights/deny/cache.'
. (Functions 'ActiveDirectory/Manage Active Directory Groups.ps1')
$credParams=@{Server='example.test'};$DomainName='example.test';$Credential=$null
$script:ChangeCmdlet=[pscustomobject]@{}
$script:ChangeCmdlet | Add-Member ScriptMethod ShouldProcess {param($target,$action) return $true}
$global:FixtureGroupWrites=0;$global:FixtureDisposed=0;$global:FixtureFailedLog=0
function Log-ScriptExecution {param($Status) if(-not $Status){$global:FixtureFailedLog++}}
function Get-ADGroup {[pscustomobject]@{ManagedBy='CN=old,DC=example,DC=test';ObjectGUID=[guid]'22222222-2222-2222-2222-222222222222'}}
function Set-ADObject {$global:FixtureGroupWrites++}
function Set-ADGroup {$global:FixtureGroupWrites++}
Update-GroupManager -GroupDN fixture -manager 'CN=new,DC=example,DC=test' -action set -enableManagerAccess N
Assert ($global:FixtureGroupWrites -eq 0 -and $global:FixtureFailedLog -eq 1) 'Manager replacement must refuse leaving the old ACL grant.'
$global:FixtureEntry=[pscustomobject]@{ObjectSecurity=$null}
$global:FixtureEntry | Add-Member ScriptMethod Dispose {$global:FixtureDisposed++}
function New-Object {param([Parameter(Position=0)]$TypeName,[Parameter(Position=1)]$ArgumentList) if($TypeName -like '*DirectoryEntry*'){return $global:FixtureEntry};throw 'Unexpected constructor in fixture.'}
function Get-ADObject {throw 'Denied manager SID fixture'}
$failed=$false;try{Update-ManagerAccess -GroupDN fixture -toEnable enable}catch{$failed=$true}
Assert ($failed -and $global:FixtureDisposed -eq 1) 'Delegation failure must propagate and dispose DirectoryEntry.'
Remove-Item Function:New-Object
function Update-ManagerAccess {return $false}
Update-GroupManager -GroupDN fixture -action removed
Assert ($global:FixtureGroupWrites -eq 0) 'Declined delegation removal must retain manager attribute.'
$failed=$false
try { & (Join-Path $root 'ActiveDirectory/Manage Active Directory Groups.ps1') -DomainName example.test -MultiExecutionMode -InputCsvFilePath nonexistent.csv } catch {$failed=$true}
Assert $failed 'Multi-action bulk mode must fail before reading or using a stale CSV.'
Write-Output 'PASS group manager stale-grant refusal, delegation error/disposal, declined removal and bulk-menu refusal.'
$stagedGroup=Join-Path $root ('ExchangeOnline/.fixture-'+[guid]::NewGuid().ToString('N')+'.ps1')
Copy-Item -LiteralPath (Join-Path $root 'ExchangeOnline/Get-DistributionGroupMember') -Destination $stagedGroup
$temp=Join-Path ([IO.Path]::GetTempPath()) ('remaining-report-fixture-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $temp
try {
 function Get-ADUser {
  [pscustomobject]@{Name='recent';PasswordLastSet=[datetime]::UtcNow.AddDays(-1);whenCreated=[datetime]::UtcNow.AddYears(-5)}
  [pscustomobject]@{Name='old';PasswordLastSet=[datetime]::UtcNow.AddYears(-1);whenCreated=[datetime]::UtcNow}
 }
 $r=@(& (Join-Path $root 'ActiveDirectory/GetADuserpasswd.ps1') -Server fixture -SearchBase fixture)
 Assert ($r.Count -eq 1 -and $r[0].Name -eq 'recent') 'Password report must filter PasswordLastSet, not account creation.'
 function Get-DistributionGroup {[pscustomobject]@{Guid=[guid]'22222222-2222-2222-2222-222222222222';PrimarySmtpAddress='group@example.test'}}
 function Get-DistributionGroupMember {throw 'Denied group fixture'}
 $path=Join-Path $temp 'members.csv';$failed=$false
 try{& $stagedGroup -TenantId '33333333-3333-3333-3333-333333333333' -OutputPath $path}catch{$failed=$true}
 Assert ($failed -and -not (Test-Path $path)) 'Denied group membership cannot publish a complete report.'
 function Get-DistributionGroupMember {return}
 & $stagedGroup -TenantId '33333333-3333-3333-3333-333333333333' -OutputPath $path | Out-Null
 $r=@(Import-Csv $path);Assert ($r.Count -eq 1 -and $r[0].CollectionState -eq 'Empty') 'Successfully empty group must remain visible.'
 function Get-CimInstance {[pscustomobject]@{DeviceID='C:';Size=0;FreeSpace=0}}
 $path=Join-Path $temp 'disk.csv';$failed=$false
 try{& (Join-Path $root 'scripts/cleanup/disk_space_report.ps1') -ComputerName fixture -OutputPath $path}catch{$failed=$true}
 Assert ($failed -and -not (Test-Path $path)) 'Zero disk capacity must fail without publication.'
 function Get-CimInstance {[pscustomobject]@{DeviceID='C:';Size=1000;FreeSpace=250}}
 & (Join-Path $root 'scripts/cleanup/disk_space_report.ps1') -ComputerName fixture -OutputPath $path
 Assert ((Import-Csv $path).FreePercent -eq '25') 'Disk report must retain numeric capacity ratio.'
 function Get-MgContext {[pscustomobject]@{TenantId='33333333-3333-3333-3333-333333333333'}}
 function Get-MgBetaAuditLogSignIn {
  param($Filter,[switch]$All,$PageSize)
  Assert ($Filter -match 'createdDateTime ge 2026-01-01T00:00:00Z' -and $Filter -match 'createdDateTime lt 2026-01-02T00:00:00Z' -and $Filter -match 'signInEventTypes/any' -and $All -and $PageSize -eq 100) 'Sign-in query must retain UTC bounds/type and paging.'
  [pscustomobject]@{Id='event-1';Status=@{ErrorCode=50001};RiskState='hidden'}
  [pscustomobject]@{Id='event-2';Status=@{ErrorCode=50001};RiskState='atRisk'}
 }
 $signins=Join-Path $root 'M365 Sign-in Failure Report .ps1';$path=Join-Path $temp 'signin.csv'
 & $signins -UseBeta -TenantId '33333333-3333-3333-3333-333333333333' -StartUtc '2026-01-01T00:00:00Z' -EndUtc '2026-01-02T00:00:00Z' -OutputPath $path | Out-Null
 Assert (@(Import-Csv $path).Count -eq 2) 'Raw sign-in report must retain hidden risk evidence.'
 foreach($scenario in @('cap','hidden')){
  $path=Join-Path $temp ($scenario+'.csv');$failed=$false
  $extra=if($scenario -eq 'cap'){@{MaxRecords=1}}else{@{RiskySignInsOnly=$true}}
  try{& $signins -UseBeta -TenantId '33333333-3333-3333-3333-333333333333' -StartUtc '2026-01-01T00:00:00Z' -EndUtc '2026-01-02T00:00:00Z' -OutputPath $path @extra}catch{$failed=$true}
  Assert ($failed -and -not (Test-Path $path)) 'Capped/hidden filtered sign-in evidence must not publish a completed report.'
 }
 function Get-MgAuditLogSignIn {
  param($Filter)
  Assert ($Filter -notmatch 'signInEventTypes') 'Default must use the stable interactive-user contract.'
  [pscustomobject]@{Id='stable-event';Status=@{ErrorCode=50001};RiskState='none'}
 }
 $path=Join-Path $temp 'stable.csv'
 & $signins -TenantId '33333333-3333-3333-3333-333333333333' -StartUtc '2026-01-01T00:00:00Z' -EndUtc '2026-01-02T00:00:00Z' -OutputPath $path | Out-Null
 Assert ((Import-Csv $path).Id -eq 'stable-event') 'Stable default sign-in query must publish its evidence.'
 function Get-GPO {[pscustomobject]@{Id=[guid]'22222222-2222-2222-2222-222222222222';DisplayName='Duplicate-friendly-name'}}
 function Get-GPPermission {
  param($Guid,$DomainName,$Server)
  Assert ($Guid -eq [guid]'22222222-2222-2222-2222-222222222222' -and $Server -eq 'fixture' -and $DomainName -eq 'example.test') 'GPO permission query must use GUID and explicit scope.'
  [pscustomobject]@{Trustee=@{Sid='S-1-5-21-1-2-3-1001'};Permission='GpoRead';Inherited=$false}
 }
 function Get-ADObject {return}
 $path=Join-Path $temp 'acl.csv'
 & (Join-Path $root 'scripts/Find-Principal_PermAD.ps1') -DomainName example.test -Server fixture -SearchBase fixture -PrincipalSid 'S-1-5-21-1-2-3-1001' -OutputPath $path
 Assert (@(Import-Csv $path).Count -eq 1) 'Exact SID GPO evidence must be retained.'
} finally {Remove-Item -LiteralPath $temp -Recurse -Force;Remove-Item -LiteralPath $stagedGroup -Force}
Write-Output 'PASS password-date filtering, denied/empty group membership, disk capacity, bounded sign-in evidence and exact SID/GPO scope.'
