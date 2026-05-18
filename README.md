# PowerShell Admin Toolkit

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows%20Server%202016%2B-lightgrey?logo=windows)
![M365](https://img.shields.io/badge/Microsoft%20365-Exchange%20%7C%20Entra%20%7C%20Intune-0078D4?logo=microsoft)
![License](https://img.shields.io/badge/License-MIT-green)
![Last Commit](https://img.shields.io/github/last-commit/blow-tech/powershell-admin-toolkit)

Production PowerShell scripts for Windows Server, Active Directory, Exchange Online, and Microsoft 365 administration. Built from real incidents and daily operations — not tutorial code.

---

## Overview

| Domain | Coverage |
|---|---|
| Active Directory | Account lifecycle, lockout tracing, logon auditing, expiry management, MFA status, risky users |
| Exchange Online | Mailbox permissions, distribution group membership, shared mailbox reporting, mail flow auditing, PIM role audit |
| Microsoft Entra | MFA registration gaps, risky user detection, break glass account reporting, sign-in failure analysis |
| Environment Health | AD replication, DNS, disk, certificates, services — single HTML report output |
| Backup | AD state backup automation |
| Inventory | System info collection, environment audit |

All scripts include comment-based help (accessible via `Get-Help`), parameter validation, and error handling.

---

## Repository Structure

```
powershell-admin-toolkit/
├── ActiveDirectory/
│   ├── Environment Health-Check.ps1              # AD, DNS, disk, cert, service health — HTML report
│   ├── Get-ExpiringAccounts_Report.ps1           # Accounts with passwords expiring within N days
│   ├── Get-LastLogon.ps1                         # Last logon per user queried across all DCs
│   ├── Get-LockedOutLocation.ps1                 # Lockout source from Security event 4740
│   ├── GetUsersLogonLogoffEvents.ps1             # Logon/logoff event audit
│   ├── Get_MFA_Status.ps1                        # MFA registration status via Graph API
│   ├── Manage Active Directory Groups.ps1        # Bulk group membership management
│   ├── Risky Users Report in Microsoft Entra.ps1 # Entra ID Protection risky user report
│   └── Send-PasswordExpiry.ps1                   # Email notifications before password expiry
│
├── ExchangeOnline/
│   ├── Audit PIM role.ps1                        # Privileged Identity Management role audit
│   ├── Get-DistributionGroupMember.ps1           # Distribution list membership export
│   ├── Get-MailboxPermissions.ps1                # Full Access, Send-As, Send on Behalf audit
│   ├── Shared Mailbox Size Report.ps1            # Size, item count, and quota per shared mailbox
│   └── Trace Emails Sent to External Domains.ps1 # Outbound external mail flow audit
│
├── backup/
│   └── ADBackUp.ps1                              # Active Directory state backup
│
└── scripts/
    ├── cleanup/                                  # Disk space reclamation
    ├── inventory/
    │   ├── Audit.ps1                             # Environment audit report
    │   ├── Break Glass Account Report.ps1        # Break glass account access audit
    │   ├── Get-SystemInfo.ps1                    # Windows system info snapshot
    │   └── Send Password Expiry Notifications to M365 Users.ps1
    ├── M365 Sign-in Failure Report.ps1           # Failed sign-in analysis from Entra logs
    └── README.md
```

---

## Prerequisites

**Active Directory scripts** require a domain-joined machine with RSAT installed, or execution directly on a domain controller.

**Exchange Online and Entra ID scripts** require the relevant modules and an authenticated session before running.

```powershell
# Exchange Online
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
Connect-ExchangeOnline

# Microsoft Graph (MFA status, risky users, Entra reports)
Install-Module -Name Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All","IdentityRiskyUser.Read.All","AuditLog.Read.All"
```

> The `ActiveDirectory` module is not available on PSGallery. Install it via RSAT on Windows Server or enable it through Windows Optional Features on a management workstation.

---

## Script Reference

### Environment Health Check

**`ActiveDirectory/Environment Health-Check.ps1`**

The primary operational script. Runs automated checks across the environment and outputs a timestamped HTML report.

| Area | What is checked |
|---|---|
| Active Directory | Replication failures, replication queue depth |
| DNS | SRV record resolution, forwarder health, external resolution |
| Disk | Free space on all fixed drives (configurable threshold) |
| Services | NTDS, DNS, Netlogon, KDC, DFSR, W32Time, WinRM |
| Certificates | Expiry warnings from LocalMachine\My store |
| Shares | SYSVOL and NETLOGON availability |
| DC Connectivity | Ping and LDAP port 389 per domain controller |
| Event Logs | Error and warning counts from System and Application logs (last 24h) |

```powershell
# Default run — HTML report saved to script directory
.\Environment Health-Check.ps1

# Custom thresholds
.\Environment Health-Check.ps1 -DiskThresholdPercent 15 -CertWarningDays 45 -OutputPath "C:\Reports"

# Email report on completion
.\Environment Health-Check.ps1 -SendEmail -SmtpServer "smtp.domain.local" `
    -EmailFrom "healthcheck@domain.local" -EmailTo "it-team@domain.local"
```

---

### Active Directory

| Script | Description | Output |
|---|---|---|
| `Get-ExpiringAccounts_Report` | Accounts with passwords expiring within N days | CSV |
| `Get-LastLogon` | Most recent logon per user, queried across all DCs | CSV |
| `Get-LockedOutLocation` | Source machine from Security event ID 4740 | Console |
| `GetUsersLogonLogoffEvents` | Logon and logoff event audit trail | CSV |
| `Get_MFA_Status` | MFA method registration status per user via Graph | CSV |
| `Manage Active Directory Groups` | Bulk add, remove, or report on group membership | CSV |
| `Risky Users Report in Microsoft Entra` | Entra ID Protection risk level and state per user | CSV |
| `Send-PasswordExpiry` | Email notifications to users before password expires | Email |

See [ActiveDirectory/README.md](ActiveDirectory/README.md) for full parameter reference and usage examples.

---

### Exchange Online

| Script | Description | Output |
|---|---|---|
| `Audit PIM role` | Active and eligible PIM role assignment audit | CSV |
| `Get-DistributionGroupMember` | Membership export for one or all distribution lists | CSV |
| `Get-MailboxPermissions` | Full Access, Send-As, and Send on Behalf per mailbox | CSV |
| `Shared Mailbox Size Report` | Size, item count, and quota status per shared mailbox | CSV |
| `Trace Emails Sent to External Domains` | Outbound external mail flow security audit | Console |

---

### Inventory and Reporting

| Script | Description | Output |
|---|---|---|
| `Break Glass Account Report` | Access and activity audit for break glass accounts | CSV |
| `Get-SystemInfo` | Hardware, OS, network, and role snapshot | Console / CSV |
| `Audit.ps1` | Broad environment audit across key config areas | Console |
| `M365 Sign-in Failure Report` | Failed sign-in analysis pulled from Entra audit logs | CSV |
| `Send Password Expiry Notifications to M365 Users` | M365-native password expiry notification | Email |

---

## Security Notes

- Scripts specify minimum required permissions in their `.NOTES` section
- No hardcoded credentials — scripts use `-Credential` parameters or existing authenticated sessions
- Reporting scripts are read-only by default and do not modify AD or mailbox data
- Graph-based scripts use delegated or application permissions scoped to the minimum required

---

## License

[MIT](LICENSE)
