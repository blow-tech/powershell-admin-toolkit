<#
=============================================================================================
Name:        Manage Active Directory Groups Using PowerShell Script
Description: This script helps you perform 16 Active Directory group management actions, including both single and bulk operations, to save time and reduce manual effort. 
Version:     1.0
Website:     o365reports.com

~~~~~~~~~~~~~~~~~~
Script Highlights:
~~~~~~~~~~~~~~~~~~
1. Performs 16 actions to manage Active Directory groups.
2. Allows you to perform specific group management actions directly.   
3. Enables bulk group management for all actions using CSV input files.  
4. Enables you to perform multiple actions without repeatedly running the script.  
5. Requires a preinstalled ActiveDirectory module; SupportsShouldProcess protects all mutation helpers.
6. Exports execution results to a CSV log file for easier tracking and analysis.   
 
For detailed script execution: https://o365reports.com/manage-active-directory-groups-using-powershell/  

=============================================================================================
#>


[CmdletBinding(SupportsShouldProcess, ConfirmImpact="High")]
param (
    [string]$Action = "0",
    [string]$InputCsvFilePath,
    [switch]$MultiExecutionMode,
    [PSCredential]$Credential,
    [switch]$ExecuteBulk,
    [string]$InputCsvSha256,
    [string]$DomainName
)

function Connect-AdModule {
    Import-Module ActiveDirectory -ErrorAction Stop
}

function Log-ScriptExecution {
    param (
        [string]$Identity,
        [string]$Operation,
        [boolean]$Status,
        [string] $ExecutionMessage,
        [string]$ErrorMessage
    )

    $EventTime = (Get-Date).ToLocalTime()
    $CSVEntry = [PSCustomObject]@{
        "Event Time"    = $EventTime
        "Identity"     = $Identity
        "Operation"    = $Operation
        "Status"       = if ($Status) { "Success" } else { "Failed" }
        "Error Message" = if ([string]::IsNullOrEmpty($ErrorMessage)) { "-" } else { $ErrorMessage }
    }

    $CSVEntry | Export-Csv -Path $LogFilePath -NoTypeInformation -Append -Force

    if (([string]::IsNullOrEmpty($InputCsvFilePath))) {
        $script:OperationStatus = $Status
        if ($Status) {
            $script:Message = $ExecutionMessage
        } else {
            $script:Message = "Attempt to $Operation is failed. Error: $ErrorMessage"
        }
    }
}

function ValidateAndImportCsv {
    param (
        [string]$FilePath,
        [string[]]$RequiredColumns
    )

    try {
        if (-not (Test-Path $FilePath)) {
            Write-Host "CSV file not found at: $FilePath" -ForegroundColor Red
            Exit 1
        }

        $csvData = @($script:ApprovedCsv)

        if ($csvData.Count -eq 0) {
            Write-Host "CSV file is empty. Please check and update the csv file." -ForegroundColor Red
            Exit 1
        }

        $csvColumns = $csvData[0].PSObject.Properties.Name
        $missing = @($RequiredColumns | Where-Object { $_ -notin $csvColumns })

        if ($missing.Count -gt 0) {
            Write-Host "`nCSV validation failed. Missing column(s): $($missing -join ', ')" -ForegroundColor Red
            Exit 1
        }

        return $csvData
    }
    catch {
        Write-Host "`nCSV validation error: $($_.Exception.Message)" -ForegroundColor Red
        Exit 1
    }
}

