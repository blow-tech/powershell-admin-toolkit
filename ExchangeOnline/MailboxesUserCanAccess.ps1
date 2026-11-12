<#
Direct mailbox permission assignments, NOT an effective-access certification.
Preserves original community script purpose; nested group membership, RBAC,
delegation policies and deny precedence require separate authorization analysis.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][guid]$TenantId,[Parameter(Mandatory=$true)][string]$OutputPath,[string[]]$UPN=@())
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/common/ReportSafety.ps1')
Assert-ExchangeTenant $TenantId
$cache=@{}; $wanted=@{}
function Resolve-PermissionPrincipal {
    param([string]$Identity)
    if (-not $Identity) { throw 'Empty permission principal.' }
    if (-not $cache.ContainsKey($Identity)) {
        try {
            $r=@(Get-Recipient -Identity $Identity -ErrorAction Stop)
            if ($r.Count -ne 1 -or -not $r[0].ExternalDirectoryObjectId) { throw 'Ambiguous principal' }
            $cache[$Identity]=[pscustomobject]@{Id=[string]$r[0].ExternalDirectoryObjectId;State='Resolved'}
        } catch { $cache[$Identity]=[pscustomobject]@{Id='';State='UNKNOWN'} }
    }
    $cache[$Identity]
}
foreach ($u in $UPN) {
    $p=Resolve-PermissionPrincipal $u
    if ($p.State -ne 'Resolved') { throw "Requested principal cannot be resolved: $u" }
    $wanted[$p.Id]=$true
}
$rows=New-Object 'System.Collections.Generic.List[object]'
function Add-Assignment {
    param($Mailbox,[string]$Principal,[string]$Right,$Deny,$Inherited)
    $p=Resolve-PermissionPrincipal $Principal
    # Unresolved evidence is always retained, even in a filtered report.
    if ($wanted.Count -and $p.State -eq 'Resolved' -and -not $wanted.ContainsKey($p.Id)) { return }
    $rows.Add([pscustomobject]@{MailboxId=$Mailbox.ExternalDirectoryObjectId;Mailbox=$Mailbox.PrimarySmtpAddress;Principal=$Principal;PrincipalId=$p.Id;Right=$Right;Deny=$Deny;Inherited=$Inherited;Resolution=$p.State;Coverage='Direct assignments only'})
}
$mailboxes=@(Get-Mailbox -ResultSize Unlimited -ErrorAction Stop)
foreach ($m in $mailboxes) {
    if (-not $m.Guid -or -not $m.ExternalDirectoryObjectId) { throw 'Mailbox missing immutable identity.' }
    foreach ($ace in @(Get-MailboxPermission -Identity $m.Guid -ErrorAction Stop)) {
        foreach ($right in $ace.AccessRights) { Add-Assignment $m ([string]$ace.User) ([string]$right) $ace.Deny $ace.IsInherited }
    }
    foreach ($ace in @(Get-RecipientPermission -Identity $m.Guid -ErrorAction Stop)) {
        foreach ($right in $ace.AccessRights) { Add-Assignment $m ([string]$ace.Trustee) ([string]$right) ($ace.AccessControlType -eq 'Deny') $ace.IsInherited }
    }
    foreach ($principal in $m.GrantSendOnBehalfTo) { Add-Assignment $m ([string]$principal) 'SendOnBehalf' $false $false }
}
Export-NewReport @($rows.ToArray()) $OutputPath
$unknown=@($rows | Where-Object Resolution -eq 'UNKNOWN').Count
[pscustomobject]@{Status=$(if($unknown){'UNKNOWN principals'}else{'Collected direct assignments'});MailboxCount=$mailboxes.Count;Unresolved=$unknown;OutputPath=$OutputPath}
if ($unknown) { throw 'Report contains unresolved principals; do not interpret it as effective-access clearance.' }
