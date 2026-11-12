# Trace-evidence report; original concept: AdminDroid Community / o365reports.com.
# Requires an existing ExchangeOnlineManagement V3 session and read-only recipient access.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][guid]$TenantId,
 [Parameter(Mandatory=$true)][string]$HistoricalMessageTraceReportPath,
 [Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/common/ReportSafety.ps1')
Assert-ExchangeTenant $TenantId
Function FindDifference{
    param(
        $DateTime
    )

    $DayDifference = (New-TimeSpan -Start $DateTime -End (Get-Date)).Days
    $DayDifference = "$DayDifference" + " Days"
    return $DayDifference
}

Function GettingInactiveDistributionLists
{
    # Preserve input evidence byte-for-byte. Parse dates before comparing them.
    Import-Csv -LiteralPath $HistoricalMessageTraceReportPath -ErrorAction Stop | ForEach-Object {
        if (-not $_.PSObject.Properties['recipient_status'] -or -not $_.PSObject.Properties['origin_timestamp_utc']) {
            throw 'Trace CSV requires recipient_status and origin_timestamp_utc headers.'
        }
        $RecipientAddresses = $_.'recipient_status' -Split ';'
        ForEach($RecipientAddress in $RecipientAddresses){
            $Recipient = $RecipientAddress -Split "##" | select -Index(0)
            $DL = $global:DistributionLists.$Recipient
            if($DL)
            {
                $LastEmail = [datetimeoffset]::Parse($_.'origin_timestamp_utc',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).UtcDateTime
                $LastEmailReceived = $LastEmail
                $Difference = FindDifference -DateTime $LastEmail
                if($global:InactiveDistributionLists.$DL)
                {
                    $Last = $global:InactiveDistributionLists.$DL[0]
                    if($Last -lt $LastEmailReceived)
                    {
                        $global:InactiveDistributionLists.$DL[0] = $LastEmailReceived
                        $global:InactiveDistributionLists.$DL[1] = $Difference
                    }
                }
                else
                {
                    $global:InactiveDistributionLists[$DL] = @($LastEmailReceived,$Difference)
                }
            }
        }
    }
}


$groups=@(Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop | Where-Object RecipientTypeDetails -eq 'MailUniversalDistributionGroup')
$global:DistributionLists=@{}; $global:InactiveDistributionLists=@{}
foreach($g in $groups) {
 foreach($address in @($g.EmailAddresses)) {
  if([string]$address -notmatch '(?i)^smtp:'){continue}
  $alias=([string]$address).Substring(5);$primary=[string]$g.PrimarySmtpAddress
  if($global:DistributionLists.ContainsKey($alias) -and $global:DistributionLists[$alias] -ne $primary){throw 'Ambiguous SMTP alias.'}
  $global:DistributionLists[$alias]=$primary
 }
}
GettingInactiveDistributionLists
$rows=@(foreach($g in $groups) {
 $key=[string]$g.PrimarySmtpAddress;$entry=$global:InactiveDistributionLists[$key]
 [pscustomobject]@{Group=$key;LastObservedUtc=$(if($entry){$entry[0].ToString('o')}else{$null});EvidenceState=$(if($entry){'ObservedInSuppliedTrace'}else{'UNKNOWN'});InactivityProven=$false}
})
Export-NewReport $rows $OutputPath
[pscustomobject]@{Path=$OutputPath;Rows=$rows.Count;Scope='Supplied trace only; gaps and retention not assessed'}
