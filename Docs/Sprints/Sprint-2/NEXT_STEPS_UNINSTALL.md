# Sprint 2 - Next Steps to Finalize Uninstall

## Goal
Deliver a clean, deterministic uninstall that:
- Never targets repo/installer paths
- Stops and removes installer-owned background components
- Removes installer-owned artifacts (tasks/keys/files) safely and idempotently
- Produces clean logs (actionable + reproducible)

---

## Current Reality
- Some evidence can show "success" while uninstall still hangs/fails due to blocking deletes or lingering processes/tasks.
- To finalize Sprint 2, uninstall must be verified via a strict checklist (not just a single log line).

---

## Required Fixes (W3/W4 Completion)

### 1) Safety gates (non-negotiable)
- Uninstall must refuse if the resolved target root is under `C:\FirewallInstaller\...`.
- Default target root must be LIVE (`C:\Firewall`) unless an explicit override is provided.
- Clean uninstall must require an explicit confirmation (e.g., typed UNINSTALL) when launched from any UI.

### 2) Stop background components before deletion
Order of operations (deterministic):
1. Stop/disable scheduled tasks the installer owns (Toast Listener, Watchdog, Defender integration if applicable).
2. Kill only installer-owned PowerShell processes (command line contains `FirewallToastListener` / known runner paths).
3. Remove protocol handler registry keys (HKLM/HKCU as applicable).
4. Remove installer-owned ProgramData artifacts.
5. Remove installer-owned `C:\Firewall\...` files.

### 3) Idempotency
Uninstall must be safe to rerun:
- Missing tasks/keys/files are logged as WARN/INFO, not fatal.
- Remove operations use `-ErrorAction SilentlyContinue` or explicit try/catch with log output.

### 4) Logging (Sprint 2 hard requirement)
Logs must contain:
- Start/end markers
- Step markers (each major operation)
- Explicit OK/WARN/FAIL lines per step
- When failing: exact path/task/key that caused it

---

## Event Viewer Log Checks - Optional (Pros/Cons)

### Pros
- Quick confirmation that Event Log integration is present (helps validate install).
- Useful for diagnosing install/uninstall drift (especially on VMs).
- Non-invasive check if done as read-only.

### Cons
- Admin-only for reliable queries in some environments.
- Can add noise or false negatives if Event Viewer services are slow or restricted.
- Not required to validate uninstall correctness (uninstall should be verifiable via tasks/keys/files/processes).

### Recommendation
- Keep Event Viewer check OPTIONAL and gated by admin.
- Never block uninstall completion based on Event Viewer check.

---

## Final Approval Checklist (Sprint 2 Definition of Done)

### Loop A - Install
- Install completes with deterministic logs.
- Tasks created with single-string Arguments and hidden execution.
- Targeted LIVE paths are used (no `C:\FirewallInstaller\...` in scheduled task actions).

### Loop B - Uninstall
- Uninstall completes without hanging.
- Uninstall removes:
  - installer-owned scheduled tasks
  - protocol handler keys
  - ProgramData artifacts (owned)
  - `C:\Firewall` artifacts (owned)
- No lingering toast listener/runner PowerShell processes after completion.

### Loop C - Reinstall
- Reinstall works immediately after uninstall.
- No manual cleanup steps required.

### Evidence to capture
- Uninstall log + debug log from a run that completed
- `Get-ScheduledTask` outputs (before/after)
- `Get-CimInstance Win32_Process` filtered to powershell.exe (before/after)
- `Test-Path` for `C:\Firewall` and `C:\ProgramData\FirewallCore` (before/after)

---

## UX that feels good (Operator workflow)
- Non-admin can open the maintenance UI and see status.
- Destructive actions are disabled unless elevated.
- Provide a clear "Relaunch as Administrator" path.
- Clean uninstall requires typed confirmation.
- Actions run hidden and write deterministic logs.
