# Sprint 2 Results - Installer/Uninstaller Hardening

## Summary
- Clean Uninstall verified via deterministic log markers + post-action fail-safe checks.
- Installer/uninstaller lifecycle is moving toward repeatable: install -> uninstall -> reinstall.

---

## What passed
- Uninstall completed successfully with start/end markers.
- Scheduled tasks validated removed/missing (installer-owned set).
- No notification listener/runner PowerShell processes remained after uninstall.
- Project-tag firewall rule scan returned no matches post-uninstall.
- Owned paths absent: C:\Firewall and C:\ProgramData\FirewallCore.

---

## What failed (and how it was fixed)
- Symptom: Uninstall appeared to hang / ambiguous “success” signals.
- Fix: enforce deterministic ordering: stop tasks -> stop processes -> remove keys -> reset firewall -> remove owned paths.
- Fix: add post-action verification (tasks/process/rules/profile sanity) to remove ambiguity.

---

## Evidence captured
- Uninstall log + debug log
- Pre/post snapshots in Tools\Snapshots
- Fail-safe verification output (tasks/process/rules/profile)

---

## Next steps (pipeline)
1) Integrate verification checks into the Maintenance UI (admin panel) post-action status.
2) Keep destructive actions admin-only; require typed confirmation for Clean Uninstall.
3) Run full lifecycle loop on at least one VM: install -> verify -> uninstall -> verify -> reinstall.
4) Sprint 3: regression testing across Forced/DEV/Live suites + signing/packaging guardrails.

---

## Maintenance UI note
- Add the post-uninstall verification checks as a status summary section.
- Keep the UI minimal: status panel + install/uninstall/repair + relaunch-as-admin.

---

## Phase B Admin Panel Test Signoff Checklist (WPF)

### Scope
Validate Tests section rendering, button wiring, deterministic logging, dev-mode gating, and UI responsiveness.

### Evidence
- C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log (tail after run)
- Screenshot: Tests section visible; dev-only controls disabled when DevMode off
- Optional: AdminPanel-PhaseB.log if produced

### Critical Button Inventory
**Tests (user-visible):**
- Quick Health Check
- Notification Demo (Info/Warn/Critical)
- Baseline Drift Check
- Inbound Allow Risk Report
- Export Diagnostics Bundle

**Bottom bar actions:**
- Refresh
- Install
- Repair
- Maintenance
- Uninstall
- Clean Uninstall

**Developer-gated:**
- Dev Suite
- Forced Suite
- Attack Simulation (Safe)
- Attack Simulation (Advanced)

### State Matrix (per button)
- default
- hover
- focus (keyboard)
- active/click
- disabled
- in-progress (if async)
- success
- error/fail

### Keyboard-Only
- Tab/Shift+Tab traverses logically
- Enter/Space activates focused button
- Focus is visible (outline) and never lost

### Resilience / Stress
- double-click / rapid repeat: should not spawn multiple processes uncontrollably
- if tool script missing: show friendly message + log "Missing script"
- if tool script fails: no crash; log status=Fail with error detail

### Logging Contract
Every click must append one row to:
C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log
Fields:
- timestamp
- action name
- resolved script path
- status (Start/Ok/Fail)
- error message if Fail

### Acceptance Criteria
- Tests section visible
- Every button click logs deterministically
- No visible PowerShell windows
- UI remains responsive during checks
- Dev-mode gating works exactly as designed

### Phase B Update (Admin Panel)
- Gate B: before = checklist/tests mostly hidden at default size; after = 1200x820 default with min 1000x720 + central scroll so most checklist rows and selectors are visible on launch.
- Status icons/colors: Segoe MDL2 Assets glyphs for PASS/WARN/FAIL with ASCII fallback ([OK]/[!]/[X]) plus color-coded status background/foreground.
- Repair options: Apply Selected launches Repair with deterministic switches (Restart notifications `-RestartToast`, Archive queue `-ArchiveQueue`, Re-apply policy `-ApplyPolicy`) and shows an "Applied" status line; Reset Defaults restores Restart notifications + Archive queue ON, Re-apply policy OFF; both actions log to AdminPanel-Actions.log.
- Dropdown UX: Tests, Dev/Lab, and System Actions consolidated into selectors + Run buttons with inline status lines and deterministic logging.
- Tests mappings: Quick Health Check -> C:\Firewall\Tools\Run-QuickHealthCheck.ps1; Notification Demo -> C:\Firewall\Tools\Run-NotificationDemo.ps1; Baseline Drift Check -> C:\Firewall\Tools\Run-DriftCheck.ps1; Inbound Allow Risk Report -> C:\Firewall\Tools\Run-InboundRiskReport.ps1; Export Diagnostics Bundle -> C:\Firewall\Tools\Export-DiagnosticsBundle.ps1. Launch contract: powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File <script>.
- Dev Mode gating: uses C:\ProgramData\FirewallCore\DevMode.enabled; toggle creates/removes flag (admin-only), updates DEV-only section visibility immediately, and logs Start/Ok/Fail.
- Rules inventory: summarized counts (Total, owned FirewallCore v1/v2/v3, non-owned) with optional "Export rules report" action rather than dumping groups.
- Focus + logging: window activates on load (Topmost pulse), and AdminPanel-Actions.log is seeded on launch with `START | AdminPanelLaunch | PID=... | User=... | Elevated=... | PS=... | <timestamp>`.
- Evidence pointers: screenshot(s) of window size + status icons + selectors (capture after run); tail excerpt from C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log showing click events (capture after run).