function Exit-Script {
    param([switch]$Exit)
    if((Test-Path -Path $LogFilePath) -eq "True")
    {   
        Write-Host `n "The Log file is availble in: " -NoNewline -ForegroundColor Yellow; Write-Host "$LogFilePath"
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open log file?",` 0,"Open Log File",4)
        if ($UserInput -eq 6)
        {
            Invoke-Item "$LogFilePath"
        }
    }

    Write-Host `n~~ Script prepared by Admindroid Community ~~`n -ForegroundColor Green
    Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "admindroid.com" -ForegroundColor Yellow -NoNewline; Write-Host " to access 450+ insightful reports and 70+ management actions across your Active Directory environment. ~~" -ForegroundColor Green `n
    
    if ($Exit.IsPresent) { if (-not $script:AllSuccess) { throw "One or more AD operations failed. Review the log." }; return }
}

function New-ADGroupCustom {
    param (
        [string]$GroupName,
        [string]$Scope,
        [string]$Category,
        [string]$OUPath
    )
    if (-not $script:ChangeCmdlet.ShouldProcess("$GroupName in $OUPath", "New-ADGroupCustom")) { return }


    try {
        New-ADGroup -Name $GroupName -GroupScope $Scope -GroupCategory $Category -Path $OUPath -ErrorAction Stop @credParams
        Log-ScriptExecution -Identity "CN=$GroupName,$OUPath" -Operation "create group" -Status $true -ExecutionMessage "CN=$GroupName,$OUPath is created successfully." -ErrorMessage ""
    }
    catch {
        $script:AllSuccess = $false
        Log-ScriptExecution -Identity $GroupName -Operation "create group" -Status $false -ErrorMessage $_.Exception.Message
    }
}

function Add-ADGroupMembersCustom {
    param (
        [string]$GroupDN,
        [string]$Member
    )
    if (-not $script:ChangeCmdlet.ShouldProcess("$GroupDN member $Member", "Add-ADGroupMembersCustom")) { return }


    try {
        Add-ADGroupMember -Identity (Get-ADGroup -Identity $GroupDN -ErrorAction Stop @credParams).ObjectGUID -Members $Member -ErrorAction Stop @credParams
        Log-ScriptExecution -Identity $GroupDN -Operation "add member to group" -Status $true -ExecutionMessage "Member: $Member is added to the group: $GroupDN successfully." -ErrorMessage ""
    }
    catch {
        $script:AllSuccess = $false
        Log-ScriptExecution -Identity $GroupDN -Operation "add member to group" -Status $false -ErrorMessage $_.Exception.Message
    }
}

function Remove-ADGroupMembersCustom {
    param (
        [string]$GroupDN,
        [string]$Member
    )
    if (-not $script:ChangeCmdlet.ShouldProcess("$GroupDN member $Member", "Remove-ADGroupMembersCustom")) { return }


    try {
        $group = Get-ADGroup -Identity $GroupDN -Properties member -ErrorAction Stop @credParams
        if (!($group.member -contains $Member)) {
            throw "member:$($Member) is not a member of this group: $($GroupDN )"
        }
        Remove-ADGroupMember -Identity $group.ObjectGUID -Members $Member -Confirm:$false -ErrorAction Stop @credParams
        Log-ScriptExecution -Identity $GroupDN -Operation "remove member from group" -Status $true -ExecutionMessage "Member: $Member is removed from group: $GroupDN successfully." -ErrorMessage ""
    }
    catch {
        $script:AllSuccess = $false
        Log-ScriptExecution -Identity $GroupDN -Operation "remove member from group" -Status $false -ErrorMessage $_.Exception.Message
    }
}

function Move-ADGroupToOU {
    param([string]$GroupDN,[string]$TargetOU,[string]$disable,[string]$enable)
    $group = Get-ADGroup -Identity $GroupDN -Properties ProtectedFromAccidentalDeletion -ErrorAction Stop @credParams
    $target = Get-ADOrganizationalUnit -Identity $TargetOU -ErrorAction Stop @credParams
    if (-not $script:ChangeCmdlet.ShouldProcess("$($group.ObjectGUID) -> $($target.ObjectGUID)", 'Move group and restore original deletion protection')) { return }
    $restore = [bool]$group.ProtectedFromAccidentalDeletion
    try {
        if ($restore) { Set-ADObject -Identity $group.ObjectGUID -ProtectedFromAccidentalDeletion $false -ErrorAction Stop @credParams }
        Move-ADObject -Identity $group.ObjectGUID -TargetPath $target.DistinguishedName -ErrorAction Stop @credParams
    } catch {
        $script:AllSuccess=$false
        throw
    } finally {
        if ($restore) {
            try { Set-ADObject -Identity $group.ObjectGUID -ProtectedFromAccidentalDeletion $true -ErrorAction Stop @credParams }
            catch { throw "CRITICAL: deletion protection could not be restored on $($group.ObjectGUID): $($_.Exception.Message)" }
        }
    }
    Log-ScriptExecution -Identity $group.ObjectGUID -Operation 'Move group' -Status $true -ExecutionMessage 'Moved; original deletion protection restored.'
}

function Remove-ADGroupCustom {
    param([string]$GroupDN,[string]$canRemove)
    $group = Get-ADGroup -Identity $GroupDN -Properties ProtectedFromAccidentalDeletion -ErrorAction Stop @credParams
    if (-not $script:ChangeCmdlet.ShouldProcess("$($group.DistinguishedName) [$($group.ObjectGUID)]", 'Delete group permanently from active directory; recovery requires AD Recycle Bin or backup')) { return }
    $restore = [bool]$group.ProtectedFromAccidentalDeletion
    $removed=$false
    try {
        if ($restore) { Set-ADObject -Identity $group.ObjectGUID -ProtectedFromAccidentalDeletion $false -ErrorAction Stop @credParams }
        Remove-ADGroup -Identity $group.ObjectGUID -Confirm:$false -ErrorAction Stop @credParams
        $removed=$true
    } finally {
        if ($restore -and -not $removed) {
            try { Set-ADObject -Identity $group.ObjectGUID -ProtectedFromAccidentalDeletion $true -ErrorAction Stop @credParams }
            catch { throw "CRITICAL: failed to restore deletion protection on $($group.ObjectGUID): $($_.Exception.Message)" }
        }
    }
    Log-ScriptExecution -Identity $group.ObjectGUID -Operation 'Delete group' -Status $true
}

function Restore-ADGroupByName {
    param (
        [string]$GroupName
    )
    if (-not $script:ChangeCmdlet.ShouldProcess($GroupName, "Restore-ADGroupByName")) { return }


    try {
           
            $RecycleBinEnable=(Get-ADOptionalFeature -Identity 'Recycle Bin Feature' @credParams ).EnabledScopes
            $del = Get-ADObject -Filter "samAccountName -eq '$($GroupName.Replace("'", "''"))' -and ObjectClass -eq 'group'" -IncludeDeletedObjects -Properties lastKnownParent, whenChanged @credParams | Sort-Object whenChanged -Descending | Select-Object -First 1
            
            if ($del) 
            {
                if (-not $del.lastKnownParent) {
                    throw "Cannot restore. lastKnownParent is missing."
                }
                if ($RecycleBinEnable -and $RecycleBinEnable.Count -gt 0)
                {
                    Restore-ADObject -Identity $del.ObjectGUID -ErrorAction Stop @credParams
                }
                else
                {
                    Restore-ADObject -Identity $del.ObjectGUID -NewName "$GroupName" -ErrorAction Stop @credParams
                }
                $GroupDN=(Get-ADGroup -Identity $del.ObjectGUID -Properties distinguishedName -ErrorAction Stop @credParams).distinguishedName
                Log-ScriptExecution -Identity $GroupDN -Operation "restore group" -ExecutionMessage "$GroupDN is restored successfully." -Status $true -ErrorMessage ""
            }
            else {
                throw "Not found in deleted objects."
            }
       
    }
    catch {
        $script:AllSuccess = $false
        Log-ScriptExecution -Identity $GroupName -Operation "restore group" -Status $false -ErrorMessage $_.Exception.Message
    }
}

function Update-GroupManager {
    param (
        [string]$manager,
        [string]$GroupDN,
        [string]$enableManagerAccess,
        [string]$action       
    )
    if (-not $script:ChangeCmdlet.ShouldProcess("$GroupDN manager $manager", "Update-GroupManager")) { return }

    try {
     if($action -eq "set"){
            Set-ADObject -Identity (Get-ADGroup -Identity $GroupDN -ErrorAction Stop @credParams).ObjectGUID  -Replace @{ managedBy = $manager} -ErrorAction Stop @credParams
            if ([string]::IsNullOrWhiteSpace($enableManagerAccess))
            {
                $enableManagerAccess=(Read-Host "`nDo you want to enable 'Manager can update membership list'? [Y] Yes [N] No").Trim()
            }
            if($enableManagerAccess -match "[yY]")
            {
              Update-ManagerAccess -GroupDN $GroupDN -toEnable "Enable"
            }
        }
    else
    {
        $ManagerDN = (Get-ADGroup -Identity $GroupDN -Properties ManagedBy -ErrorAction Stop @credParams).ManagedBy
        if([string]::IsNullOrWhiteSpace($ManagerDN) ) {
            throw "manager doesn't exist in this group: $($GroupDN )"
        }
        Update-ManagerAccess -GroupDN $GroupDN -toEnable "Disable"
        Set-ADGroup -Identity (Get-ADGroup -Identity $GroupDN -ErrorAction Stop @credParams).ObjectGUID -Clear managedBy -ErrorAction Stop @credParams
    }
    Log-ScriptExecution -Identity $GroupDN -Operation "$action group manager" -Status $true -ExecutionMessage "Group manager is $action successfully." -ErrorMessage ""
    }
    catch {
        $script:AllSuccess = $false
        Log-ScriptExecution -Identity $GroupDN -Operation "$action group manager" -Status $false -ErrorMessage  $_.Exception.Message
    }
}

