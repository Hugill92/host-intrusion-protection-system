Implement exactly this spec. Do not ask clarifying questions.
If any file paths differ, search the repo for the closest matching canonical Admin Panel/XAML file and proceed.
Do not partially implement: complete every checklist item and fill in "Changes Made / Implementations Done" with exact file paths and bullets.
Ignore anything testing/Pester related: do not add or modify Pester tests or TESTING.md.
# PR – Admin Panel Phase B Wiring + Loop Fixes (Deterministic)

This PR implements the Admin Panel Phase B wiring and fixes infinite-refresh/looping behaviors with deterministic logging and PS5.1 compatibility.
# Codex Tasking – FirewallCore Admin Panel Phase B + Loop Fixes + Deterministic Actions (No Test Tasking)

## Goal (Read This First)
The Admin Panel currently has multiple infinite refresh loops, missing/unfinished inventory/status grid, and unreliable Actions/Test buttons that either:
- continuously refresh forever,
- block UI interaction,
- crash due to missing helper scope or runspace wiring,
- or don’t log deterministically.

This task wires Phase B properly and fixes the looping behavior while enforcing the process launch contract (no console flashes, hidden PowerShell, deterministic logging).

Do NOT add “fancy” new features beyond what’s listed. Stabilize and make deterministic.

---

## Non-Negotiable Engineering Contracts

### 1) No infinite loops / no runaway refresh
- No button should trigger a repeating refresh that cannot be stopped.
- Every action must have:
  - start state (Busy++)
  - deterministic completion state (Busy--)
  - UI re-enable
  - log evidence
  - timeouts / cancellation where appropriate

### 2) Deterministic action runner
All buttons (Install/Repair/Uninstall/Tests/etc.) must route through a single action execution pattern:
- enqueue action -> execute -> emit logs + output -> mark complete -> refresh UI once.

### 3) Logging requirements (audit-grade)
Every action/test must write to:
- C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log

Each entry must include:
- Timestamp (ISO8601)
- ActionName
- Result (OK/FAIL)
- DurationMs
- Evidence pointers (paths to snapshots/bundles/reports)
- Exception details on FAIL

### 4) Process launch contract (NO console flashes)
Any scheduled task, protocol handler, or Start-Process must use:
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass
(+ -STA ONLY when needed for toast/UI COM cases)

No pwsh unless explicitly required. Remove PS7-only features from shipped runtime (PS5.1).

### 5) PS5.1 compatibility
- Do NOT use ?? or PS7-only syntax in shipped scripts.
- Be strict about quoting and Join-Path usage.
- Avoid markdown backticks inside double-quoted PowerShell strings (use single quotes).

---

## Primary Symptoms to Fix (Current Bugs)
1) Endless refresh loop after:
   - Install
   - Repair
   - Uninstall / Clean Uninstall
   - Inbound Allow Risk Report
   - Diagnostics Bundle
   - Dev/Forced/Attack Simulation suites
   - Some tests (even when they “work” they keep looping)

2) Missing inventory/status table (grid of checks):
   - Install state
   - Scheduled tasks status
   - Firewall rules count by Group tags FirewallCorev1/v2/v3
   - Event log health
   - Notify queue counts
   - Last test summary / last bundle

3) Buttons crash / helper scope issues:
   - Fix by centralizing helpers and ensuring they exist at runtime execution scope.

4) Themes/accent not working:
   - Minimal implementation: persist + apply to root container.

---

## Required UI Outcomes (Admin Panel must show)

### A) Health/Status Checklist Grid (User-facing)
Rows (each row: Status + 1-line summary + Expandable details + single contextual action)
- Install State
- Scheduled Tasks (Listener/Watchdog/etc.)
- Firewall Rules Count (by Group tags: FirewallCorev1 / FirewallCorev2 / FirewallCorev3)
- Event Log Health (FirewallCore log exists + providers writing)
- Notify Queue Health (counts by state: Working/Failed/Archived)
- Last Test Summary (from last run log)
- Last Diagnostics Bundle (path + timestamp)

PASS rows show “No action needed”.
FAIL rows show “Recommended action” button (Repair, Open Logs, Export Bundle, etc.).

### B) Actions Section
Buttons must work, return, and log deterministically:
- Repair
- Uninstall (with keep logs option)
- Open Logs
- Open Event Viewer (filtered view)
- Export Baseline + SHA256
- Export Diagnostics Bundle

### C) Tests Section (Phase B)
Buttons:
- Quick Health Check
- Notification Demo (Info/Warn/Critical)
- Baseline Drift Check
- Inbound Allow Risk Report
- Export Diagnostics Bundle

