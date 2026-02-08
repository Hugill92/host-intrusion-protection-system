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


<!-- SPRINT2_PROGRESS -->

## Sprint 2 Progress (Triage Status)

- Timestamp: 2026-01-12 13:03:51
- Verification pack: all green

### Completed
- W1: PS5.1-safe scheduled task arguments (single string) - PASS
- W2: Hidden execution + LIVE paths for toast infrastructure - PASS

### Evidence (high level)
- Scheduled tasks: Hidden execution detected and task args are a single string
- Toast listener: scheduled task launches live scripts under `C:\Firewall\...`
- Protocol handler: `firewallcore-review` present
- Event Log: `FirewallCore` log exists
- Core assets present: listener, runner, watchdog, sounds

### Pending
- W3: Uninstall completeness (Loop B) -> verify tasks/keys/files removed and idempotent
- W4: Logging polish -> confirm no silent catches and logs contain start/end + step markers

### Next Steps
- Run Loop B (uninstall) and capture verification output (tasks removed, protocol handler removed, ProgramData cleanup, no listener processes).
- Run Loop C (reinstall) to confirm determinism.

### Update (2026-01-12 13:11:54)
- Ghost shells still appear about every 5 minutes after install.
- W2 reopened; investigate watchdog/task/process trigger.
- Next: capture `powershell.exe` and `conhost.exe` at flash time to identify the source.



<!-- BEGIN UNINSTALL_VERIFICATION_PASS -->
---

## Uninstall verification - PASS (2026-01-12)

Outcome:
- Uninstall completed successfully (start/end markers present).
- Scheduled tasks verified removed/missing.
- No toast listener/runner PowerShell processes remained.
- Project-tag firewall rule scan returned no matches.
- Default firewall profile state captured post-run.

Operator evidence:
- Capture uninstall log + debug log.
- Capture before/after snapshots from Tools\Snapshots.
- Run the fail-safe verification script below and save output.

Admin panel integration:
- Add this verification as a post-action step after Clean Uninstall.
- Surface results in the status panel (PASS/WARN/FAIL per section).

Fail-safe verification script (copy/paste):
```powershell
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== A) Scheduled tasks (should be MISSING) ===" -ForegroundColor Cyan

$tasks = @(
  "Firewall Core Monitor",
  "Firewall WFP Monitor",
  "Firewall-Defender-Integration",
  "FirewallCore Toast Listener",
  "FirewallCore Toast Watchdog",
  "FirewallCore-ToastListener",
  "FirewallCore-ToastWatchdog",
  "FirewallCore User Notifier"
)

foreach ($t in $tasks) {
  $st = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
  if ($st) {
    Write-Host ("FAIL: Task still present -> {0}" -f $t) -ForegroundColor Red
    ($st.Actions | Select-Object -First 1) | Format-List Execute,Arguments,WorkingDirectory
  } else {
    Write-Host ("PASS: Task missing -> {0}" -f $t) -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "=== B) Running related PowerShell processes (should be NONE) ===" -ForegroundColor Cyan
$procs = Get-CimInstance Win32_Process |
  Where-Object { $_.Name -eq "powershell.exe" -and $_.CommandLine -match "FirewallToastListener|ToastWatchdog|FirewallCore" } |
  Select-Object ProcessId, CommandLine

if ($procs) {
  Write-Host "FAIL: Found running related processes:" -ForegroundColor Red
  $procs | Format-Table -AutoSize
} else {
  Write-Host "PASS: No related PowerShell processes found" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== C) Firewall rules (project-tag search) ===" -ForegroundColor Cyan
$tags = @("FirewallCore","Firewall Core","HIPS","Host Intrusion Protection","Pentest","DEV-Only","Forced")
$hits = @()
foreach ($tag in $tags) {
  $hits += Get-NetFirewallRule -ErrorAction SilentlyContinue |
    Where-Object {
      ($_.DisplayName -like ("*" + $tag + "*")) -or
      ($_.Group -like ("*" + $tag + "*")) -or
      ($_.Description -like ("*" + $tag + "*"))
    }
}
$hits = $hits | Sort-Object -Property Name -Unique

if ($hits.Count -gt 0) {
  Write-Host ("WARN: Found firewall rules that match project tags: {0}" -f $hits.Count) -ForegroundColor Yellow
  $hits | Select-Object DisplayName, Group, Enabled, Direction, Action, Profile | Format-Table -AutoSize
} else {
  Write-Host "PASS: No firewall rules matched project tags" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== D) Windows Firewall defaults quick sanity ===" -ForegroundColor Cyan
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize
```

<!-- END UNINSTALL_VERIFICATION_PASS -->

