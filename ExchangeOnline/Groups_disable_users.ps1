# Read-only group/user evidence. Original concept AdminDroid / o365reports.com.
# Requires Microsoft.Graph.Groups/Users and existing expected-tenant context;
# delegated GroupMember.Read.All + User.Read.All, plus Member.Read.Hidden for hidden membership.
# Only direct user members/owners are assessed, never nested groups or effective access.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][guid]$TenantId,[Parameter(Mandatory=$true)][string]$OutputPath,
 [ValidateSet('All','Microsoft365','Security','MailEnabledSecurity','DistributionList')][string]$GroupType='All')
$ErrorActionPreference='Stop'
$context=Get-MgContext
if(-not $context -or $context.TenantId -ne $TenantId.ToString()){throw 'Connect Graph to the explicitly expected tenant first.'}
. (Join-Path $PSScriptRoot '../scripts/common/ReportSafety.ps1')
$groups=@(Get-MgGroup -All -Property Id,DisplayName,Mail,MailEnabled,SecurityEnabled,GroupTypes -ErrorAction Stop)
$rows=@(foreach($g in $groups){
 $type=if($g.GroupTypes -contains 'Unified'){'Microsoft365'}elseif($g.MailEnabled -and $g.SecurityEnabled){'MailEnabledSecurity'}elseif($g.MailEnabled){'DistributionList'}else{'Security'}
 if($GroupType -ne 'All' -and $GroupType -ne $type){continue}
 $members=@(Get-MgGroupMemberAsUser -GroupId $g.Id -All -Property Id,AccountEnabled,UserPrincipalName -ErrorAction Stop)
 $owners=@(Get-MgGroupOwnerAsUser -GroupId $g.Id -All -Property Id,AccountEnabled,UserPrincipalName -ErrorAction Stop)
 $unknown=@(@($members)+@($owners) | Where-Object {$null -eq $_.AccountEnabled})
 [pscustomobject]@{GroupId=$g.Id;DisplayName=$g.DisplayName;GroupType=$type;DirectUserMembers=$members.Count;DirectUserOwners=$owners.Count;DisabledMemberIds=(@($members | Where-Object {$_.AccountEnabled -eq $false}).Id -join ';');DisabledOwnerIds=(@($owners | Where-Object {$_.AccountEnabled -eq $false}).Id -join ';');UnknownAccountStates=$unknown.Count;CollectionState=$(if($unknown.Count){'UNKNOWN'}else{'Collected'});Scope='Direct users; hidden/nested/unsupported groups may be incomplete'}
})
Export-NewReport $rows $OutputPath
if(@($rows | Where-Object CollectionState -eq UNKNOWN).Count){throw "Unknown account states in $OutputPath; permissions or limited Graph properties need review."}
[pscustomobject]@{Path=$OutputPath;Rows=$rows.Count;Completeness='NotCertified'}
