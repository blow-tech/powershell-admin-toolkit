# linux-admin-scripts

Bash tooling for RHEL/CentOS server operations, health monitoring, and auditing — built from real production maintenance workflows.

![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)
![RHEL](https://img.shields.io/badge/RHEL%20%2F%20CentOS-EE0000?style=flat&logo=redhat&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

> Sanitized, generalized versions of scripts used in live production environments. Environment-specific values (hostnames, paths, thresholds) are replaced with placeholders — review before running.

---

## 📋 What's Included

| Script | Purpose |
|---|---|
| `healthcheck.sh` | System health check with configurable thresholds (CPU, memory, disk, load) and alerting |
| `log-parser.sh` | Parses rotated and compressed logs (`.gz`) for pattern matching and summary reporting |
| `service-monitor.sh` | Monitors systemd services and restarts them on failure with logging |
| `backup-validate.sh` | Validates backup completion and integrity against expected schedules |
| `cron-maintenance.sh` | Scheduled cleanup and maintenance tasks structured for cron, with consistent log output |

*(Update table with your actual script names/filenames.)*

---

## ⚙️ Requirements

- Bash 4+
- RHEL / CentOS (tested on: *add version, e.g. RHEL 8.x / 9.x*)
- Standard GNU coreutils; any additional dependencies noted per-script header
- `sudo`/root access required for service-monitor and cron-maintenance scripts

---

## 🚀 Usage

```bash
# Example: run a health check with default thresholds
./healthcheck.sh --cpu-threshold 85 --disk-threshold 90

# Example: schedule via cron (daily at 2am)
0 2 * * * /opt/scripts/cron-maintenance.sh >> /var/log/cron-maintenance.log 2>&1
```

Each script includes:
- A usage header (`./script.sh --help`)
- Exit codes documented for monitoring integration
- Logging to a configurable path for auditability

---

## 🖼️ Sample Output

*(Add a screenshot or terminal output sample here — showing a real health-check run or log summary demonstrates functionality more convincingly than a feature list.)*

```
![Sample health check output](./docs/sample-output.png)
```

---

## ⚠️ Disclaimer

Provided as-is for reference and adaptation. Test in a non-production environment first. No warranty is expressed or implied.

## 📄 License

MIT — see [LICENSE](./LICENSE)
