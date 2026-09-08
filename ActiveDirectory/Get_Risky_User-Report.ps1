<#
=============================================================================================
Name:           Risky Users Report in Microsoft Entra
Version:        1.0
Website:        o365reports.com

Script Highlights:  
~~~~~~~~~~~~~~~~~
1. Exports all risky users in your organization to a CSV file.
2. Lists all users who have a history of risky activity.
3. Finds users based on specific risk levels and risk states.
4. Supports exporting risky users over a specified time.
5. Uses an existing Graph session in the explicitly expected tenant. History retrieval is optional.
6. The script can be executed with an MFA-enabled account too.
7. Supports Certificate-based Authentication too.
8. The script is scheduler friendly.


For detailed Script execution: https://o365reports.com/2025/05/20/how-to-get-all-risky-users-in-microsoft-entra/
============================================================================================
#>

Param
(
    [nullable[int]]$ShowRiskyUsersFromLastNDays,
    [ValidateSet("Low", "Medium", "High", "None")]
    [string[]]$RiskLevel,
    [ValidateSet("ConfirmedSafe", "Remediated", "Dismissed", "AtRisk", "ConfirmedCompromised", "None")]
    [string[]]$RiskState,
    [switch]$CreateSession,
    [Parameter(Mandatory)][string]$TenantId,
    [switch]$IncludeHistory,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

$ErrorActionPreference='Stop'
$context=Get-MgContext
if ($null -eq $context -or $context.TenantId -ne $TenantId) { throw 'Connect Graph to the expected TenantId first.' }
$OutputRecords=New-Object 'System.Collections.Generic.List[object]'
$Location = Get-Location
$CurrentDate = Get-Date
$ExportCSV = "$Location\M365_Risky_Users_Report$($CurrentDate.ToString('yyyyMMddTHHmmss'))_$([guid]::NewGuid().ToString('N')).csv"
$Filter = @()
$ExportResult =""   
$ExportResults = @() 

if ($ShowRiskyUsersFromLastNDays -ne $null) {
    $Filter += "(RiskLastUpdatedDateTime ge $($CurrentDate.AddDays(-$ShowRiskyUsersFromLastNDays).ToString('yyyy-MM-dd')))"
} else {
    $Filter += "(RiskLastUpdatedDateTime ge $($CurrentDate.AddDays(-90).ToString('yyyy-MM-dd')))"
}

$Count=0
$PrintedLogs=0
$Filter = $Filter -join " and "
Write-Host "Generating M365 risky users' report..."
Get-MgRiskyUser -All -Filter "$($Filter)" | ForEach-Object {
 $Count++
 Write-Progress -Activity "`n     Identified $count risky users"
 $Id = $_.Id
 $RiskLastUpdatedDateTime = ($_.RiskLastUpdatedDateTime).ToLocalTime()
 $UserRiskLevel = $_.RiskLevel
 $UserRiskState = $_.RiskState
 $UserRiskDetail = $_.RiskDetail
 $UserDisplayName = $_.UserDisplayName
 $UPN = $_.UserPrincipalName
 $IsDeleted = $_.IsDeleted
 $IsProcessing = $_.IsProcessing
 $UserRiskEventType = 'Not collected'
 $Print = 1

 # Apply filters based on the param values...
 if (!([string]::IsNullOrEmpty($RiskLevel)) -and ($UserRiskLevel -notin $RiskLevel)) { $Print = 0 }
 if (!([string]::IsNullOrEmpty($RiskState)) -and ($UserRiskState -notin $RiskState)) { $Print = 0 }

 #Export users to output file
 if($Print -eq 1)
 {
  if ($IncludeHistory) {
    $history=@(Get-MgRiskyUserHistory -RiskyUserId $Id -All -ErrorAction Stop)
    $UserRiskEventType=(@($history.Activity.RiskEventTypes | Sort-Object -Unique) -join ', ')
  }
  $PrintedLogs++
  $ExportResult=[PSCustomObject]@{'Risk Last Updated Date Time'=$RiskLastUpdatedDateTime; 'Risky User UPN'=$UPN; 'Risky User Name'=$UserDisplayName; 'Risk Level'=$UserRiskLevel; 'Remediation Action'=$UserRiskDetail; 'Risk State'=$UserRiskState; 'Risk Event Type'=$UserRiskEventType; 'Risky User Id'=$Id; 'Is User Deleted'=$IsDeleted; 'Is Backend Processing'=$IsProcessing;}
  $OutputRecords.Add($ExportResult)
 }
}

if ($OutputRecords.Count -gt 0) {
 $temporary=$ExportCSV + '.partial'
 $OutputRecords | Export-Csv -LiteralPath $temporary -NoTypeInformation
 [IO.File]::Move($temporary,$ExportCSV)
 Write-Output "Exported $($OutputRecords.Count) risky users: $ExportCSV"
} else { Write-Output 'Enumeration succeeded; no matching risky users.' }
