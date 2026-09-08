#Requires -Version 5.1
<#
Requires existing Graph and Exchange sessions in the explicitly expected tenant.
Use -WhatIf to review resolved immutable users and requested actions.
Actions: 1 disable, 2 revoke sessions, 3 reset password, 4 review MFA,
5 disable inbox rules, 6 review forwarding, 7 remove forwarding, 8 export audit.
Supply a pre-provisioned protected EvidenceDirectory. No modules are installed.
PasswordHandoff must accept (userId, SecureString) and deliver through an approved
secret system without writing the secret to console, transcript, logs or plain files.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [string]$CSVFilePath,
    [string[]]$UPNs,
    [Parameter(Mandatory)][ValidateSet(1,2,3,4,5,6,7,8)][int[]]$Actions,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [scriptblock]$PasswordHandoff
)
$ErrorActionPreference='Stop'
function New-RemediationPassword {
    $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
    function Get-CryptoIndex([int]$Limit) {
        $bytes=New-Object byte[] 1
        do { $rng.GetBytes($bytes); $value=[int]$bytes[0] } while ($value -ge (256 - (256 % $Limit)))
        return $value % $Limit
    }
    try {
        $classes=@('ABCDEFGHJKLMNPQRSTUVWXYZ','abcdefghijkmnopqrstuvwxyz','23456789','!@#$%*-_+=')
        $alphabet=$classes -join ''
        $chars=New-Object 'System.Collections.Generic.List[char]'
        foreach ($class in $classes) { $chars.Add($class[(Get-CryptoIndex $class.Length)]) }
        while ($chars.Count -lt 24) { $chars.Add($alphabet[(Get-CryptoIndex $alphabet.Length)]) }
        for ($i=$chars.Count-1; $i -gt 0; $i--) {
            $j=Get-CryptoIndex ($i+1); $temp=$chars[$i]; $chars[$i]=$chars[$j]; $chars[$j]=$temp
        }
        -join $chars.ToArray()
    } finally { $rng.Dispose() }
}
$context=Get-MgContext
if ($null -eq $context -or $context.TenantId -ne $TenantId.ToString()) { throw 'Graph tenant mismatch or missing session.' }
if (@($Actions | Where-Object { $_ -in 5,6,7,8 }).Count -gt 0) {
    $org=@(Get-OrganizationConfig -ErrorAction Stop)
    if ($org.Count -ne 1 -or [string]$org[0].ExternalDirectoryOrganizationId -ne $TenantId.ToString()) { throw 'Exchange tenant mismatch.' }
}
if (3 -in $Actions -and $null -eq $PasswordHandoff) { throw 'Password reset requires an approved -PasswordHandoff callback accepting a SecureString.' }
$directory=Get-Item -LiteralPath $EvidenceDirectory -Force -ErrorAction Stop
if (-not $directory.PSIsContainer -or $directory.PSProvider.Name -ne 'FileSystem') { throw 'EvidenceDirectory must exist.' }
for ($ancestor=$directory; $null -ne $ancestor; $ancestor=$ancestor.Parent) {
    if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse evidence paths refused.' }
}
if ($CSVFilePath -and $UPNs) { throw 'Use either CSVFilePath (UserPrincipalName header) or UPNs.' }
if ($CSVFilePath) { $UPNs=@((Import-Csv -LiteralPath $CSVFilePath).UserPrincipalName) }
$identities=@($UPNs | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() })
if ($identities.Count -eq 0) { throw 'Supply at least one user.' }
$seen=@{}
$users=@(foreach ($upn in $identities) {
    if ($upn -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw "Invalid UPN: $upn" }
    $user=Get-MgUser -UserId $upn -Property Id,UserPrincipalName -ErrorAction Stop
    if (-not $user.Id -or $seen.ContainsKey($user.Id)) { throw 'Missing or duplicate immutable user ID.' }
    $seen[$user.Id]=$true
    $user
})
$results=New-Object 'System.Collections.Generic.List[object]'
$run=[guid]::NewGuid().ToString('N')
try {
 foreach ($user in $users) {
  foreach ($action in @($Actions | Select-Object -Unique)) {
   $target="$($user.UserPrincipalName) [$($user.Id)] tenant=$TenantId"
   if ($action -in 1,2,3,5,7 -and -not $PSCmdlet.ShouldProcess($target,"Compromised-account action $action")) {
    $results.Add([pscustomobject]@{UserId=$user.Id; Action=$action; Status='Skipped/WhatIf'}); continue
   }
   $evidence=Join-Path $directory.FullName "$run-$($user.Id)-$action.clixml"
   switch ($action) {
    1 { Update-MgUser -UserId $user.Id -AccountEnabled:$false -ErrorAction Stop }
    2 { $revoked=Revoke-MgUserSignInSession -UserId $user.Id -ErrorAction Stop; if (-not $revoked.Value) { throw 'Session revocation was not acknowledged.' } }
    3 {
     $password=New-RemediationPassword
     $profile=@{forceChangePasswordNextSignIn=$true;password=$password}
     try {
      Update-MgUser -UserId $user.Id -PasswordProfile $profile -ErrorAction Stop
      $secure=ConvertTo-SecureString $password -AsPlainText -Force
      & $PasswordHandoff $user.Id $secure | Out-Null
     } catch { throw "Password reset/handoff failed for user ID $($user.Id). Verify action status securely; the secret is never logged." }
     finally { $profile.Clear(); $password=$null; if ($secure) { $secure.Dispose(); $secure=$null } }
    }
    4 { Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction Stop | Select-Object Id,@{n='MethodType';e={$_.AdditionalProperties['@odata.type']}} }
    5 {
     $rules=@(Get-InboxRule -Mailbox $user.UserPrincipalName -ErrorAction Stop)
     $rules | Export-Clixml -LiteralPath $evidence -ErrorAction Stop
     foreach ($rule in $rules | Where-Object Enabled) { Disable-InboxRule -Identity $rule.Identity -Confirm:$false -ErrorAction Stop }
    }
    6 { Get-Mailbox -Identity $user.UserPrincipalName -ErrorAction Stop | Select-Object ExchangeGuid,ForwardingAddress,ForwardingSmtpAddress,DeliverToMailboxAndForward }
    7 {
     $mailbox=Get-Mailbox -Identity $user.UserPrincipalName -ErrorAction Stop
     $mailbox | Select-Object ExchangeGuid,ForwardingAddress,ForwardingSmtpAddress,DeliverToMailboxAndForward | Export-Clixml -LiteralPath $evidence -ErrorAction Stop
     Set-Mailbox -Identity $mailbox.ExchangeGuid.ToString() -ForwardingAddress $null -ForwardingSmtpAddress $null -DeliverToMailboxAndForward:$false -ErrorAction Stop
    }
    8 {
     if ($PSCmdlet.ShouldProcess($evidence,'Export read-only audit evidence')) {
      $events=@(Search-UnifiedAuditLog -UserIds $user.UserPrincipalName -StartDate (Get-Date).AddDays(-10) -EndDate (Get-Date) -ResultSize 5000 -ErrorAction Stop)
      $events | Export-Clixml -LiteralPath $evidence -ErrorAction Stop
      if ($events.Count -ge 5000) { throw 'Audit export reached its row limit; narrow the interval or use paginated audit retrieval.' }
     }
    }
   }
   $results.Add([pscustomobject]@{UserId=$user.Id; Action=$action; Status='Completed'})
  }
 }
} finally {
 if (-not $WhatIfPreference -and $results.Count -gt 0) { $results | Export-Csv -LiteralPath (Join-Path $directory.FullName "$run-status.csv") -NoTypeInformation }
 $results
}
