# PowerShell Admin Toolkit

PowerShell scripts for Windows system administration, inventory, and read-only health checks.

## Scripts

### Get-SystemInfo.ps1

Collects basic system information from a Windows machine.

Checks include:

- Computer name
- Windows version
- OS architecture
- Hardware manufacturer and model
- CPU details
- Total memory
- Disk size and free space
- Network configuration

## Usage

Clone the repository:

```powershell
git clone https://github.com/blow-tech/powershell-admin-toolkit.git
cd powershell-admin-toolkit
```

Run the script:

```powershell
.\scripts\Get-SystemInfo.ps1
```

## Safety

This script is read-only.

It does not modify:

- Users or groups
- Services
- Registry keys
- Firewall rules
- Network settings
- System configuration

## Requirements

- Windows 10/11 or Windows Server
- PowerShell 5.1 or newer

## Planned Scripts

- Disk space report
- Local user inventory
- Windows service status check
- Event log error summary
- Basic server health check

- PowerShell scripts for Windows administration, inventory, backup, and maintenance tasks.
