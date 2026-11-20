#requires -Version 5.1
<# Read-only Graph v1.0 inventory. PowerShell 5.1 / Graph Authentication module.
Examples:
 .\Export-GraphInventory.ps1 -Report UsersLicenses -PreviewOnly
 .\Export-GraphInventory.ps1 -Report All -OutputFolder C:\Report
#>
[CmdletBinding()]
param(
 [ValidateSet('UsersLicenses','LicenseSummary','Groups','GroupMembers','GroupOwners','Guests','All')][string]$Report='All',
 [string]$OutputFolder='C:\Report',
 [switch]$PreviewOnly
)
$ErrorActionPreference='Stop'
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
if (-not (Get-MgContext)) { throw 'Connect first: Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","GroupMember.Read.All","Organization.Read.All"' }
function Get-Pages([string]$Url) {
 $count=0
 do {
  $data=Invoke-MgGraphRequest -Method GET -Uri $Url -ErrorAction Stop
  if ($null -eq $data -or $null -eq $data.value) { throw "Unexpected Graph response: $Url" }
  foreach ($item in $data.value) { $item; $count++; if ($PreviewOnly -and $count -ge 5) { return } }
  $Url=$data['@odata.nextLink']
 } while ($Url)
}
function Save-Result([string]$Name,[object[]]$Items) {
 if ($PreviewOnly) { Write-Host "PREVIEW: $Name ($($Items.Count) rows, no files created)" -ForegroundColor Yellow; $Items | Select-Object -First 5 | Format-Table -AutoSize; return }
 if (-not (Test-Path -LiteralPath $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null }
 $file=Join-Path $OutputFolder ($Name+'.csv'); $Items | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8
 Write-Host "Exported $($Items.Count): $file" -ForegroundColor Green
}
$want=@($Report); if ($Report -eq 'All') { $want=@('UsersLicenses','LicenseSummary','Groups','GroupMembers','GroupOwners','Guests') }
$users=@(); $skus=@(); $groups=@()
if ($want -contains 'UsersLicenses' -or $want -contains 'Guests' -or $want -contains 'LicenseSummary') {
 $users=@(Get-Pages 'https://graph.microsoft.com/v1.0/users?$top=500&$select=id,displayName,userPrincipalName,userType,accountEnabled,department,assignedLicenses')
}
if ($want -contains 'LicenseSummary' -or $want -contains 'UsersLicenses') {
 $skus=@(Get-Pages 'https://graph.microsoft.com/v1.0/subscribedSkus')
}
$skuNames=@{}; foreach ($sku in $skus) { $skuNames[[string]$sku.skuId]=[string]$sku.skuPartNumber }
if ($want -contains 'UsersLicenses') {
 $rows=@(foreach($u in $users) {
  $ids=@($u.assignedLicenses | ForEach-Object { [string]$_.skuId })
  $labels=@($ids | ForEach-Object { if ($skuNames.ContainsKey($_)) { $skuNames[$_] } else { $_ } })
  [pscustomobject]@{DisplayName=$u.displayName;UserPrincipalName=$u.userPrincipalName;UserType=$u.userType;AccountEnabled=$u.accountEnabled;Department=$u.department;LicenseCount=$ids.Count;Licenses=($labels -join '; ');UserId=$u.id}
 })
 Save-Result 'Users_Licenses' $rows
}
if ($want -contains 'LicenseSummary') {
 $rows=@(foreach($s in $skus){[pscustomobject]@{SkuPartNumber=$s.skuPartNumber;SkuId=$s.skuId;EnabledUnits=$s.prepaidUnits.enabled;ConsumedUnits=$s.consumedUnits;AvailableUnits=([int]$s.prepaidUnits.enabled-[int]$s.consumedUnits)}})
 Save-Result 'License_Summary' $rows
}
if ($want -contains 'Guests') {
 $rows=@(foreach($u in $users | Where-Object {$_.userType -eq 'Guest'}) {[pscustomobject]@{DisplayName=$u.displayName;UserPrincipalName=$u.userPrincipalName;AccountEnabled=$u.accountEnabled;UserId=$u.id}})
 Save-Result 'Guest_Users' $rows
}
if ($want -contains 'Groups' -or $want -contains 'GroupMembers' -or $want -contains 'GroupOwners') {
 $groups=@(Get-Pages 'https://graph.microsoft.com/v1.0/groups?$top=500&$select=id,displayName,description,mail,mailEnabled,securityEnabled,groupTypes,membershipRule,membershipRuleProcessingState')
}
if ($want -contains 'Groups') {
 $rows=@(foreach($g in $groups){[pscustomobject]@{GroupName=$g.displayName;GroupId=$g.id;Mail=$g.mail;MailEnabled=$g.mailEnabled;SecurityEnabled=$g.securityEnabled;GroupTypes=(@($g.groupTypes) -join '; ');IsDynamic=(-not [string]::IsNullOrWhiteSpace([string]$g.membershipRule));MembershipRule=$g.membershipRule;Description=$g.description}})
 Save-Result 'Groups' $rows
}
if ($want -contains 'GroupMembers') {
 $rows=@(foreach($g in $groups){
  Write-Host "Members: $($g.displayName)" 
  $members=@(Get-Pages ('https://graph.microsoft.com/v1.0/groups/{0}/members?$top=500' -f $g.id))
  foreach($m in $members){[pscustomobject]@{GroupName=$g.displayName;GroupId=$g.id;MemberName=$m.displayName;MemberUPN=$m.userPrincipalName;MemberMail=$m.mail;MemberId=$m.id;MemberType=$m['@odata.type'];Membership='Direct'}}
 })
 Save-Result 'Group_Members_Direct' $rows
}
if ($want -contains 'GroupOwners') {
 $rows=@(foreach($g in $groups){
  Write-Host "Owners: $($g.displayName)"
  $owners=@(Get-Pages ('https://graph.microsoft.com/v1.0/groups/{0}/owners?$top=500' -f $g.id))
  if ($owners.Count -eq 0) {[pscustomobject]@{GroupName=$g.displayName;GroupId=$g.id;OwnerName='';OwnerUPN='';OwnerId='';OwnerStatus='No owner returned'}}
  foreach($o in $owners){[pscustomobject]@{GroupName=$g.displayName;GroupId=$g.id;OwnerName=$o.displayName;OwnerUPN=$o.userPrincipalName;OwnerId=$o.id;OwnerStatus='Owner'}}
 })
 Save-Result 'Group_Owners' $rows
}