Dev-only (behind Dev toggle/admin-only check for now; Secure Unlock gate later):
- DEV test suite
- Forced test suite
- Attack Simulation (Local) / Defensive Validation (benign)

IMPORTANT: Tests section must be implemented inside XAML with a named host container and explicit wiring.
Do NOT use brittle runtime injection hooks.

---

## Required File Targets (Edit These, Don’t Scatter Logic)
Primary Admin Panel script (expected):
- Firewall/User/FirewallAdminPanel.ps1 (or canonical equivalent)

XAML:
- Firewall/User/AdminPanel.xaml (or equivalent)
- Firewall/User/Tests.xaml (if exists)

Logging:
- Prefer module helpers under Firewall/Modules rather than scattered scripts.

---

## Implementation Requirements (Fix the Looping)

### 1) Create a single action runner
Implement something like:
- Invoke-AdminPanelAction -Name <string> -ScriptBlock <sb> -UiUpdate <sb>

Rules:
- increments busy counter at start
- disables initiating button or whole action panel
- runs in background/runspace safely
- catches exceptions -> logs -> surfaces FAIL row summary
- decrements busy counter in finally
- triggers exactly ONE UI refresh when done

### 2) Fix cascade refresh behavior
Replace repeated cascades with:
- Request-UiRefresh -Reason <string> (debounced; ignore duplicates within 250–500ms)
Ensure refresh does NOT re-trigger actions.

### 3) Busy counter must be correct
Implement or fix:
- Get-UiBusyCount
- Increment-UiBusy
- Decrement-UiBusy

Hard rules:
- Busy counter never negative
- If Busy > 0, disable action buttons
- When Busy returns to 0, enable once

### 4) Output queue pattern (no UI thread violations)
Use:
- Enqueue-ActionOutput -Text ... -ActionLabel ...
- Process-ActionOutputQueue on UI thread via DispatcherTimer

No direct Write-Host for UI status (logs still file-based).

---

## Scheduled Task / Console Flash Fixes (Admin Panel must validate)
Admin Panel health grid must check:
- Task exists
- Task action command line matches hidden launch contract
- Task last run result OK

If mismatch:
- provide Repair Task Action button (admin/elevated)
- log changes

---

## Event Log Requirements
Health grid must check:
- FirewallCore Event Log exists
- Providers writing under it

Open Event Viewer (filtered view) must open canonical FirewallCore filtered view.

---

## Inbound Allow Risk Report (Deterministic)
Button must generate CSV:
- C:\ProgramData\FirewallCore\Reports\InboundAllowRisk_YYYYMMDD_HHMMSS.csv

Include at least:
- RuleName, Enabled, Direction, Action, Profile, EdgeTraversal
- RemoteAddress scope (none vs restricted)
- Program/Service, LocalPort/Protocol
- Risk flags: Public allow, EdgeTraversal allow, no RA scope, key services (Spooler/WMI/mDNS/SSDP/dosvc/Hyper-V)

Update UI summary with report path and log evidence.

---

## Diagnostics Bundle (Deterministic)
Button must:
- create folder: C:\ProgramData\FirewallCore\Diagnostics\BUNDLE_YYYYMMDD_HHMMSS
- include lifecycle exports + key logs + policy exports + hashes
- zip to .zip
- update UI + log

Must not loop refresh.

---

## Notification Demo (Info/Warn/Critical)
Button must:
- preflight archive notify queue (non-destructive archive)
- ensure listener running (or FAIL + recommended action)
- trigger Info/Warn/Critical demo
- log TestId + evidence paths
- return control to UI (no loops)

---

## Security & Safety Guardrails
- No destructive actions without admin elevation validation.
- State-changing actions record: previous state snapshot path + post state snapshot path.
- No silent failure.

---

## Deliverables Checklist
- Admin Panel no longer loops on any button
- Inventory/status grid implemented and populated
- Tests section implemented via XAML host + explicit wiring
- All actions/tests log deterministically to AdminPanel-Actions.log
- Busy counter works and prevents re-entrancy
- Scheduled task checks validate hidden launch contract
- Inbound Allow Risk Report generates CSV + updates UI + logs
- Diagnostics Bundle creates folder + zip + updates UI + logs
- Notification Demo triggers Info/Warn/Critical + logs + returns UI control
- PS5.1 compatibility maintained (no PS7-only syntax)
- Docs updated as needed

---

## REQUIRED SECTION – Changes Made / Implementations Done
Codex MUST fill this out with bullet points and file paths:

### Changes Made / Implementations Done
- Files changed:
  - -
- Functions added/modified:
  - -
- Loop fixes implemented:
  - -
- XAML wiring changes:
  - -
- Logging additions:
  - -
- Notes / Known limitations:
  - -

END.
