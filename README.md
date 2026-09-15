# powershell-admin-toolkit

Production automation scripts for Windows Server and Microsoft 365 environments — built to solve recurring operational problems across Active Directory, Exchange Online, and infrastructure health monitoring.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat&logo=powershell&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

> These scripts are sanitized, generalized versions of tools used in live production environments. All environment-specific values (domain names, server names, mailboxes, paths) are replaced with placeholders — review and adapt before running against your own environment.

---

## 📋 What's Included

| Script | Purpose |
|---|---|
| `AD-LifecycleReport.ps1` | Generates a report of AD account lifecycle events (creations, disables, stale accounts) |
| `ExchangeOnline-AuditReport.ps1` | Audits Exchange Online mailbox permissions, forwarding rules, and mail flow anomalies |
| `Environment-HealthCheck.ps1` | Single-pass health check across AD replication, DNS, certificate expiry, disk space, and critical services — output as one consolidated HTML report |
| `Disk-AutoReclaim.ps1` | Automated cleanup of temp files, logs, and reclaimable disk space with configurable thresholds |
| `PasswordExpiry-Notify.ps1` | Sends password expiry warnings to users ahead of the policy deadline |
| `PIM-RoleAudit.ps1` | Audits active/eligible Privileged Identity Management role assignments in Entra ID |

*(Update table with your actual script names/filenames.)*

---

## ⚙️ Requirements

- PowerShell 5.1 or later (7.x compatible where noted)
- RSAT / ActiveDirectory module (for AD scripts)
- ExchangeOnlineManagement module (for Exchange scripts)
- Microsoft Graph PowerShell SDK (for PIM/Entra scripts)
- Appropriate delegated permissions — see each script header for the minimum required role

---

## 🚀 Usage

```powershell
# Example: run the environment health check
.\Environment-HealthCheck.ps1 -DomainController <DCName> -OutputPath C:\Reports\health.html
```

Each script includes:
- A comment-based help header (`Get-Help .\Script.ps1 -Full`)
- Required parameters and permissions documented inline
- No hardcoded credentials — scripts prompt or use existing authenticated sessions

---

## 🖼️ Sample Output

*(Add a screenshot here of the HTML health report or a sample console/report output — this is the single highest-impact addition. A sanitized screenshot showing the report structure demonstrates real functionality far better than a description.)*

```
![Sample health report](./docs/sample-health-report.png)
```

---

## ⚠️ Disclaimer

These scripts are provided as-is for reference and adaptation. Test in a non-production environment before running against production Active Directory, Exchange Online, or Entra ID tenants. No warranty is expressed or implied.

## 📄 License

MIT — see [LICENSE](./LICENSE)
