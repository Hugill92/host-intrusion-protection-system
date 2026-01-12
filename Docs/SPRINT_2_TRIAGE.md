# Sprint 2 Triage - Installer / Uninstaller Hardening

## Scope
**In scope**
- Installer reliability and idempotency
- Uninstaller completeness and safety
- Execution hardening (no visible console windows from background components)
- Logging and diagnostics improvements (install/uninstall only)

**Out of scope (for now)**
- Repair hashing contract and implementation
- New features or rule changes
- Event Viewer view staging (already completed in a prior sprint)

---

## Current Symptoms (Observed)

### S1 - Ghost console windows (post-install)
**Observed**
- Console windows flash/open/close after install.

**Evidence**
- Running processes show:
  - `C:\Firewall\User\FirewallToastListener-Runner.ps1`
  - `C:\Firewall\User\FirewallToastListener.ps1`

**Impact**
- Cosmetic/noise; disrupts deterministic testing.

**Target**
- Ensure background components run hidden and do not spawn visible consoles.

---

## Owned Artifact Inventory (Install/Uninstall Symmetry)

### Scheduled Tasks (owned)
- `Firewall-Defender-Integration`
- `FirewallCore Toast Listener` (including legacy names)
- `FirewallCore Toast Watchdog` (including legacy names)
- `FirewallCore User Notifier` (if applicable)

### Registry (owned)
- Protocol handler keys:
  - `HKLM:\Software\Classes\firewallcore-review`
  - `HKCU:\Software\Classes\firewallcore-review` (if used)

### Files/Directories (owned)
- Installer deployed files under `C:\Firewall\...`
- ProgramData artifacts under `C:\ProgramData\FirewallCore\...`
- Installer-owned logs under `C:\ProgramData\FirewallCore\Logs\...`

> Uninstall must remove only installer-owned artifacts.

---

## Canonical Validation Loop

### Loop A - Clean install + verify
1) Run: `Install.cmd`
2) Verify:
   - tasks exist and are correct
   - no visible consoles
   - required live files exist
3) Capture evidence:
   - install log(s)
   - task action details
   - running `powershell.exe` command lines

### Loop B - Clean uninstall + verify
1) Run: `Uninstall.cmd`
2) Verify:
   - tasks removed
   - protocol handler keys removed
   - installer-owned live files removed
   - system ready to reinstall
3) Capture evidence:
   - uninstall log(s)
   - `schtasks /Query` snapshot
   - registry checks

### Loop C - Reinstall
- Run Loop A again and confirm determinism.

---

## Work Items (Codex Execution List)

### W1 - Scheduled task action arguments (PS5.1-safe)
**Problem**
- `New-ScheduledTaskAction -Argument @(...)` can fail on PS5.1.

**Acceptance criteria**
- No array passed to `-Argument`.
- Tasks register successfully on PS5.1.

**Files**
- `_internal/Install-Firewall.ps1`

### W2 - Toast listener runs hidden (no visible consoles)
**Acceptance criteria**
- No visible console windows after install.
- Listener still functions (functional parity).

**Files**
- `_internal/Install-Firewall.ps1`
- Listener runner scripts (if needed)

### W3 - Clean uninstall completeness
**Acceptance criteria**
- Uninstall removes tasks/keys/processes/artifacts it owns.
- Safe to rerun uninstall.

**Files**
- `_internal/Uninstall-Firewall.ps1`

### W4 - Logging polish (install + uninstall)
**Acceptance criteria**
- Logs have start/end markers, step markers, explicit PASS/FAIL lines.
- No silent catches.

**Files**
- `_internal/Install-Firewall.ps1`
- `_internal/Uninstall-Firewall.ps1`

---

## Evidence Capture Commands
```powershell
git branch -vv
git status -sb

Get-CimInstance Win32_Process |
  Where-Object Name -eq 'powershell.exe' |
  Select-Object ProcessId, CommandLine

(Get-ScheduledTask -TaskName 'Firewall-Defender-Integration' -ErrorAction SilentlyContinue).Actions
(Get-ScheduledTask -TaskName 'FirewallCore Toast Listener' -ErrorAction SilentlyContinue).Actions
```

