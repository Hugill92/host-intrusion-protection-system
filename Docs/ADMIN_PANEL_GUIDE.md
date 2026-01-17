# FirewallCore Admin Panel Guide

## Overview
The FirewallCore Admin Panel provides a single operator console to:
- View system health and protection status
- Run verification tests and generate reports
- Perform repair actions and lifecycle operations (install/repair/maintenance/uninstall)
- Export diagnostic bundles for investigation and support

Actions are designed to be deterministic and auditable: when you run a test or action, it should generate observable evidence (Event Log entries, user alert notifications, or output files) and record an action log entry.

---

## Sections

### 1) System Checklist
A checklist grid shows the current system state and readiness.

**Columns**
- **Check**: the control or subsystem being validated
- **Status**: PASS / WARN / FAIL
- **Details**: reason and evidence (word-wrapped; multi-line)
- **Suggested Action**: recommended next step
- **Help**: short guidance
- **Evidence / Path**: output location for reports/logs/bundles

**How to use**
- **PASS**: no action needed
- **WARN**: run the suggested action and re-check
- **FAIL**: run repair actions or lifecycle actions depending on the row

---

### 2) Actions (Repair + System Actions)
Repair options and lifecycle actions are presented together.

**Refresh controls**
- **Refresh interval**
- **Auto-refresh**
- **Refresh Now** (manual re-check button)

**Repair options**
- Apply selected repair steps (non-destructive defaults)
- Reset defaults

**System actions**
- Install
- Repair
- Maintenance
- Uninstall
- Clean uninstall (requires explicit operator confirmation)

---

### 3) Admin Tests (Safe + Lab Simulations)
This area contains operator tests to validate logging, protection behavior, and reporting.

**Safe tests**
- Quick Health Check
- Notification Demo (Info / Warning / Critical)
- Baseline Drift Check
- Inbound Allow Risk Report
- Rules Report
- Export Diagnostics Bundle

**Lab Simulations (Dev Mode)**
Lab simulations are non-persistent and are intended to demonstrate how the system behaves during suspicious activity. Lab simulations should generate:
- Event Log evidence, and
- User alert notifications (pop-ups) that mirror real-world behavior.

Dev Mode is gated by an unlock prompt.

---

## Dev Mode Unlock
Dev Mode is enabled via a time-limited unlock workflow:
- The Dev Mode checkbox triggers an unlock prompt.
- If unlock is successful, Dev Mode is enabled temporarily.
- Dev Mode re-locks automatically after the session expires.

This enables safe operation by default while allowing admins to validate behavior intentionally.

**Current default unlock secret**
- `admin` (all lowercase)

---

## Notifications and Evidence
Operator actions should be observable:
- Event Log entries for each test/simulation (required)
- User alert notifications (pop-ups) for lab simulations (enabled by default)
- Output artifacts for reports/bundles

---

## Output Locations
Standard locations for generated artifacts:

**Logs**
- `C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log`

**Reports**
- `C:\ProgramData\FirewallCore\Reports\`

**Diagnostics**
- `C:\ProgramData\FirewallCore\Diagnostics\`

---

## Troubleshooting

### Refresh does not show completion
- Click **Refresh Now**.
- Check `AdminPanel-Actions.log` for completion markers.

### A report action runs but no output appears
- Check the **Evidence / Path** column for the output location.
- Verify write permissions under `C:\ProgramData\FirewallCore\Reports\`.
- Check `AdminPanel-Actions.log` for errors.

### Dev Mode prompt appears but tools stay locked
- Confirm the unlock secret is entered correctly (case-sensitive).
- If the secret is unknown, use the Dev Mode reset workflow (if enabled by the installer/admin).

---

## Safe Operating Notes
- Run tests only on systems you administer.
- Prefer running diagnostics and reports before destructive actions.
- Keep exported bundles and logs secured.
