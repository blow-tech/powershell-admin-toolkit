<# Read-only failure evidence using preinstalled Microsoft.Graph.Reports 2.x and an existing
expected-tenant Graph context. Interactive user evidence uses v1.0 by default. UseBeta is lab-only (Microsoft.Graph.Beta.Reports 2.x); no auto-install/login/logout.
Requires AuditLog.Read.All and an appropriate sign-in-log reader role/licensing. Policy details may be hidden
without Policy.Read.ConditionalAccess; absence is not proof that no policy applied. Risk fields can be hidden.
UTC [StartUtc, EndUtc) range, at most 31 days. Tenant retention can be shorter. No mail or GUI.
Docs: https://learn.microsoft.com/graph/api/signin-list?view=graph-rest-beta
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][guid]$TenantId,
 [Parameter(Mandatory)][datetimeoffset]$StartUtc,
 [Parameter(Mandatory)][datetimeoffset]$EndUtc,
 [Parameter(Mandatory)][string]$OutputPath,
 [ValidateSet('interactiveUser','nonInteractiveUser','servicePrincipal','managedIdentity','All')][string]$SignInEventType='interactiveUser',
 [ValidateRange(1,2147483647)][Nullable[int]]$ErrorCode,
 [string[]]$UserPrincipalName,
 [switch]$UseBeta,[switch]$RiskySignInsOnly,[switch]$GuestUserSignInsOnly,[switch]$MFASignInsOnly,[switch]$NonMFASignInsOnly,
 [ValidateRange(1,100000)][int]$MaxRecords=10000
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'scripts/common/ReportSafety.ps1')
if($EndUtc -le $StartUtc -or ($EndUtc-$StartUtc).TotalDays -gt 31 -or $EndUtc -gt [datetimeoffset]::UtcNow){throw 'Supply a positive, historical UTC interval of at most 31 days.'}
if($MFASignInsOnly -and $NonMFASignInsOnly){throw 'MFA and non-MFA filters are mutually exclusive.'}
$context=Get-MgContext -ErrorAction Stop
if(-not $context -or [string]$context.TenantId -ne $TenantId.ToString()){throw 'Expected-tenant Graph context is required.'}
$start=$StartUtc.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ');$end=$EndUtc.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
$filter="createdDateTime ge $start and createdDateTime lt $end and status/errorCode ne 0"
if($null -ne $ErrorCode){$filter+=" and status/errorCode eq $ErrorCode"}
if(-not $UseBeta -and $SignInEventType -ne 'interactiveUser'){throw 'Non-interactive/workload categories require the unsupported-in-production beta contract; use a separately approved lab with UseBeta or authoritative exported logs.'}
$types=if($SignInEventType -eq 'All'){@('interactiveUser','nonInteractiveUser','servicePrincipal','managedIdentity')}else{@($SignInEventType)}
if($UseBeta){$filter+=' and signInEventTypes/any(t: '+(($types | ForEach-Object {"t eq '$_'"}) -join ' or ')+')';Write-Warning 'Microsoft Graph beta is not supported for production applications. Lab use only.'}
$queryCommand=if($UseBeta){'Get-MgBetaAuditLogSignIn'}else{'Get-MgAuditLogSignIn'}
$rows=New-Object 'System.Collections.Generic.List[object]';$count=0;$seen=@{}
& $queryCommand -All -PageSize 100 -Filter $filter -ErrorAction Stop | ForEach-Object {
 $count++;if($count -gt $MaxRecords){throw 'Record budget exceeded; narrow the interval. No report published.'}
 if(-not $_.Id -or $seen.ContainsKey([string]$_.Id)){throw 'Missing/repeated event identity; collection cannot be certified.'};$seen[[string]$_.Id]=$true
 if($null -eq $_.Status.ErrorCode -or $_.Status.ErrorCode -eq 0){throw 'Unexpected or missing failure status.'}
 $include=$true
 if($UserPrincipalName -and $_.UserPrincipalName -notin $UserPrincipalName){$include=$false}
 if($GuestUserSignInsOnly -and $_.UserType -ne 'guest'){$include=$false}
 if($MFASignInsOnly -and $_.AuthenticationRequirement -ne 'multiFactorAuthentication'){$include=$false}
 if($NonMFASignInsOnly -and $_.AuthenticationRequirement -ne 'singleFactorAuthentication'){$include=$false}
 if($RiskySignInsOnly){
  if(-not $_.RiskState -or $_.RiskState -eq 'hidden'){throw 'Risk evidence unavailable for requested risky-only filter.'}
  if($_.RiskState -notin @('atRisk','confirmedCompromised','remediated','dismissed')){$include=$false}
 }
 if($include){$rows.Add([pscustomobject]@{Id=$_.Id;CreatedDateTime=$_.CreatedDateTime;UserPrincipalName=$_.UserPrincipalName;AppDisplayName=$_.AppDisplayName;ErrorCode=$_.Status.ErrorCode;FailureReason=$_.Status.FailureReason;AuthenticationRequirement=$_.AuthenticationRequirement;ConditionalAccessStatus=$_.ConditionalAccessStatus;RiskState=$_.RiskState;RawEvidence=($_ | ConvertTo-Json -Depth 30 -Compress);Completeness='Service-returned evidence; retention/RBAC not certified'})}
}
Export-NewReport -Rows $rows.ToArray() -Path $OutputPath
[pscustomobject]@{OutputPath=$OutputPath;Rows=$rows.Count;ObservedRecords=$count;TenantId=$TenantId;StartUtc=$StartUtc;EndUtc=$EndUtc}
