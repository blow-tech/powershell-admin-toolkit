# Backup scripts

`ADBackUp.ps1 -BackupTarget '<DriveLetter>:' -WhatIf` previews a system-state backup. Windows Server Backup must already be installed. Actual execution waits for wbadmin, checks its exit code, and retrieves the catalog. Only drive-letter destinations are currently supported; previous LogPath/AlertAgeDays examples were unimplemented and are removed.

Dot-source `Certificate_Authority.ps1` to load `Backup-CertificationAuthority`. Supply an existing protected `-Path`. Each run creates a new version, retaining prior backups and CA logs. `-BackupKey` requires a SecureString `-Password`; use `Read-Host -AsSecureString`, not plaintext command-line input. `-WhatIf` performs prerequisite checks without creating a backup.

Both actions require an elevated authorized backup identity and can impose significant I/O. Plan capacity, protect private keys, record the resulting version and validate restoration in a disposable lab. Artifact hashes and a successful backup command do not establish recoverability. See [migration and validation notes](../REMEDIATION-2026-09.md).
