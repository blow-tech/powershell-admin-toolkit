# Sharing-link observations for explicitly supplied sites, not a tenant-wide access audit.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidatePattern('^[a-zA-Z0-9-]+$')][string]$TenantName,
 [Parameter(Mandatory=$true)][guid]$ClientId,
 [Parameter(Mandatory=$true)][string]$CertificateThumbprint,
 [Parameter(Mandatory=$true)][uri[]]$SiteUrl,
 [Parameter(Mandatory=$true)][string]$OutputPath,
 [switch]$ActiveLinks,[switch]$ExpiredLinks,[switch]$LinksWithExpiration,[switch]$NeverExpiresLinks,
 [ValidateRange(0,36500)][int]$SoonToExpireInDays=0,
 [switch]$GetAnyoneLinks,[switch]$GetCompanyLinks,[switch]$GetSpecificPeopleLinks
)
$ErrorActionPreference='Stop'
if (($ActiveLinks -and $ExpiredLinks) -or ($LinksWithExpiration -and $NeverExpiresLinks) -or ($SoonToExpireInDays -and ($ExpiredLinks -or $NeverExpiresLinks)) -or (([int]$GetAnyoneLinks.IsPresent+[int]$GetCompanyLinks.IsPresent+[int]$GetSpecificPeopleLinks.IsPresent) -gt 1)) { throw 'Contradictory filters.' }
foreach ($url in $SiteUrl) { if ($url.Scheme -ne 'https' -or $url.Host -ne "$TenantName.sharepoint.com" -or $url.UserInfo -or $url.Port -ne 443) { throw 'Site URL must match the explicitly selected commercial-cloud tenant.' } }
Import-Module PnP.PowerShell -ErrorAction Stop
. (Join-Path $PSScriptRoot '../scripts/common/ReportSafety.ps1')
$SnapshotUtc=[datetime]::UtcNow
$ResultsBuffer=New-Object 'System.Collections.Generic.List[object]'
$script:ItemCount=0
Function Get-SharedLinks
{
 $ExcludedLists = @("Form Templates","Style Library","Site Assets","Site Pages", "Preservation Hold Library", "Pages", "Images",
                       "Site Collection Documents", "Site Collection Images")
 $DocumentLibraries = Get-PnPList -Connection $Connection -ErrorAction Stop | Where-Object {$_.Hidden -eq $False -and $_.Title -notin $ExcludedLists -and $_.BaseType -eq "DocumentLibrary"}
 Foreach($List in $DocumentLibraries){
 $ListItems = Get-PnPListItem -List $List -PageSize 2000 -Connection $Connection -ErrorAction Stop
 ForEach ($Item in $ListItems)
 {
  $FileName=$Item.FieldValues.FileLeafRef
  $ObjectType=$Item.FileSystemObjectType
  Write-Progress -Activity ("Site Name: $Site") -Status ("Processing Item: "+ $FileName )

  If ($true)
  {
   $FileUrl=$Item.FieldValues.FileRef
   if($ObjectType -eq "File")
   {
    $FileSharingLinks= Get-PnPFileSharingLink -Identity $FileUrl -Connection $Connection -ErrorAction Stop
   }
   elseif($ObjectType -eq "Folder")
   {
    $FileSharingLinks= Get-PnPFolderSharingLink -Folder $FileUrl -Connection $Connection -ErrorAction Stop
   }
   else
   {
    continue
   }
   foreach ($FileSharingLink in $FileSharingLinks)
   {
    $Link=$FileSharingLink.Link
    $Scope= $Link.Scope
    #Filter links based on it's type
    if($GetAnyoneLinks.IsPresent -and ($Scope -ne "Anonymous"))
    {
     Continue
    }
    elseif($GetCompanyLinks.IsPresent -and ($Scope -ne "Organization"))
    {
     Continue
    }
    elseif($GetSpecificPeopleLinks.IsPresent -and ($Scope -ne "Users"))
    {
     Continue
    }

    $Permission=$Link.Type
    $SharedLink=$Link.WebUrl
    $PasswordProtected=$FileSharingLink.HasPassword
    $BlockDownload=$Link.PreventsDownload
    $RoleList = $FileSharingLink.Roles -join ","
    $ExpirationDate=$FileSharingLink.ExpirationDateTime
    $Users=$FileSharingLink.GrantedToIdentitiesV2.User.Email
    $DirectUsers= $Users -join ","
    $CurrentDateTime = $SnapshotUtc
    If($ExpirationDate -ne $null)
    {
     $ExpiryDate = ([DateTimeOffset]$ExpirationDate).UtcDateTime
     $ExpiryDays= ($ExpiryDate - $CurrentDateTime).TotalDays
     If($ExpiryDate -le $CurrentDateTime)
     {
      $LinkStatus = "Expired"
      $ExpiryDateCalculation=$ExpiryDays * (-1)
      $FriendlyExpiryTime="Expired $ExpiryDateCalculation days ago"
     }
     else
     {
      $LinkStatus="Active"
      $FriendlyExpiryTime="Expires in $ExpiryDays days"
     }
    }
    else
    {
     $LinkStatus="Active"
     $ExpiryDays="-"
     $ExpiryDate="-"
     $FriendlyExpiryTime="Never Expires"
    }

    #Filter for active links
    If(($ActiveLinks.IsPresent) -and ($LinkStatus -ne "Active"))
    {
     Continue
    }

    #Filter for expired links
    elseif(($ExpiredLinks.IsPresent) -and ($LinkStatus -ne "Expired"))
    {
     Continue
    }

    #Filter for finding links with expiration
    elseif(($LinksWithExpiration.IsPresent) -and ($ExpirationDate -eq $null))
    {
     Continue
    }

    #Filter for finding links with no expiry
    elseif(($NeverExpiresLinks.IsPresent) -and ($FriendlyExpiryTime -ne "Never Expires"))
    {
     Continue
    }

    #Filter for finding soon-to-expire links
    elseif(($SoonToExpireInDays -gt 0) -and (($ExpirationDate -eq $null) -or ($SoonToExpireInDays -lt $ExpiryDays) -or ($LinkStatus -eq "Expired")))
    {
     Continue
    }

    $Results = [PSCustomObject]@{
                            "Site Name"             = $Site
                            "Library"          = $List.Title
                            "Object Type" =$ObjectType
                            "File/Folder Name"             = $FileName
                            "File/Folder URL"         = $FileUrl
                            "Link Type" =$Scope
                            "Access Type"      = $Permission
                            "Roles" =$RoleList
                            "Users" = $DirectUsers
                            "File Type"         = $Item.FieldValues.File_x0020_Type
                            "Link Status"     = $LinkStatus
                            "Link Expiry Date"  = $ExpiryDate
                            "Days Since/To Expiry" =$ExpiryDays
                            "Friendly Expiry Time" =$FriendlyExpiryTime
                            "Password Protected" =$PasswordProtected
                            "Block Download"    =$BlockDownload
                            "Shared Link"       = $SharedLink
     }
     $ResultsBuffer.Add($Results)
     $script:ItemCount++
    }
   }
  }
 }
}

foreach ($url in $SiteUrl) {
 $Connection=$null
 try {
  $Connection=Connect-PnPOnline -Url $url.AbsoluteUri -ClientId $ClientId.ToString() -Thumbprint $CertificateThumbprint -Tenant "$TenantName.onmicrosoft.com" -ReturnConnection -ErrorAction Stop
  $Site=$url.AbsoluteUri
  Get-SharedLinks
 } finally { $Connection=$null } # Release returned connection without disconnecting caller session.
}
Export-NewReport @($ResultsBuffer.ToArray()) $OutputPath
[pscustomobject]@{Status='Complete for selected sites/libraries';Count=$ResultsBuffer.Count;SnapshotUtc=$SnapshotUtc;OutputPath=$OutputPath}
