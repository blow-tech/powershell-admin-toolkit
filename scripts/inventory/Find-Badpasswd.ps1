# Get users who has bad passwords:
Get-ADUser -Filter * -Properties BadPwdCount, LastBadPasswordAttempt, LockedOut, AccountLockoutTime |
Where-Object { $_.BadPwdCount -ge 1 } |Select-Object SamAccountName,Name, BadPwdCount, LastBadPasswordAttempt, LockedOut, DistinguishedName


# Get users who didn't change the initial password:
Get-ADUser -Filter * -Properties pwdLastSet | Where-Object {$_.pwdLastSet -eq 0} | Select-Object SamAccountName,Name, pwdLastSet, DistinguishedName
