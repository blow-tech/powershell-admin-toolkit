#Requires -Version 5.1
<# Read-only snapshot reconciliation. For actor attribution, correlate Windows Firewall audit events.
The log directory must already exist and be protected. No firewall rules are modified. #>
[CmdletBinding()]
param(
    [string]$LogFile='C:\FirewallChangeLog.jsonl',
    [ValidateRange(5,3600)][int]$IntervalSeconds=30,
    [ValidateRange(1,10)][int]$MaxFailures=3,
    [switch]$Once
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function ConvertTo-StableFilter {
    param([object[]]$Filters, [string[]]$Properties)
    if (@($Filters).Count -eq 0) { throw 'Associated firewall filter missing.' }
    @($Filters | ForEach-Object {
        $record=[ordered]@{}
        foreach ($property in $Properties) {
            $record[$property]=@($_.$property | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        }
        $record | ConvertTo-Json -Compress -Depth 6
    } | Sort-Object)
}
function Get-FirewallSnapshot {
    $rules=@(Get-NetFirewallRule -PolicyStore ActiveStore -ErrorAction Stop)
    if ($rules.Count -eq 0) { throw 'No active-store rules returned; collection scope is unverified.' }
    $records=@{}
    foreach ($rule in $rules) {
        $id="$($rule.PolicyStoreSource)|$($rule.Name)"
        if ($records.ContainsKey($id)) { throw "Duplicate firewall identity: $id" }
        $record=[ordered]@{
            Identity=$id; DisplayName=[string]$rule.DisplayName; Direction=[string]$rule.Direction
            Action=[string]$rule.Action; Enabled=[string]$rule.Enabled; Profile=[string]$rule.Profile
            Application=@(ConvertTo-StableFilter @($rule | Get-NetFirewallApplicationFilter -ErrorAction Stop) @('Program','Package'))
            Port=@(ConvertTo-StableFilter @($rule | Get-NetFirewallPortFilter -ErrorAction Stop) @('Protocol','LocalPort','RemotePort','IcmpType','DynamicTarget'))
            Address=@(ConvertTo-StableFilter @($rule | Get-NetFirewallAddressFilter -ErrorAction Stop) @('LocalAddress','RemoteAddress'))
            Service=@(ConvertTo-StableFilter @($rule | Get-NetFirewallServiceFilter -ErrorAction Stop) @('Service'))
            Interface=@(ConvertTo-StableFilter @($rule | Get-NetFirewallInterfaceFilter -ErrorAction Stop) @('InterfaceAlias'))
        }
        $records[$id]=$record | ConvertTo-Json -Compress -Depth 10
    }
    $canonical=@($records.Keys | Sort-Object | ForEach-Object { $records[$_] }) -join "`n"
    $sha=[Security.Cryptography.SHA256]::Create()
    try { $hash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical)))).Replace('-','') }
    finally { $sha.Dispose() }
    [pscustomobject]@{ Hash=$hash; Records=$records; Count=$records.Count }
}
function Compare-FirewallSnapshot {
    param($Before,$After)
    foreach ($id in @(@($Before.Records.Keys)+@($After.Records.Keys) | Sort-Object -Unique)) {
        if (-not $Before.Records.ContainsKey($id)) { $kind='Added' }
        elseif (-not $After.Records.ContainsKey($id)) { $kind='Removed' }
        elseif ($Before.Records[$id] -cne $After.Records[$id]) { $kind='Modified' }
        else { continue }
        [pscustomobject]@{ Identity=$id; Change=$kind; Before=$Before.Records[$id]; After=$After.Records[$id] }
    }
}
try { $previous=Get-FirewallSnapshot }
catch { throw "MONITORING FAILED: $($_.Exception.Message)" }
if ($Once) { $previous; return }
$failures=0
while ($true) {
    Start-Sleep -Seconds $IntervalSeconds
    try {
        $current=Get-FirewallSnapshot
        if ($current.Hash -ne $previous.Hash) {
            $event=[pscustomobject]@{ TimeUtc=[datetime]::UtcNow; State='CHANGED'; Changes=@(Compare-FirewallSnapshot $previous $current) }
            $event | ConvertTo-Json -Compress -Depth 12 | Add-Content -LiteralPath $LogFile -ErrorAction Stop
            $event
        }
        $previous=$current
        $failures=0
    } catch {
        $failures++
        Write-Warning "MONITORING FAILED ($failures/$MaxFailures): $($_.Exception.Message)"
        if ($failures -ge $MaxFailures) { throw 'Firewall monitoring stopped after repeated collection/logging failures.' }
    }
}
