<#
=============================================================================================
Name:           Export Entra Device Report using MS Graph PowerShell
Description:    This script exports all Microsoft 365 devices to CSV
Version:        3.0
website:        o365reports.com

~~~~~~~~~~~~~~~~~
Script Highlights:
~~~~~~~~~~~~~~~~~
1. Exports all Azure AD devices in your organization.
2. Requires a preinstalled Graph module and an existing connection to the expected tenant.
3. Enables filtering based on following device registration types:
    -> Entra registered
    -> Entra joined
    -> Entra Hybrid joined
4. Generates a report that retrieves enabled devices alone.
5. Helps export disabled devices alone.
6. Find inactive devices based on inactive days.
7. Includes ownership filtering to show company, personal, unknown devices.
8. List all devices that have BitLocker key.
9. The script can be executed with MFA-enabled accounts too.
10. Facilitates filtering devices by users, owners, and groups.
11. Exports the report results in CSV format.
12. Allows exporting devices that match the selected filters.
    -> Device management status – [ Managed / Unmanaged ]
    -> Device compliance status – [ Compliant / Non-compliant ]
    -> Device rooted state – [ Rooted / Nonrooted ]
13. Compatible with certificate-based authentication (CBA).
14. Filter devices by profile types such as IoT, Printer, Secure VM, Shared device, and Registered device.


For detailed script execution: https://o365reports.com/2023/04/18/get-azure-ad-devices-report-using-powershell/

~~~~~~~~~~~
Change Log:
~~~~~~~~~~~
V1.0 (Apr 25, 2023) – File created.  
V2.0 (Jul 17, 2024) – Updated to use MS Graph beta PowerShell module instead of 'Select-MgProfile beta' to load beta commands.  
V3.0 (Jul 03, 2025) – Upgraded from the 'MS Graph beta module' to Microsoft Graph module and added additional filters such as device join type, profile type, compliance status, and more.

============================================================================================
#>

Param
(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [Int]$InactiveDays,
    [string[]]$Users,
    [string[]]$Owners,
    [string[]]$Groups,
    [ValidateSet("Enabled", "Disabled")]
    [string]$DeviceStatus,
    [ValidateSet("Managed", "Unmanaged")]
    [string]$ManagementStatus,
    [ValidateSet("Compliant", "NonCompliant")]
    [string]$ComplianceStatus,
    [ValidateSet("Rooted", "NonRooted")]
    [string]$RootedStatus,
    [ValidateSet("RegisteredDevice", "SecureVM", "Printer", "Shared", "IoT")]
    [string[]]$ProfileType,
    [ValidateSet("Entra registered", "Entra joined", "Entra hybrid joined")]
    [string[]]$JoinType,
    [ValidateSet("Company", "Personal", "Unknown")]
    [string[]]$DeviceOwnership,
    [switch]$IncludeRelationships,
    [switch]$IncludeBitLockerPresence,
    [switch]$DevicesWithBitLockerKey
)

$ErrorActionPreference='Stop'
# Connections and module installation are explicit operator prerequisites.
$context=Get-MgContext
if ($null -eq $context -or $context.TenantId -ne $TenantId) { throw 'Connect Microsoft Graph to the expected TenantId first.' }
$neededScopes=@('Directory.Read.All','DeviceManagementManagedDevices.Read.All')
if ($IncludeBitLockerPresence -or $DevicesWithBitLockerKey) { $neededScopes += 'BitlockerKey.ReadBasic.All' }
if ($context.AuthType -eq 'Delegated') {
 foreach ($scope in $neededScopes) {
  if ($scope -notin $context.Scopes -and -not ($scope -eq 'BitlockerKey.ReadBasic.All' -and 'BitlockerKey.Read.All' -in $context.Scopes)) { throw "Missing delegated scope: $scope" }
 }
}
# Example connection: Connect-MgGraph -TenantId <TenantId> -Scopes 'Directory.Read.All','DeviceManagementManagedDevices.Read.All'
# Add BitlockerKey.ReadBasic.All only when requesting key-presence metadata (never key material).
$OutputRecords=New-Object 'System.Collections.Generic.List[object]'
$Location = Get-Location
$CurrentDate = Get-Date
$TimeZone = (Get-TimeZone).Id
$OutputCsv = "$Location\EntraDevicesReport_$($CurrentDate.ToString('yyyyMMddTHHmmss'))_$([guid]::NewGuid().ToString('N')).csv"
$Report=""
$PrintedLogs=0

$ManagedById=@{}
Get-MgDeviceManagementManagedDevice -All -Property AzureAdDeviceId,SerialNumber -ErrorAction Stop | ForEach-Object {
 if ($_.AzureAdDeviceId) {
  $key=[string]$_.AzureAdDeviceId
  $ManagedById[$key]=@(@($ManagedById[$key])+@($_.SerialNumber) | Where-Object { $_ } | Sort-Object -Unique)
 }
}

