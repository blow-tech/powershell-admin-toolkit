#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Identifies the source computer that caused an AD account lockout.

.DESCRIPTION
    Queries all Domain Controllers for bad password attempt data on the target account,
    then queries the PDC Emulator's Security event log for Event ID 4740 (account lockout)
    to determine exactly which machine triggered the lockout.

    Displays per-DC bad password stats and the lockout origin machine.

.PARAMETER Identity
    The SamAccountName of the locked-out user.

.EXAMPLE
    .\GetADAccountLockedOutLocation.ps1 -Identity "jdoe"

.EXAMPLE
    Import-Module .\GetADAccountLockedOutLocation.ps1
    Get-LockedOutLocation -Identity "sqlclustsvc"

.NOTES
    Requires: PDC Emulator running Windows Server 2008 SP2 or later.
              AD Web Services must be available on at least one DC.
    Author:   blow-tech | based on original by Jason Walker
    Version:  1.2
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$Identity
)

Import-Module ActiveDirectory -ErrorAction Stop

function Get-LockedOutLocation {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )

    $dcCounter    = 0
    $lockedStats  = [System.Collections.Generic.List[PSObject]]::new()

    # ── Get all DCs ────────────────────────────────────────────────────────────
    try {
        $domainControllers = Get-ADDomainController -Filter * -ErrorAction Stop
        $pdcEmulator       = $domainControllers | Where-Object { $_.OperationMasterRoles -contains "PDCEmulator" }
        Write-Host "[*] Found $($domainControllers.Count) Domain Controller(s). PDC: $($pdcEmulator.HostName)" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "[!] Could not enumerate Domain Controllers: $_"
        return
    }

    # ── Query each DC for bad password info ───────────────────────────────────
    foreach ($dc in $domainControllers) {
        $dcCounter++
        Write-Progress -Activity "Querying DCs for lockout info" `
                       -Status "Contacting $($dc.HostName)" `
                       -PercentComplete (($dcCounter / $domainControllers.Count) * 100)

        try {
            $userInfo = Get-ADUser -Identity $Identity `
                                   -Server $dc.HostName `
                                   -Properties AccountLockoutTime, LastBadPasswordAttempt, BadPwdCount, LockedOut `
                                   -ErrorAction Stop

            if ($userInfo.LastBadPasswordAttempt) {
                $lockedStats.Add([PSCustomObject]@{
                    Name                   = $userInfo.SamAccountName
                    SID                    = $userInfo.SID.Value
                    LockedOut              = $userInfo.LockedOut
                    BadPwdCount            = $userInfo.BadPwdCount
                    DomainController       = $dc.HostName
                    AccountLockoutTime     = $userInfo.AccountLockoutTime
                    LastBadPasswordAttempt = $userInfo.LastBadPasswordAttempt.ToLocalTime()
                })
            }
        }
        catch {
            Write-Warning "[!] Could not query $($dc.HostName): $_"
        }
    }

    Write-Progress -Activity "Querying DCs for lockout info" -Completed

    # ── Display per-DC stats ───────────────────────────────────────────────────
    if ($lockedStats.Count -gt 0) {
        Write-Host "`n--- Bad Password Stats per DC ---" -ForegroundColor Yellow
        $lockedStats | Format-Table Name, LockedOut, DomainController, BadPwdCount, AccountLockoutTime, LastBadPasswordAttempt -AutoSize
    }
    else {
        Write-Host "[i] No bad password attempts found for '$Identity' on any DC." -ForegroundColor Gray
    }

    # ── Query PDC Emulator event log for lockout origin ───────────────────────
    Write-Host "[*] Querying PDC Emulator event log ($($pdcEmulator.HostName)) for Event ID 4740..." -ForegroundColor Cyan

    try {
        $lockedOutEvents = Get-WinEvent -ComputerName $pdcEmulator.HostName `
                                        -FilterHashtable @{ LogName = 'Security'; Id = 4740 } `
                                        -ErrorAction Stop |
                           Sort-Object -Property TimeCreated -Descending
    }
    catch {
        Write-Warning "[!] Could not retrieve events from PDC: $_"
        return
    }

    # ── Match events to target user SID ───────────────────────────────────────
    $targetSID = ($lockedStats | Select-Object -First 1).SID
    $matchFound = $false

    foreach ($event in $lockedOutEvents) {
        if ($event.Properties[2].Value -match $targetSID) {
            $matchFound = $true
            [PSCustomObject]@{
                User              = $event.Properties[0].Value
                DomainController  = $event.MachineName
                EventId           = $event.Id
                LockedOutTime     = $event.TimeCreated
                LockedOutLocation = $event.Properties[1].Value
                Message           = ($event.Message -split "`r" | Select-Object -First 1)
            } | Format-List
        }
    }

    if (-not $matchFound) {
        Write-Host "[i] No lockout event (4740) found for '$Identity' on the PDC Emulator." -ForegroundColor Gray
        Write-Host "    The account may not be currently locked, or events may have been cleared." -ForegroundColor Gray
    }
}

# ── Run if called directly (not dot-sourced) ──────────────────────────────────
if ($MyInvocation.InvocationName -ne '.') {
    Get-LockedOutLocation -Identity $Identity
}
