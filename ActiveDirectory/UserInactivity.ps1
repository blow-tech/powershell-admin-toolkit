#This PowerShell script disables users that have been inactive for 30 days or more.

# Import the Active Directory module
Import-Module ActiveDirectory

# Set the threshold for inactivity (30 days in this example)
$inactiveThreshold = (Get-Date).AddDays(-30)

# Get inactive users
$inactiveUsers = Get-ADUser -Filter {LastLogonDate -lt $inactiveThreshold} -Properties LastLogonDate, SamAccountName, DisplayName | Select-Object SamAccountName, DisplayName, LastLogonDate

# Disable inactive users
foreach ($user in $inactiveUsers) {
    Disable-ADAccount -Identity $user.SamAccountName
    Write-Host "Disabled user: $($user.SamAccountName)"
}

# Display the results
if ($inactiveUsers) {
    Write-Host "Inactive users older than 30 days:"
    $inactiveUsers | Format-Table -AutoSize
} else {
    Write-Host "No inactive users found."
