# PowerShell Admin Toolkit

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue)]()
[![Platform](https://img.shields.io/badge/Platform-Windows%20Server-lightgrey)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()
[![Status](https://img.shields.io/badge/Status-Active-success)]()

A production-focused PowerShell toolkit for Windows Server, Active Directory, Exchange Online, Microsoft 365, and infrastructure administration.

This repository provides reusable operational scripts for reporting, auditing, troubleshooting, and routine administrative tasks across Microsoft environments.

> Built for system administrators and infrastructure engineers who need practical, reviewable, and production-safe automation.

---

## Contents

- [Features](#features)
- [Repository Structure](#repository-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Script Inventory](#script-inventory)
- [Usage Examples](#usage-examples)
- [Safety Classification](#safety-classification)
- [Operational Standards](#operational-standards)
- [Contributing](#contributing)
- [Disclaimer](#disclaimer)

---

## Features

- Active Directory reporting and troubleshooting
- Account lockout investigation
- User logon and logoff event auditing
- Password expiry notification workflows
- Exchange Online administration scripts
- Structured script organization by technology area
- Production-oriented usage guidance

---

## Repository Structure

```text
powershell-admin-toolkit/
├── ActiveDirectory/
│   ├── Get-ExpiringAccounts_Report
│   ├── Get-LastLogon
│   ├── Get-LockedOutLocation.ps1
│   ├── GetUsersLogonLogoffEvents
│   └── Send-PasswordExpiry
├── ExchangeOnline/
├── backup/
├── scripts/
├── .gitignore
├── LICENSE
└── README.md
