# M365 Reporting Kit

Read-only PowerShell 5.1 scripts that export Microsoft 365 inventory data to CSV:
Entra ID users, licenses and groups via Microsoft Graph, mailbox permissions and
forwarding via Exchange Online, and the last successful sign-in per user.

## Scripts

| Script | Source | Purpose |
|---|---|---|
| `Export-GraphInventory.ps1` | Microsoft Graph | Users and licenses, license summary, groups, group members and owners, guests |
| `Export-ExchangeInventory.ps1` | Exchange Online | Mailboxes, Full Access, Send As, Send on Behalf, forwarding |
| `Export-EntraLastSignIn.ps1` | Microsoft Graph | Last successful sign-in per user |

## Parameters

| Script | `-Report` values | Other parameters |
|---|---|---|
| `Export-GraphInventory.ps1` | `UsersLicenses`, `LicenseSummary`, `Groups`, `GroupMembers`, `GroupOwners`, `Guests`, `All` (default) | `-OutputFolder` (default `C:\Report`), `-PreviewOnly` |
| `Export-ExchangeInventory.ps1` | `Mailboxes`, `FullAccess`, `SendAs`, `SendOnBehalf`, `Forwarding`, `All` (default) | `-OutputFolder` (default `C:\Report`), `-PreviewOnly` |
| `Export-EntraLastSignIn.ps1` | n/a | `-OutputPath` (default: timestamped CSV in Documents), `-PreviewOnly` |

## Required permissions

| Scope | Used for |
|---|---|
| `User.Read.All` | Users and licenses |
| `Group.Read.All`, `GroupMember.Read.All` | Groups, members, owners |
| `Organization.Read.All` | Subscribed SKUs (license names) |
| `AuditLog.Read.All` | Last sign-in data |

Exchange Online requires a role that can read mailbox permissions (for example View-Only Recipients plus Mail Recipients, or Global Reader).

## Usage

1. Copy the `.ps1` files to a local folder and create the output folder:

```powershell
New-Item -Path C:\Report -ItemType Directory -Force
```

2. Connect to Microsoft Graph:

```powershell
Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes 'User.Read.All','Group.Read.All','GroupMember.Read.All','Organization.Read.All','AuditLog.Read.All'
```

3. Preview first (samples a few rows, nothing is exported in full):

```powershell
.\Export-GraphInventory.ps1 -Report UsersLicenses -PreviewOnly
.\Export-GraphInventory.ps1 -Report GroupMembers -PreviewOnly
```

4. Run the full Graph reports:

```powershell
.\Export-GraphInventory.ps1 -Report All -OutputFolder C:\Report
.\Export-EntraLastSignIn.ps1 -OutputPath C:\Report\EntraLastSuccessfulSignIn.csv
```

5. Exchange Online needs its own connection and the ExchangeOnlineManagement module:

```powershell
Connect-ExchangeOnline -UserPrincipalName <your-admin-UPN>
.\Export-ExchangeInventory.ps1 -Report All -OutputFolder C:\Report
```

## Notes and limitations

- `-PreviewOnly` on group reports samples up to five groups and five members per group.
- Graph group membership is direct, not transitive.
- Distribution groups and dynamic membership are not fully represented by the Graph members export. Use Exchange for distribution list membership.
- The users/licenses report shows subscribed SKU part numbers, not product names.
- An empty report may produce an empty CSV. Missing records are not proof of no access.

## Security

All scripts only read remote data. The exported CSV files contain sensitive account and access information. Store them securely, never commit them to a repository, and delete them when no longer needed.
