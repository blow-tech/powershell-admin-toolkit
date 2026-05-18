# ExchangeOnline

PowerShell scripts for Exchange Online and Microsoft 365 administration. Covers mailbox auditing, permissions reporting, mail flow analysis, and privileged access review.

All scripts require an active `Connect-ExchangeOnline` session unless otherwise noted. Scripts that query Entra ID or PIM require the `Microsoft.Graph` module and appropriate permissions.

---

## Scripts

### `Audit PIM role.ps1`
Audits Privileged Identity Management (PIM) role assignments in Microsoft Entra ID. Reports both active and eligible assignments, assigned principals, and assignment type (permanent vs time-bound).

**Requirements:** `Microsoft.Graph` module, `RoleManagement.Read.All` permission  
**Output:** CSV report

```powershell
.\Audit PIM role.ps1 -OutputPath "C:\Reports\PIM_Roles.csv"
```

---

### `Get-DistributionGroupMember.ps1`
Exports membership of one or all distribution lists and mail-enabled security groups. Useful for access reviews and group hygiene audits.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-GroupName` | No | Target a specific group by display name or alias. Omit to export all groups. |
| `-OutputPath` | No | Path for CSV export. Default: current directory |

```powershell
# Single group
.\Get-DistributionGroupMember.ps1 -GroupName "IT-Team" -OutputPath "C:\Reports\IT-Team.csv"

# All distribution groups
.\Get-DistributionGroupMember.ps1 -OutputPath "C:\Reports\AllGroups.csv"
```

---

### `Get-MailboxPermissions.ps1`
Audits mailbox permissions across the tenant. Reports Full Access, Send-As, and Send on Behalf delegations per mailbox. Identifies non-inherited and non-self permissions to surface actual delegations.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-Mailbox` | No | Target a specific mailbox by UPN or alias. Omit to scan all mailboxes. |
| `-OutputPath` | No | Path for CSV export |

```powershell
# All mailboxes
.\Get-MailboxPermissions.ps1 -OutputPath "C:\Reports\MailboxPermissions.csv"

# Single mailbox
.\Get-MailboxPermissions.ps1 -Mailbox "j.smith@domain.com" -OutputPath "C:\Reports\jsmith_perms.csv"
```

---

### `Shared Mailbox Size Report.ps1`
Reports size, item count, and quota status for all shared mailboxes in the tenant. Flags mailboxes approaching or exceeding quota limits.

**Output:** CSV report and console summary

```powershell
.\Shared Mailbox Size Report.ps1 -OutputPath "C:\Reports\SharedMailboxSizes.csv"
```

---

### `Trace Emails Sent to External Domains.ps1`
Audits outbound mail flow to external recipients over a specified time window. Pulls message trace data from Exchange Online and reports sender, recipient domain, subject, and delivery status. Useful for data loss and mail flow security reviews.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-StartDate` | No | Start of trace window. Default: last 7 days |
| `-EndDate` | No | End of trace window |
| `-OutputPath` | No | Path for CSV export |

```powershell
.\Trace Emails Sent to External Domains.ps1 -StartDate "2025-01-01" -EndDate "2025-01-31" -OutputPath "C:\Reports\ExternalMailTrace.csv"
```

---

## Requirements

- PowerShell 5.1 or later
- Exchange Online Management module

```powershell
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
Connect-ExchangeOnline -UserPrincipalName admin@domain.com
```

- Microsoft Graph module (for `Audit PIM role.ps1`)

```powershell
Install-Module -Name Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes "RoleManagement.Read.All"
```

---

## Notes

- All scripts are read-only and do not modify mailboxes, permissions, or group membership
- Message trace data in Exchange Online is limited to the last 10 days via `Get-MessageTrace`. Scripts requiring longer windows use `Start-HistoricalSearch` or the compliance centre APIs
- Scanning all mailboxes in large tenants may take several minutes — expected behaviour

---

*Part of [powershell-admin-toolkit](https://github.com/blow-tech/powershell-admin-toolkit)*
