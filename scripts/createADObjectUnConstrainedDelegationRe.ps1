<#PSScriptInfo

.VERSION 0.1

.GUID 5e7bfd24-88b8-4e4d-99fd-c4ffbfcf5be6

.AUTHOR Chad.Cox@microsoft.com
    https://blogs.technet.microsoft.com/chadcox/
    https://github.com/chadmcox

.COMPANYNAME 

.COPYRIGHT This Sample Code is provided for the purpose of illustration only and is not
intended to be used in a production environment.  THIS SAMPLE CODE AND ANY
RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a
nonexclusive, royalty-free right to use and modify the Sample Code and to
reproduce and distribute the object code form of the Sample Code, provided
that You agree: (i) to not use Our name, logo, or trademarks to market Your
software product in which the Sample Code is embedded; (ii) to include a valid
copyright notice on Your software product in which the Sample Code is embedded;
and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and
against any claims or lawsuits, including attorneys` fees, that arise or result
from the use or distribution of the Sample Code..

.RELEASENOTES

.DESCRIPTION 
 this is to help descover Objects with this exploit
 https://support.microsoft.com/en-us/help/4490425/updates-to-tgt-delegation-across-incoming-trusts-in-windows-server

#>
# Read-only, scoped configuration evidence. Does not certify exploitability/effective access.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server,[Parameter(Mandatory)][string]$SearchBase,[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
. (Join-Path $PSScriptRoot 'common/ReportSafety.ps1')
$filter='(&(servicePrincipalName=*)(|(msDS-AllowedToActOnBehalfOfOtherIdentity=*)(msDS-AllowedToDelegateTo=*)(userAccountControl:1.2.840.113556.1.4.804:=17301504)))'
$rows=@(Get-ADObject -Server $Server -SearchBase $SearchBase -LDAPFilter $filter -Properties userAccountControl,sAMAccountName,msDS-AllowedToDelegateTo,msDS-AllowedToActOnBehalfOfOtherIdentity -ErrorAction Stop | ForEach-Object {
 [pscustomobject]@{ObjectGUID=$_.ObjectGUID;DistinguishedName=$_.DistinguishedName;SamAccountName=$_.sAMAccountName;IsDC=(($_.userAccountControl -band 8192) -ne 0);Unconstrained=(($_.userAccountControl -band 524288) -ne 0);ProtocolTransition=(($_.userAccountControl -band 16777216) -ne 0);AllowedToDelegateTo=($_.'msDS-AllowedToDelegateTo' -join ';');ResourceDelegationConfigured=($null -ne $_.'msDS-AllowedToActOnBehalfOfOtherIdentity')}
})
# Trust objects are a separate domain-wide configuration scope; explicitly identified rows, not a risk verdict.
$rows+=@(Get-ADTrust -Server $Server -Filter * -ErrorAction Stop | Select-Object @{n='RecordType';e={'TrustConfiguration'}},Name,Direction,TGTDelegation)
# Normalize mixed record schemas so trust fields cannot be dropped by Export-Csv's first-row schema.
$rows=@($rows | Select-Object RecordType,ObjectGUID,DistinguishedName,SamAccountName,IsDC,Unconstrained,ProtocolTransition,AllowedToDelegateTo,ResourceDelegationConfigured,Name,Direction,TGTDelegation)
Export-NewReport -Rows $rows -Path $OutputPath
