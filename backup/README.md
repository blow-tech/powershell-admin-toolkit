# backup

Scripts for backing up critical Windows Server and Active Directory state.

---

## Scripts

### `ADBackUp.ps1`
Automates Active Directory backup using `wbadmin` to perform a system state backup. Captures AD DS, SYSVOL, registry, and boot files. Designed to run as a scheduled task on a domain controller.

Writes a timestamped log entry on each run. Alerts to the console if the backup job fails or if the last successful backup exceeds a configurable age threshold.

**Parameters:**
| Parameter | Required | Description |
|---|---|---|
| `-BackupTarget` | Yes | Drive letter or UNC path for the backup destination |
| `-LogPath` | No | Path for log file output. Default: `C:\Logs\ADBackup.log` |
| `-AlertAgeDays` | No | Warn if last successful backup is older than N days. Default: `2` |

```powershell
# Backup to a dedicated backup drive
.\ADBackUp.ps1 -BackupTarget "E:" -LogPath "C:\Logs\ADBackup.log"

# Backup to a network share
.\ADBackUp.ps1 -BackupTarget "\\backupserver\ADBackups" -AlertAgeDays 1
```

**Scheduled task setup:**

```powershell
$action  = New-ScheduledTaskAction -Execute "PowerShell.exe" `
               -Argument "-NonInteractive -File C:\Scripts\backup\ADBackUp.ps1 -BackupTarget E:"
$trigger = New-ScheduledTaskTrigger -Daily -At 02:00
Register-ScheduledTask -TaskName "AD System State Backup" -Action $action -Trigger $trigger `
    -RunLevel Highest -User "SYSTEM"
```

---

## Requirements

- Must run on a domain controller
- Requires local Administrator or Backup Operators group membership
- `wbadmin` must be available (included with Windows Server Backup feature)

```powershell
# Install Windows Server Backup feature if not present
Install-WindowsFeature -Name Windows-Server-Backup
```

---

## Notes

- System state backups capture AD DS database, SYSVOL, registry, COM+ class registration database, and boot files
- Backups to UNC paths require the scheduled task to run under an account with write access to the share — SYSTEM account does not have network access by default
- Test restore procedures periodically — a backup that has never been tested is not a backup

---

*Part of [powershell-admin-toolkit](https://github.com/blow-tech/powershell-admin-toolkit)*