Get-MgDevice -All | ForEach-Object {
    Write-Progress -Activity "Fetching devices: $($_.DisplayName)"
    $LastSigninActivity = "-"
    $TrustType = "" 

    if(($_.ApproximateLastSignInDateTime -ne $null)) {
        $LastSigninActivity = (New-TimeSpan -Start $_.ApproximateLastSignInDateTime).Days
    }

    $DeviceErrors=New-Object 'System.Collections.Generic.List[string]'
    $BitLockerKeyIsPresent = 'Not collected'
    if ($IncludeBitLockerPresence -or $DevicesWithBitLockerKey) {
      try {
        $BitLockerKeys=@(Get-MgInformationProtectionBitlockerRecoveryKey -All -Filter "DeviceId eq '$($_.DeviceId)'" -ErrorAction Stop)
        $BitLockerKeyIsPresent=if ($BitLockerKeys.Count -gt 0) {'Yes'} else {'No'}
      } catch {
        $BitLockerKeyIsPresent='UNKNOWN'
        $DeviceErrors.Add('BitLocker metadata query failed')
        if ($DevicesWithBitLockerKey) { throw 'Cannot reliably apply BitLocker filter after collection failure.' }
      }
    }

    if($DevicesWithBitLockerKey.IsPresent) {
        if($BitLockerKeyIsPresent -eq "No") { return }
    }

    if($InactiveDays -ne "") {
        if(($_.ApproximateLastSignInDateTime -eq $null)) { return }
        if($LastSigninActivity -le $InactiveDays) { return }
    }

    $SerialNumber = ""
    if ($_.IsManaged) {
        $ManagedDeviceId = $_.DeviceId
        $SerialNumber = @($ManagedById[$ManagedDeviceId]) -join ','
    }

    $DeviceOwners=@(); $DeviceUsers=@(); $DeviceMemberOf=@()
    $RelationshipState='Not collected'
    if ($IncludeRelationships -or $Owners -or $Users -or $Groups) {
        $deviceObjectId=$_.Id
        try {
            $DeviceOwners=@(Get-MgDeviceRegisteredOwner -DeviceId $deviceObjectId -All -ErrorAction Stop | Select-Object -ExpandProperty AdditionalProperties)
            $DeviceUsers=@(Get-MgDeviceRegisteredUser -DeviceId $deviceObjectId -All -ErrorAction Stop | Select-Object -ExpandProperty AdditionalProperties)
            $DeviceMemberOf=@(Get-MgDeviceMemberOf -DeviceId $deviceObjectId -All -ErrorAction Stop | Select-Object -ExpandProperty AdditionalProperties)
            $RelationshipState='Collected'
        } catch {
            $RelationshipState='UNKNOWN'
            $DeviceErrors.Add('Device relationships query failed')
            if ($Owners -or $Users -or $Groups) { throw 'Cannot apply relationship filters after query failure.' }
        }
    }
    $DeviceGroups=@($DeviceMemberOf | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' })
    $AdministrativeUnits=@($DeviceMemberOf | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.administrativeUnit' })

    if ($_.TrustType -eq "Workplace") { $TrustType = "Entra registered" }
    elseif ($_.TrustType -eq "AzureAd") { $TrustType = "Entra joined" }
    elseif ($_.TrustType -eq "ServerAd") { $TrustType = "Entra hybrid joined" }
    
    if ($_.ApproximateLastSignInDateTime -ne $null) {
        $LastSigninDateTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($_.ApproximateLastSignInDateTime,$TimeZone) 
        $RegistrationDateTime = if ($_.RegistrationDateTime) { [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($_.RegistrationDateTime,$TimeZone) } else { '-' }
    } 
    else {
        $LastSigninDateTime = "-"
        $RegistrationDateTime = "-"
    }

    if ($_.ComplianceExpirationDateTime -ne $null) {
        $ComplianceExpirationDateTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($_.ComplianceExpirationDateTime,$TimeZone)
    } else { 
        $ComplianceExpirationDateTime = "-" 
    }

    $ExtensionAttributes = $_.ExtensionAttributes
    $AttributeArray = @()
    $ExtensionAttributes.psobject.properties | Where-Object {$_.Value -ne $null -and $_.Name -ne "AdditionalProperties"} | select Name, Value | ForEach-Object { $AttributeArray+=$_.Name+":"+$_.Value }

    $Print = 1

    # Apply filters based on the param values...
    if ($DeviceStatus -eq "Enabled" -and $_.AccountEnabled -ne $true) { $Print = 0 }
    elseif ($DeviceStatus -eq "Disabled" -and $_.AccountEnabled -ne $false) { $Print = 0 }
    
    if ($ManagementStatus -eq "Managed" -and $_.IsManaged -ne $true) { $Print = 0 }
    elseif ($ManagementStatus -eq "Unmanaged" -and $_.IsManaged -ne $false) { $Print = 0 }
    
    if ($ComplianceStatus -eq "Compliant" -and $_.IsCompliant -ne $true) { $Print = 0 }
    elseif ($ComplianceStatus -eq "NonCompliant" -and $_.IsCompliant -ne $false) { $Print = 0 }
    
    if ($RootedStatus -eq "Rooted" -and $_.IsRooted -ne $true) { $Print = 0 }
    elseif ($RootedStatus -eq "NonRooted" -and $_.IsRooted -ne $false) { $Print = 0 }
    
    if (!([string]::IsNullOrEmpty($ProfileType)) -and ($_.ProfileType -notin $ProfileType)) { $Print = 0 }
    if (!([string]::IsNullOrEmpty($JoinType)) -and ($TrustType -notin $JoinType)) { $Print = 0 }
    if (!([string]::IsNullOrEmpty($DeviceOwnership)) -and ($_.DeviceOwnership -notin $DeviceOwnership)) { $Print = 0 }
    if (!([string]::IsNullOrEmpty($Users)) -and ($DeviceUsers.Where({ $Users -contains $_.userPrincipalName }, 'First').Count -eq 0)) { $Print = 0 }
    if (!([string]::IsNullOrEmpty($Owners)) -and ($DeviceOwners.Where({ $Owners -contains $_.userPrincipalName }, 'First').Count -eq 0)) { $Print = 0 }
    if (!([string]::IsNullOrEmpty($Groups)) -and ($DeviceGroups.Where({ $Groups -contains $_.displayName }, 'First').Count -eq 0)) { $Print = 0 }

    $ExportResult = @{'CollectionStatus' = $(if ($DeviceErrors.Count) {'PARTIAL'} else {'Succeeded'})
                    'CollectionErrors' = ($DeviceErrors -join '; ')
                    'Relationships' = $RelationshipState
                    'Name'                 = $_.DisplayName
                    'Enabled'                = "$($_.AccountEnabled)"
                    'Operating System'       = $_.OperatingSystem
                    'OS Version'             = $_.OperatingSystemVersion
                    'Join Type'              = $TrustType
                    'Is Managed'             = "$($_.IsManaged)"
                    'Owners'                 = (@($DeviceOwners.userPrincipalName) -join ',')
                    'Users'                  = (@($DeviceUsers.userPrincipalName)-join ',')
                    'Management Type'        = $_.ManagementType
                    'Enrollment Type'        = $_.EnrollmentType
                    'Profile Type'           = $_.ProfileType
                    'Model'                  = $_.Model
                    'Serial Number'           = $SerialNumber
                    'Device Ownership'       = "$($_.DeviceOwnership)"
                    'Is Compliant'           = "$($_.IsCompliant)"
                    'Is Rooted'              = "$($_.IsRooted)"
                    'Registration Date Time' = $RegistrationDateTime
                    'Last SignIn Date Time'  = $LastSigninDateTime
                    'Compliance Expiration Date Time' = $ComplianceExpirationDateTime
                    'InActive Days'          = $LastSigninActivity
                    'Groups'                 = (@($DeviceGroups.displayName) -join ',')
                    'Administrative Units'   = (@($AdministrativeUnits.displayName) -join ',')
                    'Object Id'              = $_.Id
                    'Device Id'              = $_.DeviceId
                    'BitLocker Key Present'    = $BitLockerKeyIsPresent
                    'Extension Attributes'   = (@($AttributeArray) | Out-String).Trim()
                    }

    $Results = $ExportResult.GetEnumerator() | Where-Object {$_.Value -eq $null -or $_.Value -eq ""} 
    Foreach($Result in $Results) {
        $ExportResult[$Result.Name] = "-"
    }

    $Report = [PSCustomObject]$ExportResult
    if($Print -eq 1) {
       $PrintedLogs++
       $OutputRecords.Add($Report)
    }
}

# Never disconnect a caller-owned session. Publish a complete report with atomic rename.
if ($OutputRecords.Count -gt 0) {
    $temporary=$OutputCsv + '.partial'
    $OutputRecords | Export-Csv -LiteralPath $temporary -NoTypeInformation -ErrorAction Stop
    [IO.File]::Move($temporary, $OutputCsv)
    Write-Output "Exported $($OutputRecords.Count) devices: $OutputCsv"
} else { Write-Output 'Enumeration succeeded; no devices matched the selected filters.' }
