#requires -Version 5.1
<# Read-only Exchange Online reporting. Requires working Connect-ExchangeOnline session.
 .\Export-ExchangeInventory.ps1 -Report All -OutputFolder C:\Report
 .\Export-ExchangeInventory.ps1 -Report FullAccess -PreviewOnly
#>
[CmdletBinding()]
param(
 [ValidateSet('Mailboxes','FullAccess','SendAs','SendOnBehalf','Forwarding','All')][string]$Report='All',
 [string]$OutputFolder='C:\Report',
 [switch]$PreviewOnly
)
$ErrorActionPreference='Stop'
if (-not (Get-Command Get-EXOMailbox -ErrorAction SilentlyContinue)) { throw 'Connect first using Connect-ExchangeOnline in a supported ExchangeOnlineManagement session.' }
function Save-Result([string]$Name,[object[]]$Rows) {
 if ($PreviewOnly) { Write-Host "PREVIEW: $Name ($($Rows.Count) rows)" -ForegroundColor Yellow; $Rows | Select-Object -First 5 | Format-Table -AutoSize; return }
 if (-not (Test-Path -LiteralPath $OutputFolder)) { New-Item $OutputFolder -ItemType Directory -Force | Out-Null }
 $path=Join-Path $OutputFolder ($Name+'.csv'); $Rows | Export-Csv $path -NoTypeInformation -Encoding UTF8
 Write-Host "Exported $($Rows.Count): $path" -ForegroundColor Green
}
$all=@(Get-EXOMailbox -ResultSize Unlimited -Properties GrantSendOnBehalfTo,ForwardingAddress,ForwardingSmtpAddress,DeliverToMailboxAndForward -ErrorAction Stop)
if ($PreviewOnly) { $all=@($all | Select-Object -First 5) }
$want=@($Report);if($Report -eq 'All'){$want=@('Mailboxes','FullAccess','SendAs','SendOnBehalf','Forwarding')}
if($want -contains 'Mailboxes') {
 Save-Result 'Exchange_Mailboxes' @(foreach($m in $all){[pscustomobject]@{DisplayName=$m.DisplayName;PrimarySmtpAddress=[string]$m.PrimarySmtpAddress;RecipientTypeDetails=$m.RecipientTypeDetails;ExternalDirectoryObjectId=$m.ExternalDirectoryObjectId}})
}
if($want -contains 'FullAccess') {
 $rows=@(foreach($m in $all){
  Write-Host "FullAccess: $($m.PrimarySmtpAddress)"
  foreach($p in @(Get-EXOMailboxPermission -Identity $m.PrimarySmtpAddress -ErrorAction Stop | Where-Object { -not $_.IsInherited -and -not $_.Deny -and $_.User -notmatch 'NT AUTHORITY\\SELF' -and $_.AccessRights -contains 'FullAccess' })) {
   [pscustomobject]@{Mailbox=[string]$m.PrimarySmtpAddress;Trustee=[string]$p.User;Rights=($p.AccessRights -join '; ')}
  }
 })
 Save-Result 'Exchange_FullAccess' $rows
}
if($want -contains 'SendAs') {
 $rows=@(foreach($m in $all){
  Write-Host "SendAs: $($m.PrimarySmtpAddress)"
  foreach($p in @(Get-EXORecipientPermission -Identity $m.PrimarySmtpAddress -ErrorAction Stop | Where-Object { -not $_.IsInherited -and -not $_.Deny -and $_.AccessRights -contains 'SendAs' -and $_.Trustee -notmatch 'NT AUTHORITY\\SELF' })) {
   [pscustomobject]@{Mailbox=[string]$m.PrimarySmtpAddress;Trustee=[string]$p.Trustee;Rights=($p.AccessRights -join '; ')}
  }
 })
 Save-Result 'Exchange_SendAs' $rows
}
if($want -contains 'SendOnBehalf') {
 $rows=@(foreach($m in $all){foreach($delegate in @($m.GrantSendOnBehalfTo)){[pscustomobject]@{Mailbox=[string]$m.PrimarySmtpAddress;Delegate=[string]$delegate}}})
 Save-Result 'Exchange_SendOnBehalf' $rows
}
if($want -contains 'Forwarding') {
 $rows=@(foreach($m in $all){if($m.ForwardingSmtpAddress -or $m.ForwardingAddress){[pscustomobject]@{Mailbox=[string]$m.PrimarySmtpAddress;ForwardingSmtpAddress=[string]$m.ForwardingSmtpAddress;ForwardingAddress=[string]$m.ForwardingAddress;DeliverToMailboxAndForward=$m.DeliverToMailboxAndForward}}})
 Save-Result 'Exchange_Forwarding' $rows
}
