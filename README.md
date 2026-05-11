# 🛠️ PowerShell Admin Toolkit

> A production-ready collection of PowerShell scripts for Windows Server, Active Directory, Exchange Online, and Microsoft 365 administration.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows%20Server%202016%2B-lightgrey?logo=windows)
![M365](https://img.shields.io/badge/Microsoft%20365-Exchange%20%7C%20Intune-0078D4?logo=microsoft)
![License](https://img.shields.io/badge/License-MIT-green)
![Last Commit](https://img.shields.io/github/last-commit/blow-tech/powershell-admin-toolkit)

---

## 📋 Overview

This toolkit automates repetitive admin tasks, enforces consistency across environments, and provides fast reporting across:

- **Active Directory** — account lifecycle, auditing, expiry management
- **Exchange Online** — mailbox reporting, permissions, mail flow tracing
- **Environment Health** — AD replication, DNS, disk, certs, services in one report
- **Backup** — AD state backup automation
- **Inventory & Cleanup** — system info collection, disk hygiene

All scripts follow a consistent structure: full comment-based help, parameter validation, error handling, and console + log output.

---

## 📁 Repository Structure

```
powershell-admin-toolkit/
├── ActiveDirectory/
│   ├── Get-ExpiringAccounts_Report.ps1     # Find accounts with expiring passwords
│   ├── Get-LastLogon.ps1                   # Last logon report across all DCs
│   ├── Get-LockedOutLocation.ps1           # Trace lockout source from Security logs
│   ├── GetUsersLogonLogoffEvents.ps1       # Logon/logoff event audit
│   └── Send-PasswordExpiry.ps1             # Email users before password expires
│
├── ExchangeOnline/
│   ├── Get-DistributionGroupMember.ps1     # Export DL membership
│   ├── Get-MailboxPermissions.ps1          # Full/Send-As/Send-on-Behalf audit
│   ├── Shared Mailbox Size Report.ps1      # Size + quota report for shared mailboxes
│   └── Trace Emails Sent to External Domains.ps1  # Mail flow security audit
│
├── backup/
│   └── ADBackUp.ps1                        # Active Directory state backup
│
└── scripts/
    ├── cleanup/
    │   └── DiskCleanup.ps1                 # Automated disk space reclamation
    ├── inventory/
    │   ├── Audit.ps1                       # Environment audit report
    │   └── Get-SystemInfo.ps1              # Full Windows system info snapshot
    └── Get-EnvironmentHealthCheck.ps1      # ⭐ Full environment health check + HTML report
```

---

## ⚡ Quick Start

### Prerequisites

```powershell
# Required modules — install once
Install-Module -Name ActiveDirectory          -Scope CurrentUser   # Built-in on DC/RSAT
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
Install-Module -Name Microsoft.Graph          -Scope CurrentUser   # For Graph-based scripts
```

> **Note:** Scripts that touch AD must be run on a Domain Controller or a machine with RSAT installed. Exchange Online scripts require an active `Connect-ExchangeOnline` session.

### Clone & Run

```powershell
git clone https://github.com/blow-tech/powershell-admin-toolkit.git
cd powershell-admin-toolkit

# Example: Run the environment health check
.\scripts\Get-EnvironmentHealthCheck.ps1 -OutputPath "C:\Reports"
```

---

## 🔍 Script Reference

### 🏥 Get-EnvironmentHealthCheck.ps1
**The flagship script.** Runs automated checks across your entire environment and outputs a timestamped HTML dashboard report.

**Checks performed:**
| Area | What's checked |
|---|---|
| Active Directory | Replication failures, replication queue |
| DNS | SRV record resolution, forwarder health, external DNS |
| Disk | Free space on all fixed drives (configurable threshold) |
| Services | Critical services: NTDS, DNS, Netlogon, KDC, DFSR, W32Time, WinRM |
| Certificates | Expiry warnings from LocalMachine\My store |
| Shares | SYSVOL and NETLOGON availability |
| DC Connectivity | Ping + LDAP port 389 per domain controller |
| Event Logs | Error/warning counts from System + Application (last 24h) |

```powershell
# Basic run — saves HTML report to script directory
.\Get-EnvironmentHealthCheck.ps1

# Custom thresholds
.\Get-EnvironmentHealthCheck.ps1 -DiskThresholdPercent 15 -CertWarningDays 45 -OutputPath "C:\Reports"

# Email report on completion
.\Get-EnvironmentHealthCheck.ps1 -SendEmail -SmtpServer "smtp.domain.local" `
    -EmailFrom "healthcheck@domain.local" -EmailTo "it-team@domain.local"
```

---

### 👤 ActiveDirectory Scripts

| Script | Description | Key Output |
|---|---|---|
| `Get-ExpiringAccounts_Report` | Finds accounts with passwords expiring within N days | CSV / console |
| `Get-LastLogon` | Queries all DCs and returns the most recent logon per user | CSV |
| `Get-LockedOutLocation` | Reads Security event 4740 to find lockout source | Console |
| `GetUsersLogonLogoffEvents` | Pulls logon/logoff events for audit trail | Console / CSV |
| `Send-PasswordExpiry` | Emails users a warning before their password expires | Email |

---

### 📧 Exchange Online Scripts

| Script | Description | Key Output |
|---|---|---|
| `Get-DistributionGroupMember` | Exports all members of a DL or all DLs | CSV |
| `Get-MailboxPermissions` | Audits Full Access, Send-As, Send on Behalf | CSV |
| `Shared Mailbox Size Report` | Reports size, item count, and quota usage | CSV / Console |
| `Trace Emails Sent to External Domains` | Security audit of outbound external mail flow | Console |

---

## 🔒 Security & Best Practices

- **Least Privilege** — Scripts specify the minimum required permissions in their `.NOTES` section
- **No hardcoded credentials** — All scripts use `-Credential` parameters or existing authenticated sessions
- **Read-only by default** — Reporting scripts never modify data unless you use an explicit `-WhatIf`-supporting action parameter
- **Transcript logging** — Where applicable, scripts support `-LogPath` for audit trails

---

## 🗺️ Roadmap

- [ ] `Security/Get-AdminAccounts.ps1` — Privileged account audit
- [ ] `Security/Audit-LocalAdmins.ps1` — Local admin enumeration across servers
- [ ] `Intune/Get-ManagedDevices.ps1` — Device compliance report via Graph API
- [ ] `Certificates/Get-ExpiringCerts.ps1` — Enterprise CA certificate expiry sweep
- [ ] `Reporting/` — HTML report wrappers for existing scripts

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first.

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/script-name`
3. Follow the existing comment-based help header format
4. Submit a PR with a clear description of what the script does and what permissions it requires

---

## 📄 License

[MIT](LICENSE) — free to use, modify, and distribute with attribution.

---

<div align="center">
  <sub>Built for sysadmins, by a sysadmin &nbsp;·&nbsp; <a href="https://github.com/blow-tech">blow-tech</a></sub>
</div>
