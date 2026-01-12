# Sprint 3 - Regression Guide (Lifecycle + Notifications)

- Created: 2026-01-12 14:03:02

## Goal
- Validate the product behaves the same across clean machines and repeated runs.

## Core loops
### Loop A - Install
- Run `Install.cmd`
- Verify tasks, protocol handler, event log, live files, and no visible consoles.

### Loop B - Uninstall
- Run `Uninstall.cmd`
- Verify tasks/keys/files removed, no running listener processes, and idempotency.

### Loop C - Reinstall
- Run Install again
- Confirm determinism (no drift, no duplicate tasks, no repo-path dependencies).

## Required checks (copy/paste snippets)
### Tasks and actions
- `(Get-ScheduledTask -TaskName "Firewall-Defender-Integration").Actions | Format-List *`
- `(Get-ScheduledTask -TaskName "FirewallCore Toast Listener").Actions | Format-List *`
- `(Get-ScheduledTask -TaskName "FirewallCore Toast Watchdog").Actions | Format-List *`

### Running processes
- `Get-CimInstance Win32_Process | ? Name -eq "powershell.exe" | select ProcessId,CommandLine`

### Protocol handler
- `Test-Path "HKLM:\Software\Classes\firewallcore-review"`
- `Test-Path "HKCU:\Software\Classes\firewallcore-review"`

### Event log
- `Get-WinEvent -ListLog "FirewallCore"`

## Evidence requirements
- Logs: install/uninstall (paths recorded)
- Task action dumps (above)
- Process command line snapshot (above)
- Pass/fail summary per loop

