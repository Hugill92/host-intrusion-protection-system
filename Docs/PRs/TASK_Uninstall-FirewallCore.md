# Tasking — FirewallCore Uninstall Architecture (Default + Clean)

## Objective
Implement a single canonical uninstall engine for FirewallCore with two allowed behaviors:

1) **Default uninstall** (keep logs/evidence)
2) **Clean uninstall** (full purge) — triggered ONLY via `-Mode Clean`

No other modes are allowed.

---

## Constraints / Standards
- **PowerShell 5.1 compatible** only (no PS7-only syntax).
- Must run under **ExecutionPolicy = AllSigned**.
- Admin-only (must hard-fail if not elevated).
- Deterministic and auditable:
  - Event Viewer logs to Log: `FirewallCore`, Provider/Source: `FirewallCore-Installer`
  - Durable file log created for every invocation
- Idempotent: running uninstall repeatedly must never error.

---

## Canonical Files / Entrypoints
### Engine
- `Tools\Uninstall\Uninstall-FirewallCore.ps1`

### Wrappers (hidden launch contract)
- `Uninstall.cmd` → default uninstall
- `Uninstall-Clean.cmd` → clean uninstall (`-Mode Clean`) and includes the clean gate

Hidden launch contract (required):
- `powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden`
- Use ExecutionPolicy AllSigned in production; Bypass only for controlled lab scenarios (must be explicitly documented if used).

---

## Event Logging Contract (Required)

### Default uninstall
Emit under:
- Log: `FirewallCore`
- Provider/Source: `FirewallCore-Installer`

Event IDs:
- **2000** — `UNINSTALL START`
- One of:
  - **2008** — `UNINSTALL OK`
  - **2003** — `UNINSTALL NOOP | reason=not-installed`
  - **2901** — `UNINSTALL FAIL | <exception>`

Never emit both OK and FAIL for the same run.

### Clean uninstall
Emit under the same Log/Provider.

Event IDs:
- **2100** — `CLEAN UNINSTALL START`
- One of:
  - **2108** — `CLEAN UNINSTALL OK`
  - **2103** — `CLEAN UNINSTALL NOOP`
  - **2901** — `CLEAN UNINSTALL FAIL | <exception>`

---

## File Logging Contract (Required)

### Default uninstall log path
- `C:\ProgramData\FirewallCore\Logs\Uninstall-FirewallCore_YYYYMMDD_HHMMSS.log`

### Clean uninstall log path
- `C:\ProgramData\FirewallCore\Logs\Uninstall-FirewallCore_CLEAN_YYYYMMDD_HHMMSS.log`

Log must include:
- Start line (timestamp, user, computer, elevated status, mode)
- Each action taken (tasks removed, paths removed, rules removed, baseline restore actions)
- End state (OK / NOOP / FAIL)

### Clean uninstall purge ordering (hard requirement)
Clean uninstall must:
1) Write the uninstall file log to ProgramData Logs
2) Perform uninstall actions
3) **Delete ProgramData FirewallCore folders as the final step**
   - Logging must not disappear mid-run.

---

## Ownership Boundaries

### Scheduled tasks to remove (exact names + allowlist legacy aliases)
Remove these tasks if present:
- `Firewall-Defender-Integration`
- `FirewallCore Toast Listener`
- `FirewallCore Toast Watchdog`
- `FirewallCore User Notifier`
- `FirewallCore-ToastListener`

### Firewall rules to remove
- Remove ONLY FirewallCore-owned firewall rules (Group tags only)
  - `FirewallCorev1`, `FirewallCorev2`, `FirewallCorev3`

### Installed file locations to remove (default + clean)
Remove product scripts/binaries under:
- `C:\Firewall\`
- `C:\ProgramData\FirewallCore\User`
- `C:\ProgramData\FirewallCore\System`
- Protocol handlers / shortcuts / UI artifacts created by FirewallCore

---

## What Default Uninstall Must Preserve
Default uninstall must keep:
- `C:\ProgramData\FirewallCore\Logs`
- Baselines / diagnostics folders (if present)
- Event Viewer history (do not delete the log)

---

## What Clean Uninstall Must Remove
Clean uninstall must remove everything default uninstall removes, PLUS:
- Entire folders under `C:\ProgramData\FirewallCore\` including:
  - `Logs`
  - `Baselines`
  - `NotifyQueue` (and any archives)
- Optional (configurable but supported):
  - Remove the `FirewallCore` Event Viewer log definition itself

---

## Clean Uninstall Gate (Required)
Clean uninstall must require an explicit confirmation or hard gate:
- Either:
  - interactive confirmation prompt, OR
  - require a switch such as `-ConfirmClean` / `-ForceClean` (recommended for automation)

If gate is not satisfied:
- log `CLEAN UNINSTALL NOOP` with reason
- exit cleanly

---

## Baseline Restore Contract (Required)
Goal: after uninstall, firewall state must revert to pre-install.

- If PRE baseline exists:
  - restore deterministically (import baseline)
  - then export POST-uninstall artifacts (.wfw + .json + end-to-end artifact if used) and hash them using existing hashing logic.
- If PRE baseline missing:
  - select an explicit fallback behavior
  - DO NOT silently destroy unrelated configuration
  - must log the chosen fallback behavior clearly.

Artifacts expected for export/validation:
- `.wfw`
- `.json`
- end-to-end artifact (e.g., `*.thc`) if part of baseline workflow
- hashes produced using existing tamper-protection hashing function

---

## Implementation Requirements
- Use try/catch/finally:
  - START event must be logged even if early return
  - FAIL event must be logged on exception
  - file log creation must be best-effort and should not block uninstall if logging fails
- No PS7-only operators or methods.
- No console flashes from wrappers.

---

## Test Plan (Must Pass)

### Default uninstall
1) Run default uninstall on installed system
   - Expect 2000 → 2008
2) Run default uninstall again
   - Expect 2000 → 2003
3) Verify logs remain on disk
4) Verify no FirewallCore tasks/rules/services/handlers remain

### Clean uninstall
1) Run clean uninstall on installed system
   - Expect 2100 → 2108
2) Verify no FirewallCore artifacts remain (including ProgramData)
3) If event log removal enabled, verify log definition removed
4) Run clean uninstall again
   - Expect 2100 → 2103

---

## Changes Made / Implementations Done
(Fill this section in)

- [ ] Canonical uninstall engine implemented
- [ ] Wrappers implemented (hidden launch contract)
- [ ] Deterministic Event Viewer logging implemented
- [ ] Durable file logs implemented
- [ ] Baseline restore implemented (PRE -> POST verification)
- [ ] Clean purge ordering verified (log persists until final step)
- [ ] Idempotency verified (Default and Clean)
- [ ] AllSigned execution verified
