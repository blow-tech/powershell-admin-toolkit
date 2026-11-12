# Retired unsupported location inference. Original report: blow_tech (2016).
# Server-name prefixes are not authoritative evidence of tenant data residency.
[CmdletBinding()]
param()
throw 'This legacy Basic-auth/datacenter-prefix report is retired. Verify data residency in the Microsoft 365 admin center and contractual service documentation. GetMailboxes.ps1 provides mailbox inventory only; it does not establish physical datacenter location.'
