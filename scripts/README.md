# scripts

General-purpose administration scripts covering inventory collection, system reporting, disk cleanup, and Microsoft 365 notifications. Organised into subfolders by function.

---

## Structure

```
scripts/
├── cleanup/
│   └── DiskCleanup.ps1
├── inventory/
│   ├── Audit.ps1
│   ├── Break Glass Account Report.ps1
│   └── Get-SystemInfo.ps1
├── M365 Sign-in Failure Report.ps1
└── Send Password Expiry Notifications to M365 Users.ps1
```

---

## cleanup/

### `DiskCleanup.ps1`
Automates disk space reclamation on Windows Server. Targets common high-volume locations: Windows temp files, user temp directories, IIS logs, CBS logs, and Windows Update cache. Reports space reclaimed per location and total freed.

Designed for scheduled execution. Does not touch application data or user profile documents.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-LogPath` | No | Path for log output. Default: `C:\Logs\DiskCleanup.log` |
| `-WhatIf` | No | Reports what would be deleted without removing anything |

```powershell
# Preview what would be removed
.\DiskCleanup.ps1 -WhatIf

# Run and log output
.\DiskCleanup.ps1 -LogPath "C:\Logs\DiskCleanup.log"
```

---

## inventory/

### `Audit.ps1`
Runs a broad environment audit across key configuration areas. Covers local administrators, installed software, running services, scheduled tasks, and open firewall rules. Intended as a baseline capture or periodic compliance check.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-OutputPath` | No | Path for report output. Default: current directory |
| `-ComputerName` | No | Remote target. Default: local machine |

```powershell
.\Audit.ps1 -OutputPath "C:\Reports\Audit"

# Remote execution
.\Audit.ps1 -ComputerName SERVER01 -OutputPath "C:\Reports\SERVER01_Audit"
```

---

### `Break Glass Account Report.ps1`
Audits break glass (emergency access) accounts in Microsoft Entra ID. Reports last sign-in date, MFA status, assigned roles, and whether the account has been accessed recently. Flags accounts that show unexpected recent activity.

**Requirements:** `Microsoft.Graph` module, `AuditLog.Read.All`, `Directory.Read.All`  
**Output:** CSV report

```powershell
.\Break Glass Account Report.ps1 -OutputPath "C:\Reports\BreakGlass.csv"
```

---

### `Get-SystemInfo.ps1`
Collects a comprehensive system snapshot from a local or remote Windows machine. Covers OS version, hardware, installed roles and features, network adapters and IP configuration, DNS settings, pending reboots, and key service states.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-ComputerName` | No | Remote target. Default: local machine |
| `-OutputPath` | No | Path for export. Default: console output only |

```powershell
# Local machine
.\Get-SystemInfo.ps1

# Remote with export
.\Get-SystemInfo.ps1 -ComputerName DC01 -OutputPath "C:\Reports\DC01_SystemInfo.csv"
```

---

## Root-level scripts

### `M365 Sign-in Failure Report.ps1`
Pulls failed sign-in events from Microsoft Entra audit logs via Graph API. Reports user, failure reason, IP address, location, and timestamp. Useful for detecting brute force attempts, password spray activity, and accounts with persistent authentication issues.

**Requirements:** `Microsoft.Graph` module, `AuditLog.Read.All`  
**Output:** CSV report

```powershell
.\M365 Sign-in Failure Report.ps1 -OutputPath "C:\Reports\SignInFailures.csv"

# Scope to a specific user
.\M365 Sign-in Failure Report.ps1 -UserPrincipalName "j.smith@domain.com" -OutputPath "C:\Reports\jsmith_failures.csv"
```

---

### `Send Password Expiry Notifications to M365 Users.ps1`
Sends password expiry warning emails to Microsoft 365 users whose passwords are approaching expiry. Queries Entra ID for password expiry data and dispatches notifications via Microsoft Graph Mail API — no SMTP relay required.

**Requirements:** `Microsoft.Graph` module, `Mail.Send`, `User.Read.All`

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-DaysWarning` | No | Notify users expiring within N days. Default: `14` |
| `-FromAddress` | Yes | Sender UPN — must have Mail.Send permission |

```powershell
.\Send Password Expiry Notifications to M365 Users.ps1 -DaysWarning 7 -FromAddress "noreply@domain.com"
```

---

## Requirements

- PowerShell 5.1 or later
- Microsoft Graph module for Entra ID and M365 scripts

```powershell
Install-Module -Name Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes "AuditLog.Read.All","Directory.Read.All","Mail.Send","User.Read.All"
```

- Remote execution scripts require WinRM enabled on the target machine

---

*Part of [powershell-admin-toolkit](https://github.com/blow-tech/powershell-admin-toolkit)*