### LKG Revert (Sprint 2 Phase B baseline)
- Reverted Admin Panel to the LKG Phase B UI/logic baseline and stabilized checklist refresh + single-instance launch.
- Evidence pointers: `C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log` (START + Start/Ok/Fail), screenshot of selectors + checklist, and latest artifacts in `C:\ProgramData\FirewallCore\Reports`/`C:\ProgramData\FirewallCore\Diagnostics`.


## Phase B Admin Panel - UI/Wiring Follow-ups (Gate B polish)

### Observations
- UI layout improved and Dev Mode correctly reveals DEV/Forced + Lab Simulation actions.
- Window focus on launch is forced via Activate + Topmost pulse.
- Tests/Dev/System actions are dropdown-driven with status lines and Start/Ok/Fail logging.
- Checklist headers are bold with sane default widths and user-resizable columns.
- Firewall rules inventory is summarized to avoid huge dumps.
- WARN rows include Help actions (button + double-click) to open relevant tools/logs.

### Sprint 2 Goals (wiring + UX only)
- Convert Tests / Dev-Lab / System actions to dropdown selectors + Run buttons.
- Add table header bolding and sensible default column widths; keep user-resizable columns.
- Add direct “Open Logs / Open Event Viewer” actions for WARN rows (double-click supported).
- Ensure every action produces deterministic UI feedback + Start/Ok/Fail logging.

### Sprint 3 Goals (functional validation + regression)
- Implement/validate tool scripts (Health/Demo/Drift/Risk/Diag bundle) across clean VMs.
- Full regression run including Admin Panel button validation in the same pass.

### Notes on PowerShell compatibility
- Admin Panel must be compatible with PS5.1 and PS7; do not require PS7 on install.
- Prefer powershell.exe for widest compatibility; allow pwsh.exe optionally for specific scripts.
- Scheduled tasks remain on powershell.exe with hidden launch contract.

---

## Phase B Admin Panel - Gate B6 results

### What changed
- Tests/Dev/Lab/System actions consolidated into dropdown selectors with Run buttons and "Last run" status lines.
- Under-checklist layout uses a 2x2 grid: Repair Options | System Actions and Tests | Dev/Lab.
- StrictMode fix: OutputHint access is guarded for hashtable/object test definitions to avoid missing property crashes on launch.
- Default window size reduced (1200x820, min 1000x720) while keeping checklist/tests scrollable.
- Checklist grid uses virtualization, bold headers, and sane default column widths; rules inventory details summarized (count/owned/non-owned).
- WARN/FAIL rows are actionable via Help column + double-click (Open Logs, Open Task Scheduler, Open Event Viewer, Run Rules Report).
- Deterministic logging: every action writes Start/Ok/Fail to `C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log`, and startup seeds `START | AdminPanelLaunch | PID=... | User=... | Elevated=... | PS=... | <timestamp>` without crashing on missing mappings.

### Staged for Sprint 3
- Implement/verify tool scripts (health/demo/drift/risk/diag bundle) on clean VMs.
- Regression validation across DEV/Forced/Live suites and packaging signoff.

### Evidence pointers
- Screenshot: default window; screenshot: maximized window; screenshot: WARN/FAIL row with Help action.
- Admin panel click log: `C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log` (tail 30 after run).

---

## Phase B Admin Panel — Gate B6/B7 Closeout

### Status
**Result:** Core wiring is functional and producing real outputs. Remaining work is UI polish + actionability for WARN/FAIL rows + Rules Inventory WARN fix.

