# ActiveDirectory

PowerShell scripts for Active Directory lifecycle reporting, account auditing, and operational health checks. Built for production environments running Windows Server with AD DS.

All scripts require the **ActiveDirectory** RSAT module and appropriate read permissions unless otherwise noted. No scripts make write changes to AD unless explicitly stated.

---

## Scripts

### `Environment Health-Check.ps1`
Runs a unified health check across AD replication, DNS, certificates, disk, and key services. Outputs a single HTML report suitable for daily ops review or incident triage.

**Requirements:** Domain-joined machine, RSAT, write access to output path  
**Output:** HTML report file

```powershell
.\Environment Health-Check.ps1 -OutputPath "C:\Reports\HealthCheck.html"
```

---

### `Get-ExpiringAccounts_Report.ps1`
Queries AD for user accounts with an upcoming expiry date and generates a report. Useful for pre-emptive lifecycle management and compliance audits.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-DaysAhead` | No | How many days forward to check. Default: `30` |
| `-OutputPath` | No | Path for CSV export. Default: current directory |

```powershell
.\Get-ExpiringAccounts_Report.ps1 -DaysAhead 14 -OutputPath "C:\Reports\ExpiringAccounts.csv"
```

---

### `Get-LastLogon.ps1`
Retrieves the last logon timestamp for AD user accounts. Queries all domain controllers and returns the most recent value to avoid stale single-DC results.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-SearchBase` | No | OU distinguished name to scope the query |
| `-InactiveDays` | No | Filter to accounts inactive for N+ days |
| `-OutputPath` | No | Path for CSV export |

```powershell
.\Get-LastLogon.ps1 -InactiveDays 90 -OutputPath "C:\Reports\LastLogon.csv"
```

---

### `Get-LockedOutLocation.ps1`
Identifies the source machine responsible for an account lockout by querying Security event logs (Event ID 4740) across domain controllers.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-Username` | Yes | SAMAccountName of the locked-out user |

```powershell
.\Get-LockedOutLocation.ps1 -Username jsmith
```

---

### `GetUsersLogonLogoffEvents.ps1`
Queries AD and Security event logs for user logon and logoff activity (Event IDs 4624, 4634, 4647). Useful for access audits and investigating suspicious activity.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-Username` | No | Filter to a specific SAMAccountName |
| `-StartDate` | No | Start of query window. Default: last 7 days |
| `-EndDate` | No | End of query window |
| `-OutputPath` | No | Path for CSV export |

```powershell
.\GetUsersLogonLogoffEvents.ps1 -Username jsmith -StartDate "2025-01-01" -OutputPath "C:\Reports\LogonEvents.csv"
```

---

### `Get_MFA_Status.ps1`
Reports MFA registration status for Entra ID (Azure AD) users via Microsoft Graph API. Identifies accounts with no MFA methods registered.

**Requirements:** `Microsoft.Graph` module, `UserAuthenticationMethod.Read.All` permission  
**Output:** CSV report

```powershell
.\Get_MFA_Status.ps1 -OutputPath "C:\Reports\MFA_Status.csv"
```

---

### `Manage Active Directory Groups.ps1`
Provides group membership management operations: add members, remove members, and report on group membership. Designed for bulk operations driven by CSV input.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-Action` | Yes | `Add`, `Remove`, or `Report` |
| `-GroupName` | Yes | Target AD group name |
| `-CsvPath` | For Add/Remove | CSV file with `Username` column |
| `-OutputPath` | For Report | Path for membership export |

```powershell
.\Manage Active Directory Groups.ps1 -Action Report -GroupName "VPN-Users" -OutputPath "C:\Reports\VPN-Users.csv"
```

---

### `Risky Users Report in Microsoft Entra.ps1`
Pulls the risky users list from Microsoft Entra ID Protection via Graph API. Reports risk level, risk state, and last risk detection date per user.

**Requirements:** `Microsoft.Graph` module, `IdentityRiskyUser.Read.All` permission  
**Output:** CSV report

```powershell
.\Risky Users Report in Microsoft Entra.ps1 -OutputPath "C:\Reports\RiskyUsers.csv"
```

---

### `Send-PasswordExpiry.ps1`
Sends automated email notifications to users whose passwords are approaching expiry. Reads expiry data from AD and dispatches via SMTP or Exchange Online.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-DaysWarning` | No | Notify users expiring within N days. Default: `14` |
| `-SmtpServer` | Yes | SMTP relay hostname or Exchange Online endpoint |
| `-FromAddress` | Yes | Sender address for notifications |

```powershell
.\Send-PasswordExpiry.ps1 -DaysWarning 7 -SmtpServer "smtp.yourdomain.com" -FromAddress "noreply@yourdomain.com"
```

---

## Requirements

- PowerShell 5.1 or later
- RSAT: Active Directory Domain Services tools
- Domain-joined machine with appropriate read permissions
- For Entra ID / Graph scripts: `Microsoft.Graph` PowerShell SDK

```powershell
# Install Graph module if needed
Install-Module Microsoft.Graph -Scope CurrentUser
```

---

## Notes

- Scripts that query multiple domain controllers may take longer in large environments — expected behaviour.
- All output paths default to the current working directory if not specified.
- No script in this folder modifies AD objects unless the description explicitly states otherwise.

---

*Part of [powershell-admin-toolkit](https://github.com/blow-tech/powershell-admin-toolkit)*
