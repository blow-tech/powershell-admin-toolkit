#Requires -Version 5.1
<#
.SYNOPSIS
Read-only bounded lockout evidence from explicitly selected DCs.
.DESCRIPTION
Resolves the target SID independently of bad-password counters. Matches Event 4740
by named XML fields and exact SID. Unavailable logs are UNKNOWN.
Caller fields are evidence, not proof of the originating application.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Identity,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$DomainController,
    [ValidateRange(1,30)][int]$DaysBack=1,
    [ValidateRange(1,100000)][int]$MaxEvents=10000
)
function ConvertFrom-LockoutEvent {
    param($Event,[string]$TargetSid)
    if ([string]::IsNullOrWhiteSpace($TargetSid)) { throw 'Resolved target SID is required.' }
    $xml=[xml]$Event.ToXml()
    $data=@{}
    foreach ($field in $xml.Event.EventData.Data) { $data[[string]$field.Name]=[string]$field.InnerText }
    if ([string]::IsNullOrWhiteSpace($data.TargetSid)) { throw 'Event 4740 has no TargetSid.' }
    if ($data.TargetSid -ne $TargetSid) { return }
    # Windows 4740 version 0 uses TargetDomainName for the caller in its XML.
    $caller=$data.CallerComputerName
    if ([string]::IsNullOrWhiteSpace($caller)) { $caller=$data.TargetDomainName }
    [pscustomobject]@{
        User=$data.TargetUserName; TargetSid=$data.TargetSid
        DomainController=$Event.MachineName; EventId=$Event.Id
        LockedOutTime=$Event.TimeCreated; RecordId=$Event.RecordId
        LockedOutLocation=$caller
        CallerState=if ([string]::IsNullOrWhiteSpace($caller)) {'UNKNOWN'} else {'Recorded'}
    }
}
function Get-LockedOutLocation {
    [CmdletBinding()]
    param([string]$Identity,[string[]]$DomainController,[int]$DaysBack=1,[int]$MaxEvents=10000)
    $ErrorActionPreference='Stop'
    $controllers=@($DomainController | Sort-Object -Unique)
    if (-not $controllers.Count -or @($controllers | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count) { throw 'Explicit DC scope required.' }
    $user=Get-ADUser -Identity $Identity -Server $controllers[0] -ErrorAction Stop
    $sid=[string]$user.SID
    if ($sid -notmatch '^S-1-(\d+-)+\d+$') { throw 'Cannot resolve a valid target SID.' }
    $results=New-Object 'System.Collections.Generic.List[object]'
    foreach ($dc in $controllers) {
        try {
            $events=@()
            try {
                $events=@(Get-WinEvent -ComputerName $dc -FilterHashtable @{
                    LogName='Security';Id=4740;StartTime=(Get-Date).AddDays(-$DaysBack)
                } -MaxEvents $MaxEvents -ErrorAction Stop)
            } catch {
                if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { throw }
            }
            $matches=@(foreach ($event in $events) { ConvertFrom-LockoutEvent $event $sid })
            $results.Add([pscustomobject]@{
                DomainController=$dc; Status=if ($events.Count -ge $MaxEvents) {'TRUNCATED'} else {'Collected'}
                EventsChecked=$events.Count; Matches=$matches; Error=$null
            })
        } catch {
            $results.Add([pscustomobject]@{DomainController=$dc;Status='UNKNOWN';EventsChecked=$null;Matches=@();Error=$_.Exception.Message})
        }
    }
    $results
}
if ($MyInvocation.InvocationName -ne '.') {
    Import-Module ActiveDirectory -ErrorAction Stop
    $report=@(Get-LockedOutLocation @PSBoundParameters)
    $report
    if (@($report | Where-Object Status -ne 'Collected').Count) { throw 'Lockout evidence is incomplete; inspect UNKNOWN/TRUNCATED results.' }
}
