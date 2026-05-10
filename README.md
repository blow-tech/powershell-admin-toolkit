# 🛠️ PowerShell Admin Toolkit

> A collection of production-ready PowerShell scripts for Windows Server administration, Active Directory management, Exchange Online operations, and IT automation.

---

## 📋 Table of Contents

- [Requirements](#requirements)
- [Scripts Overview](#scripts-overview)
  - [Active Directory](#-active-directory)
  - [Exchange Online](#-exchange-online)
- [Usage](#usage)
- [Changelog & Known Issues](#changelog--known-issues)
- [Contributing](#contributing)
- [Author](#author)

---

## ⚙️ Requirements

| Requirement | Details |
|---|---|
| PowerShell | 5.1+ (7.x recommended) |
| AD Module | `RSAT: Active Directory DS and LDS Tools` |
| Exchange Online | `ExchangeOnlineManagement` v3+ (`Install-Module ExchangeOnlineManagement`) |
| Permissions | Domain Admin or delegated AD rights depending on script |
| WinRM | Enabled on targets for remote scripts (`Get-AD-Computer-Servers-Local-Administrator-Members.ps1`) |

---

## 📁 Scripts Overview

### 🗂 Active Directory

---

#### `CreateADUsersAndGroupsFromCSV.ps1`
**Bulk-creates AD User and/or Group accounts from a CSV input file. Supports assigning members to groups.**

**Usage — Create Users:**
```powershell
# CSV Headers: sAMAccountName, FirstName, LastName, DisplayName, Description, Password
Create-ADAccountsFromCSV -CSVPath "C:\Scripts\UserAccounts.csv" `
                         -OrgUnit "OU=Staff,DC=acme,DC=local" `
                         -Type "User"
```

**Usage — Create Groups with Members:**
```powershell
# CSV Headers: sAMAccountName, Member1, Member2, Member3 ...
Create-ADAccountsFromCSV -CSVPath "C:\Scripts\GroupAccounts.csv" `
                         -OrgUnit "OU=Groups,DC=acme,DC=local" `
                         -Type "Group"
```

> **Note:** Users are created as **Disabled** with `ChangePasswordAtLogon` set to `$true`. Enable accounts manually or add `-Enabled $true` to `New-ADUser` if needed.

---

#### `GetADGroupMembers.ps1`
**Exports all AD Security Groups and their members from a specified OU to CSV.**

**Edit these variables before running:**
```powershell
$distinguishedName = "OU=Groups,OU=YourOU,DC=YourDomain,DC=com"
$displayName       = "*"         # Wildcard filter on group name
$filePath          = "C:\Reports\ADSecurityGroups.csv"
```

**Run:**
```powershell
.\GetADGroupMembers.ps1
```

---

#### `GetADAccountLockedOutLocation.ps1`
**Queries all Domain Controllers and the PDC Emulator (Event ID 4740) to identify where an account lockout originated.**

**Usage:**
```powershell
Import-Module .\GetADAccountLockedOutLocation.ps1
Get-LockedOutLocation -Identity "jdoe"
```

> **Requires:** PDC Emulator running Windows Server 2008 SP2 or later. AD Web Services must be available.

---

#### `GetADExpiringUserAccountsReport.ps1`
**Reports on user accounts expiring within N days and emails an HTML report to administrators.**

**Usage:**
```powershell
.\GetADExpiringUserAccountsReport.ps1 `
    -Days 7 `
    -SearchBase "OU=Staff,DC=contoso,DC=com" `
    -EmailFrom "noreply@contoso.com" `
    -EmailTo "it-admin@contoso.com" `
    -EmailSMTPServer "smtp.contoso.com"
```

---

#### `GetUsersLastLogonDateTime.ps1`
**Returns the last logon date and time for all AD user accounts.**

> ⚠️ Uses `DirectorySearcher` which reads the **non-replicated** `lastLogon` attribute (per-DC only).
> For accurate results across all DCs, prefer:
> ```powershell
> Get-ADUser -Filter * -Properties LastLogonDate | Select Name, LastLogonDate
> ```

**Run:**
```powershell
.\GetUsersLastLogonDateTime.ps1
```

---

#### `GetUsersLogonLogoffEvents.ps1`
**Queries Security Event Log on computers in a specified OU for Logon (4648) and Logoff (4647) events.**

**Edit before running:**
```powershell
$Computers = (Get-ADComputer -SearchBase 'OU=My Desktops,DC=lab,DC=local' -Filter *)
```

**Run:**
```powershell
.\GetUsersLogonLogoffEvents.ps1
```

> **Requires:** WinRM enabled on target machines. Run as an account with remote event log access.

---

#### `Get-AD-Computer-Servers-Local-Administrator-Members.ps1`
**Inventories the local Administrators group on all active Windows Server machines in the domain. Exports to CSV.**

Output path (edit as needed): `D:\temp\Local_Admins_Report.csv`

Filters servers active within the **last 8 days** by `LastLogonDate`.

**Run:**
```powershell
.\Get-AD-Computer-Servers-Local-Administrator-Members.ps1
```

> **Requires:** PowerShell Remoting (`Invoke-Command`) enabled on all target servers.

---

#### `UserPasswordExpiryNotificationEmails.ps1`
**Sends automated password expiry reminder emails to users at 14, 7, 3, and 1 days before expiry. Sends a summary report to the Helpdesk team.**

**Edit the `CONFIG:` sections in the script:**
```powershell
$emailFrom  = "helpdesk@domain.com"
$emailTo    = "$samname@domain.com"
$smtpServer = "email.domain.com"
```

**Recommended:** Schedule this via Windows Task Scheduler to run daily.

```powershell
.\UserPasswordExpiryNotificationEmails.ps1
```

---

### 📧 Exchange Online

> ⚠️ **Deprecation Notice:** Scripts using legacy Basic Auth remote PowerShell sessions (`New-PSSession -ConfigurationName Microsoft.Exchange`) will stop working as Microsoft has disabled Basic Auth in Exchange Online.
>
> **Migrate to:** `Connect-ExchangeOnline` from the `ExchangeOnlineManagement` v3 module:
> ```powershell
> Install-Module ExchangeOnlineManagement
> Connect-ExchangeOnline -UserPrincipalName admin@tenant.onmicrosoft.com
> ```

---

#### `ExchangeOnlineGetDistributionGroupMembers.ps1`
**Exports all Distribution Groups and their members across the Exchange Online tenant to a CSV file.**

Output: `DistributionGroupMembers.csv` (current directory)

**Run:**
```powershell
.\ExchangeOnlineGetDistributionGroupMembers.ps1 `
    -Office365Username "admin@tenant.onmicrosoft.com" `
    -Office365Password "YourPassword"
```

> 🔄 **Planned update:** Migrate to `Connect-ExchangeOnline` + `Get-DistributionGroup`.

---

#### `ExchangeOnlineGetMailBoxPermissions.ps1`
**Lists all mailboxes where other users have Full Access or Send As permissions.**

> ⚠️ Requires `$LiveCred` to be defined before running, or replace with `Get-Credential`:
> ```powershell
> $LiveCred = Get-Credential
> ```

**Run:**
```powershell
.\ExchangeOnlineGetMailBoxPermissions.ps1
```

---

## 📝 Changelog & Known Issues

| Script | Issue | Status |
|---|---|---|
| `ExchangeOnlineGetDistributionGroupMembers.ps1` | Legacy Basic Auth deprecated by Microsoft | 🔄 Update planned |
| `ExchangeOnlineGetMailBoxPermissions.ps1` | `$LiveCred` undefined — script will fail without pre-defining credential | ⚠️ Fix needed |
| `GetUsersLastLogonDateTime.ps1` | `lastLogon` is per-DC and not replicated — results may be inaccurate | ⚠️ Consider migration to `LastLogonDate` |
| `UserPasswordExpiryNotificationEmails.ps1` | Subject line typo: "expried" | 🐛 Minor |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/improve-lockout-script`
3. Follow the existing comment-based help style (`<# .SYNOPSIS ... #>`)
4. Test on a lab environment before submitting a PR
5. Open a Pull Request with a description of changes

---

## 👤 Author

**blow-tech**
- GitHub: [@blow-tech](https://github.com/blow-tech)
- Focus: Windows Server · Active Directory · PowerShell Automation · Linux Admin

---

> ⚡ Scripts are provided as-is for educational and operational use. Always test in a lab environment before running in production.