function Update-ManagerAccess
{
    param (
        [string]$GroupDN,
        [string]$toEnable       
    )
    if (-not $script:ChangeCmdlet.ShouldProcess("$GroupDN delegation $toEnable", "Update-ManagerAccess")) { return }

     try {
        $ManagerDN = (Get-ADGroup -Identity $GroupDN -Properties ManagedBy -ErrorAction Stop @credParams).ManagedBy
        if([string]::IsNullOrWhiteSpace($ManagerDN) ) {
            throw "manager doesn't set for this group: $($GroupDN )"
        }
        if ($null -eq $Credential)
        {
            $entry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($GroupDN)")
        }
        else
        {
            $entry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($DomainName)/$($GroupDN)",$Credential.UserName,$Credential.GetNetworkCredential().Password)
        }
        $acl = $entry.ObjectSecurity

        $manager = Get-ADObject $ManagerDN -Properties objectSID, objectClass -ErrorAction Stop @credParams

        if (-not $manager.objectSID) {
            throw "Object '$ManagerDN' cannot be delegated permissions."
        }

    
        $identity = New-Object System.Security.Principal.SecurityIdentifier(
            $manager.objectSID
        )
        $schemaPath = (Get-ADRootDSE @credParams).SchemaNamingContext 
        $memberAttr = Get-ADObject -SearchBase $schemaPath -LDAPFilter "(lDAPDisplayName=member)" -Properties schemaIDGUID @credParams
        $memberGuid = [Guid]::New([byte[]]$memberAttr.schemaIDGUID)
   
        $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule (
            $identity,
            [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty,
            [System.Security.AccessControl.AccessControlType]::Allow,
            $memberGuid,
            [System.DirectoryServices.ActiveDirectorySecurityInheritance]::None
        )

                
       
       if($toEnable -eq "enable")
       {
        $acl.AddAccessRule($rule)
       }
       else
       {
        $acl.RemoveAccessRuleSpecific($rule)
       } 
        $entry.ObjectSecurity = $acl
        $entry.CommitChanges()
    
        $entry.Dispose() 
    
        Log-ScriptExecution -Identity $GroupDN -Operation "$toEnable manager can update membership list" -Status $true -ExecutionMessage "Manager can update membership list is $($toEnable)d successfully." -ErrorMessage ""
    }
    catch {
        $script:AllSuccess = $false
        Log-ScriptExecution -Identity $GroupDN -Operation "$toEnable manager can update membership list" -Status $false -ErrorMessage  $_.Exception.Message
    }
}

function Update-AccidentalDeletionProtection {
    param (
        [string]$Identity,
        [bool]$Status
    )
    if (-not $script:ChangeCmdlet.ShouldProcess("$Identity protection=$Status", "Update-AccidentalDeletionProtection")) { return }

    try {
        Set-ADObject -Identity $Identity -ProtectedFromAccidentalDeletion $Status -ErrorAction Stop @credParams
        Log-ScriptExecution -Identity $Identity -Operation "$(if ($Status) { 'Enable' } else { 'Disable' }) accidental deletion protection for group" -Status $true -ExecutionMessage "Accidental deletion protection is $($status) for $($Identity) successfully." -ErrorMessage ""
    }
    catch {
        $script:AllSuccess = $false
        Log-ScriptExecution -Identity $Identity -Operation "$(if ($Status) { 'Enable' } else { 'Disable' }) accidental deletion protection for group" -Status $false -ErrorMessage  $_.Exception.Message
    }
}

function Set-PrimaryGroup{
      param (
        [string]$objDN,
        [string]$PrimaryGroup,
        [string]$toAddAsMember
    )
    if (-not $script:ChangeCmdlet.ShouldProcess("$objDN primary group $PrimaryGroup", "Set-PrimaryGroup")) { return }


     try {
        $obj = Get-ADObject -Identity $objDN -Properties primaryGroupID, MemberOf, ObjectClass -ErrorAction Stop @credParams
        $targetGroup = Get-ADGroup -Identity $PrimaryGroup -Properties SID,GroupScope, GroupCategory -ErrorAction Stop @credParams


        if (($targetGroup.GroupCategory -ne "Security") -or ($targetGroup.GroupScope -eq "DomainLocal")) 
        {
           throw "This group type or scope cannot be set as the Primary Group"            
        }
        $targetSID = if ($targetGroup.SID -is [System.Security.Principal.SecurityIdentifier]) {
                        $targetGroup.SID
                     } else {
                        [System.Security.Principal.SecurityIdentifier]$targetGroup.SID.Value
                     }
        $targetRID = $targetSID.Value.Split('-')[-1]
        if($targetRID -eq $obj.primaryGroupID)
        {
         Log-ScriptExecution -Identity $PrimaryGroup -Operation "Set Primary Group For $($obj.ObjectClass)" -Status $true -ExecutionMessage "Group is already a primary group of given object."
         return
        }
        if ($obj.MemberOf -notcontains $PrimaryGroup) 
        {
             if ([string]::IsNullOrWhiteSpace($toAddAsMember)) 
             {
                  Write-Host "`n$($obj.ObjectClass) is not a member of $($targetGroup.Name), would you like me to add the $($obj.ObjectClass) to group and execute this action?"
                  $toAddAsMember=(Read-Host "[Y] Yes [N] No").Trim()
              }
          if($toAddAsMember -match "[yY]")
          {
            Add-ADGroupMembersCustom  -Member $objDN -GroupDN $PrimaryGroup
          }
          else
          {
            throw "$($obj.Name) is not a member of $($targetGroup.Name)"
          }
        }
        Set-ADObject -Identity $objDN -Replace @{ primaryGroupID = $targetRID } -ErrorAction Stop @credParams
        Log-ScriptExecution -Identity $objDN -Operation "set primary group for $($obj.ObjectClass)" -Status $true -ExecutionMessage "$($PrimaryGroup) is set as primary group for $($obj.ObjectClass):$objDN"  -ErrorMessage ""
    }
    catch {
        $script:AllSuccess = $false
        Log-ScriptExecution -Identity $objDN -Operation "set primary group for object" -Status $false -ErrorMessage $_.Exception.Message
    }
}

function Update-ADGroupProperties {

    param (
        [string]$GroupDN,
        [string]$PropertyToUpdate,
        [string]$OperationToPerform,
        [string]$Value
    )
    if (-not $script:ChangeCmdlet.ShouldProcess("$GroupDN property $PropertyToUpdate", "Update-ADGroupProperties")) { return }


    try {
        $setParams = @{ Identity = $GroupDN; ErrorAction = 'Stop' }

        switch ($OperationToPerform) {
            'Add' {
                $setParams['Add'] = @{ $PropertyToUpdate = $Value }
            }
            'Replace' {
                if ($PropertyToUpdate -eq 'ProtectedFromAccidentalDeletion') {
                    $setParams[$PropertyToUpdate] = [System.Convert]::ToBoolean($Value)
                    break
                }
                $setParams['Replace'] = @{ $PropertyToUpdate = $Value }
            }
            'Remove' {
                $setParams['Remove'] = @{ $PropertyToUpdate = $Value }
            }
            'Clear' {
                $setParams['Clear'] = @($PropertyToUpdate)
            }
            default {
                throw "Invalid operation: $OperationToPerform. Valid operations are Add, Replace, Remove, Clear."
            }
        }

        Set-ADObject @setParams @credParams
        Log-ScriptExecution -Identity $GroupDN -Operation "$OperationToPerform group property ($PropertyToUpdate)" -Status $true -ExecutionMessage "$($OperationToPerform) group property ($($PropertyToUpdate)) is performed successfully for $($GroupDN)."
    }
    catch {
        $script:AllSuccess = $false
        Log-ScriptExecution -Identity $GroupDN -Operation "$OperationToPerform group property ($PropertyToUpdate)" -Status $false -ErrorMessage $_.Exception.Message
    }
}

function Rename-ADObjects {
    param (
        [string]$Name,
        [string]$NewSamAccountName,
        [string]$Identity       
    )
    if (-not $script:ChangeCmdlet.ShouldProcess("$Identity new name $Name", "Rename-ADObjects")) { return }

    try {
        if(!([string]::IsNullOrWhiteSpace($NewSamAccountName)))
        {
            Set-ADGroup -Identity $Identity -SamAccountName $NewSamAccountName @credParams
            Log-ScriptExecution -Identity $Identity -Operation "rename group SamAccountName  to '$($NewSamAccountName)'" -Status $true
        }
        Rename-ADObject -Identity $Identity -NewName $Name @credParams        
        Log-ScriptExecution -Identity $Identity -Operation "rename group to '$($Name)'" -Status $true -ExecutionMessage "Group:$($Identity) is renamed successfully."

    }
    catch {
        $script:AllSuccess = $false
        Log-ScriptExecution -Identity $Identity -Operation "rename group to '$($Name)'" -Status $false -ErrorMessage  $_.Exception.Message
    }
}

$ErrorActionPreference='Stop'
$script:ChangeCmdlet=$PSCmdlet
$credParams = @{}
$script:CredentialBasedExecution = ($null -ne $Credential)
if ($Credential) { $credParams.Credential=$Credential }
if ($DomainName) { $credParams.Server=$DomainName }
$script:ApprovedCsv=$null
if ($InputCsvFilePath) {
    if (-not $WhatIfPreference) {
        if (-not $ExecuteBulk -or $InputCsvSha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Bulk execution requires -ExecuteBulk and the reviewed -InputCsvSha256. Use -WhatIf to plan first.' }
        if ((Get-FileHash -LiteralPath $InputCsvFilePath -Algorithm SHA256).Hash -ne $InputCsvSha256) { throw 'CSV digest does not match the reviewed plan.' }
    }
    $script:ApprovedCsv=@(Import-Csv -LiteralPath $InputCsvFilePath -ErrorAction Stop)
    $duplicates=@($script:ApprovedCsv | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Group-Object | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) { throw 'Duplicate input rows refused.' }
}

Connect-AdModule
$script:OperationStatus = $null
$script:Message = ""
$script:AllSuccess = $true
$script:ActionName = ""
$script:RequireCSV = 0
$Location = Get-Location
$LogFilePath = "$Location\ADGroup_Management_Log_$(Get-Date -Format 'yyyy-MMM-dd-ddd_hh-mm_tt').csv"

do {
    if ($Action -eq "0") {
        Write-Host "`n=======================================" -ForegroundColor cyan
        Write-Host "   Active Directory Group Management   " -ForegroundColor Green
        Write-Host "=======================================`n" -ForegroundColor cyan
        Write-Host "You can also perform bulk operations by passing the -InputCSVFilePath parameter during script execution.`n" -ForegroundColor DarkYellow
        Write-Host @"
        1. Create group(s) 
        2. Add member(s) to group(s) 
        3. Set manager(s) to group(s)
        4. Enable group manager can modify the member list 
        5. Enable accidental deletion protection for group(s)
        6. Set primary group(s) 
        7. Move group(s) from one OU to another OU 
        8. Rename group(s) 
        9. Update group property(s) 
       10. Disable group manager can modify the member list 
       11. Disable accidental deletion protection for group(s)
       12. Remove group(s) manager(s)
       13. Remove members from group(s)
       14. Delete group(s) 
       15. Restore group(s) 
       16. Exit
       
"@ -ForegroundColor Yellow

        $Action = (Read-Host "`nPlease choose the action to continue").Trim()
        if (($script:RequireCSV -gt 0) -and (!([string]::IsNullOrEmpty($InputCsvFilePath))) -and ($Action -ne "16")) {
                $InputCsvFilePath = (Read-Host "`nEnter input CSV file path to perform bulk operation, or press 'Enter' to run single operation").Trim()
        }
    }

    switch ($Action) {
        "1" {
            $script:ActionName = "Create group(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $GroupName = (Read-Host -Prompt "`nEnter the group name").Trim()
                $Scope     = (Read-Host -Prompt "`nEnter the group scope (Global, Universal, DomainLocal)").Trim()
                $Category  = (Read-Host -Prompt "`nEnter the group type (Security, Distribution)").Trim()
                $OUPath    = (Read-Host -Prompt "`nEnter the path where you want to create the group").Trim()

                New-ADGroupCustom -GroupName $GroupName -Scope $Scope -Category $Category -OUPath $OUPath
            } else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "GroupName", "GroupScope", "GroupType", "OUPath" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupName)" -PercentComplete 100
                    New-ADGroupCustom -GroupName $_.GroupName -Scope $_.GroupScope -Category $_.GroupType -OUPath $_.OUPath
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

        "2" {
            $script:ActionName = "Add member(s) to group(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $GroupDN = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                $Member  = (Read-Host -Prompt "`nEnter the distinguished name of the object to add").Trim()
                Add-ADGroupMembersCustom -GroupDN $GroupDN -Member $Member
            } else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "GroupDN", "Member" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100
                    Add-ADGroupMembersCustom -GroupDN $_.GroupDN -Member $_.Member
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

        "3" {
            $script:ActionName = "Set manager(s) to group(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $manager = (Read-Host -Prompt "`nEnter the distinguished name of the manager").Trim()
                $GroupDN = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                Update-GroupManager -manager $manager -GroupDN $GroupDN -action "set"
            } 
            else {
                $enableManagerAccess=(Read-Host "Do you want to enable 'Manager can update membership list'?[Y] Yes [N] No").Trim()
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "Manager", "GroupDN" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100                    
                    Update-GroupManager -manager $_.Manager -GroupDN $_.GroupDN -action "set" -enableManagerAccess $enableManagerAccess
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

       
        "4" {
            $script:ActionName = "Enable group manager can modify the member list"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $GroupDN = (Read-Host -Prompt "Enter the distinguished name of the group").Trim()
                Update-ManagerAccess -GroupDN $GroupDN -toEnable "enable"
            } 
            else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "GroupDN" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100
                    Update-ManagerAccess -GroupDN $_.GroupDN -toEnable "enable"
                     $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }
       
        "5" {
            $script:ActionName = "Enable accidental deletion protection for group(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $Identity = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                Update-AccidentalDeletionProtection -Identity $Identity -Status $true
            } else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "Identity" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.Identity)" -PercentComplete 100
                    Update-AccidentalDeletionProtection  -Identity $_.Identity -Status $true
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }
      

        "6" {
            $script:ActionName = "Set primary group(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                    $ObjDN = (Read-Host -Prompt "`nEnter the distinguished name of the object").Trim()
                    $GroupDN = (Read-Host -Prompt "`nEnter the distinguished name of the group to set as primary").Trim()
                    Set-PrimaryGroup -objDN $ObjDN -PrimaryGroup $GroupDN
            } else {
                Write-Host "`nIf given object is not a member of the group. Would you like to add it as a member and make it the primary group?"
                $toAddAsMember=(Read-Host "[Y] Yes [N] No").Trim()
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "ObjectDN", "GroupDN" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100
                    Set-PrimaryGroup  -objDN $_.ObjectDN -PrimaryGroup $_.GroupDN -toAddAsMember $toAddAsMember
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

        "7" {
            $script:ActionName = "Move group(s) from one OU to another OU"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $GroupDN = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                $TargetOU  = (Read-Host -Prompt "Enter the target path of the Organizational Unit (OU)").Trim()
                Move-ADGroupToOU -GroupDN $GroupDN -TargetOU $TargetOU
            } else {
                $disable=(Read-Host "`nIf accidental deletion protection is enabled for this group, do you want to disable it and continue? [Y] Yes [N] No").Trim()
                $enable=(Read-Host "`nDo you want to enable accidental deletion protection after relocating this group? [Y] Yes [N] No").Trim()
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "GroupDN", "TargetOU" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100
                    Move-ADGroupToOU -GroupDN $_.GroupDN -TargetOU $_.TargetOU -disable $disable -enable $enable
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

        "8" {
            $script:ActionName = "Rename group(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $GroupDN = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                $newName = (Read-Host -Prompt "`nEnter the new name").Trim()
                $change= (Read-Host "Would you like to change the SAM account name? Y (yes) or N (no)").Trim()
               
                if($change -match "[yY]")
                {
                 $NewSamAccountName=(Read-Host -Prompt "`nEnter the new SamAccountName").Trim()
                }
                Rename-ADObjects -Name $newName -Identity $GroupDN -NewSamAccountName $NewSamAccountName
            } 
            else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "GroupDN", "NewName" , "NewSamAccountName" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100
                    Rename-ADObjects -Identity $_.GroupDN -Name $_.NewName -NewSamAccountName $_.NewSamAccountName
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

        "9" {
            $script:ActionName = "Update group property(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $GroupDN = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                $OperationToPerform = (Read-Host -Prompt "`nEnter the operation to perform (Add/Remove/Replace/Clear)").Trim()
                $prop = (Read-Host -Prompt "`nEnter the property name to update").Trim()
                if($OperationToPerform -ne "Clear"){ $Value = (Read-Host -Prompt "Enter the value").Trim()}
                Update-ADGroupProperties -GroupDN $GroupDN -PropertyToUpdate $prop -Value $Value -OperationToPerform $OperationToPerform
            } else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "GroupDN", "PropertyToUpdate", "Value", "OperationToPerform" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100
                    Update-ADGroupProperties -GroupDN $_.GroupDN -PropertyToUpdate $_.PropertyToUpdate -Value $_.Value -OperationToPerform $_.OperationToPerform
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
                break
        }

         "10" {
            $script:ActionName = "Disable group manager can modify the member list"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $GroupDN = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                Update-ManagerAccess -GroupDN $GroupDN -toEnable "disable"
            } 
            else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "GroupDN" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100
                    Update-ManagerAccess -GroupDN $_.GroupDN -toEnable "disable"
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

      "11" {
            $script:ActionName = "Disable accidental deletion protection for group(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $Identity = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                Update-AccidentalDeletionProtection -Identity $Identity -Status $false
            } else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "Identity" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.Identity)" -PercentComplete 100
                    Update-AccidentalDeletionProtection  -Identity $_.Identity -Status $false
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

     "12" {
            $script:ActionName = "Remove group(s) manager(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $GroupDN = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                Update-GroupManager -GroupDN $GroupDN -action "removed"
            } 
            else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "GroupDN" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100
                    Update-GroupManager -GroupDN $_.GroupDN  -action "removed"
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

      "13" {
             $script:ActionName = "Remove members from group(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $GroupDN = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                $Member   = (Read-Host -Prompt "`nEnter the distinguished name of the object to remove").Trim()
                Remove-ADGroupMembersCustom -GroupDN $GroupDN -Member $Member
            } else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "GroupDN", "Member" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100
                    Remove-ADGroupMembersCustom -GroupDN $_.GroupDN -Member $_.Member
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

        "14"{
            $script:ActionName = "Delete group(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $GroupDN = (Read-Host -Prompt "`nEnter the distinguished name of the group").Trim()
                Remove-ADGroupCustom -GroupDN $GroupDN
            } else {
                Write-Host "`nIf accidental deletion protection is enabled for this group, do you want to disable it and continue?"
                $canRemove=(Read-Host "[Y] Yes [N] No").Trim()
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "GroupDN" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.GroupDN)" -PercentComplete 100
                    Remove-ADGroupCustom -GroupDN $_.GroupDN -canRemove $canRemove
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
         }

       "15" {
            $script:ActionName = "Restore group(s)"
            if ([string]::IsNullOrWhiteSpace($InputCsvFilePath)) {
                $samAccountName = (Read-Host -Prompt "`nEnter group's samAccountName to restore").Trim()
                Restore-ADGroupByName -GroupName $samAccountName
            } else {
                ValidateAndImportCsv -FilePath $InputCsvFilePath -RequiredColumns "samAccountName" | ForEach-Object {
                    Write-Progress -Activity "Processed groups count: $($Count)" -Status "Currently Processing $($_.samAccountName)" -PercentComplete 100
                    Restore-ADGroupByName -GroupName $_.samAccountName
                    $Count++
                }
                Write-Progress -Activity "Completed" -Completed
            }
            break
        }

       "16" {
            Exit-Script -Exit
        }

        default {
            Write-Host "`nInvalid choice. Please enter the valid option." -ForegroundColor Red
            Exit-Script -Exit
        }
    }

    if ($script:OperationStatus -ne $null) {
        if ($script:OperationStatus -eq $true) {
            Write-Host "`n$($script:Message)" -ForegroundColor Green
        } else {
            Write-Host "`n$($script:Message)" -ForegroundColor Red
        }
    }

    if ($MultiExecutionMode.IsPresent -and ![string]::IsNullOrWhiteSpace($InputCsvFilePath)) { 
        if ($script:AllSuccess) {
            Write-Host "`n$ActionName completed successfully for all groups." -ForegroundColor Green
        }
        else {
            Write-Host "`n$ActionName completed with some failures. Check the log file: $LogFilePath" -ForegroundColor red
        } 
        $script:AllSuccess = $true
        $script:ActionName = ""
    }

    if ($MultiExecutionMode.IsPresent)
    { 
        $Action = "0"
        $script:RequireCSV = 1
    }

} while ($MultiExecutionMode.IsPresent)

$credParams = @{}
$script:cred = $null; $script:domainName = $null
$script:CredentialBasedExecution = $false
$script:OperationStatus = $null; $script:Message = ""

Exit-Script

if (-not $script:AllSuccess) { throw "One or more AD operations failed; review the execution log." }
