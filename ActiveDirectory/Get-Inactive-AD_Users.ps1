# Read-only HR correlation by exact EmployeeID. Input files are never rewritten.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Server,
 [Parameter(Mandatory=$true)][string]$SearchBase,
 [Parameter(Mandatory=$true)][string[]]$EmployeeCsvPath,
 [Parameter(Mandatory=$true)][string]$OutputPath,
 [ValidateRange(1,36500)][int]$Days=180)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
. (Join-Path $PSScriptRoot '../scripts/common/ReportSafety.ps1')
$employees=@{}
foreach($path in $EmployeeCsvPath){
 foreach($row in @(Import-Csv -LiteralPath $path -ErrorAction Stop)){
  if(-not $row.PSObject.Properties['EmployeeID'] -or -not $row.PSObject.Properties['HireStatus']){throw 'HR CSV requires EmployeeID and HireStatus headers.'}
  $id=([string]$row.EmployeeID).Trim()
  if(-not $id -or $employees.ContainsKey($id)){throw 'Missing or duplicate HR EmployeeID; resolve ambiguity before reporting.'}
  $employees[$id]=[string]$row.HireStatus
 }
}
$cutoff=[datetime]::UtcNow.AddDays(-$Days)
$rows=@(Get-ADUser -Server $Server -SearchBase $SearchBase -Filter * -Properties EmployeeID,LastLogonDate,PasswordLastSet -ErrorAction Stop | Where-Object {
 $_.Enabled -and (-not $_.LastLogonDate -or $_.LastLogonDate.ToUniversalTime() -lt $cutoff)
} | ForEach-Object {
 $id=([string]$_.EmployeeID).Trim()
 [pscustomobject]@{ObjectGUID=$_.ObjectGUID;SamAccountName=$_.SamAccountName;EmployeeID=$id;HireStatus=$(if($id -and $employees.ContainsKey($id)){$employees[$id]}else{'UNKNOWN'});LastLogonDate=$_.LastLogonDate;PasswordLastSet=$_.PasswordLastSet;Evidence='Replicated approximate timestamp and supplied HR snapshot only';CleanupEligible=$false}
})
Export-NewReport $rows $OutputPath
[pscustomobject]@{Path=$OutputPath;Rows=$rows.Count;InactivityProven=$false}
