<# Read-only direct GPO/container ACL evidence for reviewed SIDs. Requires AD/GroupPolicy modules,
explicit domain/DC/search base and read access. Does not evaluate effective rights, nested groups or inheritance reach.
Unresolvable ACE identities are UNKNOWN rows; incomplete evidence causes failure after marked output. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$DomainName,[Parameter(Mandatory)][string]$Server,[Parameter(Mandatory)][string]$SearchBase,[Parameter(Mandatory)][ValidatePattern('^S-1-[0-9]+(-[0-9]+)+$')][string[]]$PrincipalSid,[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop
. (Join-Path $PSScriptRoot 'common/ReportSafety.ps1')
if((Get-ADDomain -Server $Server -ErrorAction Stop).DNSRoot -ne $DomainName){throw 'Server/domain mismatch.'}
$rows=New-Object 'System.Collections.Generic.List[object]';$unknown=$false
foreach($gpo in @(Get-GPO -All -Domain $DomainName -Server $Server -ErrorAction Stop)){
 foreach($ace in @(Get-GPPermission -Guid $gpo.Id -All -DomainName $DomainName -Server $Server -ErrorAction Stop)){
  $sid=[string]$ace.Trustee.Sid;$state='Collected'
  if(-not $sid){$state='UNKNOWN';$unknown=$true}
  if(-not $sid -or $sid -in $PrincipalSid){$rows.Add([pscustomobject]@{Kind='GPO';ObjectId=$gpo.Id;Name=$gpo.DisplayName;PrincipalSid=$sid;Rights=[string]$ace.Permission;AccessType='GPO permission';Inherited=$ace.Inherited;CollectionState=$state})}
 }
}
foreach($container in @(Get-ADObject -Server $Server -SearchBase $SearchBase -LDAPFilter '(|(objectClass=organizationalUnit)(objectClass=domainDNS)(objectClass=builtinDomain)(objectClass=container))' -Properties nTSecurityDescriptor -ErrorAction Stop)){
 if($null -eq $container.nTSecurityDescriptor){throw "UNKNOWN: no security descriptor for $($container.DistinguishedName)"}
 foreach($ace in $container.nTSecurityDescriptor.Access){
  $sid='';$state='Collected'
  try{$sid=$ace.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value}catch{$state='UNKNOWN';$unknown=$true}
  if(-not $sid -or $sid -in $PrincipalSid){$rows.Add([pscustomobject]@{Kind='Container';ObjectId=$container.ObjectGUID;Name=$container.DistinguishedName;PrincipalSid=$sid;Rights=[string]$ace.ActiveDirectoryRights;AccessType=[string]$ace.AccessControlType;Inherited=$ace.IsInherited;CollectionState=$state})}
 }
}
Export-NewReport -Rows $rows.ToArray() -Path $OutputPath
if($unknown){throw 'Report contains unresolved ACL identities; effective access is not certified.'}
