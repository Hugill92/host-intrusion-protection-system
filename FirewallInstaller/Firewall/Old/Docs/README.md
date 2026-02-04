# Firewall Core – Self-Healing Windows Firewall

## Overview
Firewall Core enforces a cryptographically locked firewall baseline and detects:
- Rule deletion
- Rule modification
- Unauthorized non-baseline rules
- Unexpected SYSTEM changes

It runs as SYSTEM via Scheduled Task.

---

## Folder Structure

C:\Firewall
├── Monitor
│   └── Firewall-Core.ps1
├── Modules
│   └── Firewall-EventLog.ps1
├── Maintenance
│   ├── Start-Maintenance.ps1
│   ├── Stop-Maintenance.ps1
│   └── Uninstall-Firewall.ps1
├── State
│   ├── baseline.json
│   ├── baseline.hash
│   ├── allowlist.json
│   └── maintenance.token (temporary)
├── Golden
│   ├── baseline.golden.json
│   └── baseline.golden.hash
└── Logs

---

## Scheduled Task
Name: Firewall Core Monitor  
Runs as: SYSTEM  
Triggers:
- Startup
- Every 5 minutes

---

## Event IDs

| ID | Meaning |
|----|-------|
3001 | Baseline rule restored |
3003 | Non-baseline rule corrected |
3200 | Drift detected |
3201 | Interactive admin change (no enforcement) |
3210 | Maintenance window active |
3300 | Baseline integrity violation |
4001 | **Unexpected SYSTEM firewall change** |

---

## Maintenance Mode
Use ONLY during expected firewall changes.

```powershell
Start-Maintenance.ps1 -Minutes 30
