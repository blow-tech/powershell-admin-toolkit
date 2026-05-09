# PowerShell Admin Toolkit

PowerShell scripts for Windows administration, inventory, backup, cleanup, and maintenance tasks.

## Scripts

### Inventory

| Script | Description | Risk Level |
|---|---|---|
| `scripts/Get-SystemInfo.ps1` | Collects basic Windows system information. | Read-only |
| `scripts/inventory/Audit.ps1` | Generates a Windows audit report. | Read-only / information gathering |

### Backup

| Script | Description | Risk Level |
|---|---|---|
| `backup/ADBackUp.ps1` | Performs Active Directory or Windows Server backup-related tasks. | Administrative change |

### Cleanup

| Script | Description | Risk Level |
|---|---|---|
| `scripts/cleanup/DiskCleanup.ps1` | Cleans temporary files, cache, logs, or old files depending on script configuration. | Deletes files |

## Usage

Clone the repository:

```powershell
git clone https://github.com/blow-tech/powershell-admin-toolkit.git
cd powershell-admin-toolkit