### Verified Working (Evidence-Based)
- Admin Panel renders successfully and remains stable during interaction.
- Tool actions produced outputs under:
  - `C:\ProgramData\FirewallCore\Reports\`
    - `QuickHealth_*.json`
    - `DriftCheck_*.json`
    - `InboundAllowRisk_*.csv`
  - `C:\ProgramData\FirewallCore\Diagnostics\`
    - `BUNDLE_*.zip`
  - `C:\ProgramData\FirewallCore\Logs\`
    - `AdminPanel-Actions.log` (startup + action trails)
- Developer Mode exposes lab-only actions (no exploitation/persistence):
  - Attack Simulation (Safe)
  - Attack Simulation (Advanced)

### Verification Checklist (UI/UX)
- Focus on launch (no taskbar click required).
- 2x2 grouping under checklist:
  - Repair Options | System Actions
  - Tests | Developer/Lab
- Checklist table:
  - Bold headers
  - Sane default column widths (not full-screen stretch)
  - User-resizable columns
  - Virtualization enabled to reduce scroll lag
- WARN/FAIL rows actionable:
  - Help actions: open Logs / open Event Viewer filtered view / open Task Scheduler
  - Double-click row triggers help only when WARN/FAIL

### Rules Inventory (Expected)
- Summary only (Total rules / Installer-owned by Group tag / Non-owned).
- Avoid listing large rule strings or package resource names.

### Acceptance Gate (Phase B Closeout) — Verify
- Focus-on-launch
- 2x2 dropdown layout
- Actionable WARN/FAIL rows
- Rules inventory summary + no `.Count` WARN
- Deterministic logs for every run

### Evidence To Capture (Final)
- Screenshot: default window
- Screenshot: maximized
- `AdminPanel-Actions.log` tail (last 20 lines)
- Names of latest outputs: QuickHealth JSON, DriftCheck JSON, InboundAllowRisk CSV, Diagnostics Bundle ZIP

---

## Gate B8/B9 Evidence Checklist
- Screenshots: default + maximized (show 2x2 layout and dropdowns)
- Tail: `AdminPanel-Actions.log -Tail 30`
- Confirm WFAS logs exist in ProgramData (3 files)
- Confirm "Open firewall traffic logs" opens the folder
- Confirm Repair Apply/Reset never cut off
- Confirm refresh shows progress/cascade cue

---

## Phase B Admin Panel - Gate B9 Fix Pack

### Changes
- Async runspace execution for checklist refresh, Rules Report, and dropdown actions with busy gating and disabled buttons.
- Rules Report help action now always opens Reports folder when script is missing and updates inline status label; logs include OutputHint.
- Refresh UX shows progress bar + "Refresh complete" status; rows remain responsive during rapid clicks.
- Layout fixes: Close button moved to footer; Dev/Lab run button stacked; details/suggested-action wrapping clamped to ~2-3 lines.
- Theme/Accent selectors added with persisted settings under `C:\ProgramData\FirewallCore\User\Settings\AdminPanelTheme.json` (PASS/WARN/FAIL colors unchanged).
- Typed confirmations logged for Clean Uninstall (`DELETE`) and Advanced Dev/Lab (`SIMULATE`).

### Evidence checklist
- Screenshots: default + maximized
- `AdminPanel-Actions.log` tail 60
- Verify Rules Report opens Reports folder or creates `RulesReport_*.json`
- Verify refresh progress/cascade visible
- Verify no clipped buttons at default size

---

## Phase B Admin Panel - Gate B8/B9 Closeout

### What changed
- Windows Firewall logging standardized to ProgramData paths with LogAllowed/LogBlocked On and MaxSize 16384; snapshots written to `C:\ProgramData\FirewallCore\Reports\WindowsFirewallLogging_*.json`.
- Checklist row added for Windows Firewall logging with Help action to open logs or latest snapshot.
- Refresh UX shows progress (`Refreshing... (x/y)`) and completion (`Last refresh: <time>`).
- Rules inventory row remains summary-only and is the only row with wrapped Details text.
- Clean Uninstall requires typed confirmation; Dev/Lab enable now requires an admin passphrase (stored as a hash).

### Evidence pointers
- Screenshot: default window; screenshot: maximized.
- Admin panel click log: `C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log` (tail 30 after run).
- Windows Firewall logs: `C:\ProgramData\FirewallCore\Logs\WindowsFirewall\firewall.log`, `C:\ProgramData\FirewallCore\Logs\WindowsFirewall\privatefirewall.log`, `C:\ProgramData\FirewallCore\Logs\WindowsFirewall\publicfirewall.log`.
- Windows Firewall logging snapshot: `C:\ProgramData\FirewallCore\Reports\WindowsFirewallLogging_*.json`.
- Outputs: `C:\ProgramData\FirewallCore\Reports\QuickHealth_*.json`, `C:\ProgramData\FirewallCore\Reports\DriftCheck_*.json`, `C:\ProgramData\FirewallCore\Reports\InboundAllowRisk_*.csv`, `C:\ProgramData\FirewallCore\Reports\RulesReport_*.json`, `C:\ProgramData\FirewallCore\Diagnostics\BUNDLE_*.zip`.
