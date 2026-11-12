# Read-only role-change audit evidence; original concept AdminDroid / o365reports.com.
# ExchangeOnlineManagement V3 with Search-UnifiedAuditLog and View-Only Audit Logs RBAC.
# This is raw role-change evidence, not proof of complete PIM activity or current role state.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][guid]$TenantId,
 [Parameter(Mandatory=$true)][datetimeoffset]$StartDate,
 [Parameter(Mandatory=$true)][datetimeoffset]$EndDate,
 [Parameter(Mandatory=$true)][string]$OutputPath,
 [switch]$PIMActivationsOnly,[switch]$PIMDeactivationsOnly)
$ErrorActionPreference='Stop'
function Get-RoleAuditEvidence {
 param([datetime]$StartUtc,[datetime]$EndUtc,[string[]]$Operations)
 $rows=New-Object 'System.Collections.Generic.List[object]';$seen=@{}
 for($day=$StartUtc;$day -lt $EndUtc;$day=$stop){
  $stop=$day.AddDays(1);if($stop -gt $EndUtc){$stop=$EndUtc}
  $session=[guid]::NewGuid().ToString('N');$retrieved=0;$sessionSeen=@{}
  while($true){
   $batch=@(Search-UnifiedAuditLog -StartDate $day -EndDate $stop -Operations $Operations -SessionId $session -SessionCommand ReturnLargeSet -ResultSize 5000 -ErrorAction Stop)
   if(-not $batch.Count){break}
   $retrieved+=$batch.Count
   if($retrieved -ge 50000 -or @($batch | Where-Object {[long]$_.ResultCount -ge 50000}).Count){throw 'Audit session may be truncated at 50000 records. Narrow the time window; no report published.'}
   $added=0
   foreach($entry in $batch){
    $data=$entry.AuditData | ConvertFrom-Json -ErrorAction Stop
    if(-not $data.Id -or -not $data.CreationTime){throw 'Audit record has no stable identity or timestamp.'}
    $time=[datetimeoffset]::Parse($data.CreationTime,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).UtcDateTime
    $key=[string]$data.Id
    if(-not $sessionSeen.ContainsKey($key)){$sessionSeen[$key]=$true;$added++}
    if(-not $seen.ContainsKey($key)){
     $seen[$key]=$true
     if($time -ge $StartUtc -and $time -lt $EndUtc){$rows.Add([pscustomobject]@{Id=$key;CreationTimeUtc=$time.ToString('o');Operation=$data.Operation;UserId=$data.UserId;AuditData=$entry.AuditData;PIMAttribution='NotAssessed'})}
    }
   }
   if(-not $added){throw 'Audit pagination made no progress; no report published.'}
  }
 }
 $rows.ToArray()
}
if($StartDate -ge $EndDate -or ($EndDate-$StartDate).TotalDays -gt 31 -or $EndDate -gt [datetimeoffset]::UtcNow){throw 'Require an explicit increasing UTC interval of at most 31 days ending no later than now.'}
if($PIMActivationsOnly -and $PIMDeactivationsOnly){throw 'Activation/deactivation filters are mutually exclusive.'}
. (Join-Path $PSScriptRoot '../scripts/common/ReportSafety.ps1')
Assert-ExchangeTenant $TenantId
$ops=@('Add member to role','Remove member from role')
if($PIMActivationsOnly){$ops=@('Add member to role')};if($PIMDeactivationsOnly){$ops=@('Remove member from role')}
$rows=@(Get-RoleAuditEvidence $StartDate.UtcDateTime $EndDate.UtcDateTime $ops)
Export-NewReport $rows $OutputPath
[pscustomobject]@{Path=$OutputPath;Rows=$rows.Count;Collection='Queries completed; tenant retention, ingestion and PIM attribution require validation'}
