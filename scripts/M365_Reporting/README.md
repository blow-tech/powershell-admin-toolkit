M365 Reporting Kit - Windows PowerShell 5.1

1. Copy .ps1 files to Desktop or another folder.
2. Run: New-Item -Path C:\Report -ItemType Directory -Force
3. Graph connection:
   Import-Module Microsoft.Graph.Authentication
   Connect-MgGraph -Scopes 'User.Read.All','Group.Read.All','GroupMember.Read.All','Organization.Read.All','AuditLog.Read.All'
4. Graph preview:
   .\Export-GraphInventory.ps1 -Report UsersLicenses -PreviewOnly
   .\Export-GraphInventory.ps1 -Report GroupMembers -PreviewOnly
5. Graph full reports:
   .\Export-GraphInventory.ps1 -Report All -OutputFolder C:\Report
   .\Export-EntraLastSignIn.ps1 -OutputPath C:\Report\EntraLastSuccessfulSignIn.csv
6. Exchange Online requires a separate connection and compatible module:
   Connect-ExchangeOnline -UserPrincipalName <your-admin-UPN>
   .\Export-ExchangeInventory.ps1 -Report All -OutputFolder C:\Report

NOTE: PreviewOnly on group reports samples up to five groups and five members per group.
Graph group membership is direct membership, not transitive. Distribution groups and dynamic
membership are not fully represented by this Graph members export; use Exchange for distribution
list membership. Graph users/licenses report uses subscribed SKU part numbers, not product names.
Empty reports may yield an empty CSV. Do not treat missing records as proof of no access.
All scripts read remote data only; CSV files contain sensitive account and access information.
