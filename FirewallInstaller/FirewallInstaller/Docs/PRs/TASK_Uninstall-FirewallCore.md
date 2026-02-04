## Codex Implementation Checklist (Gate-by-Gate)

### A) Preflight / Safety
- [ ] Confirm PS5.1-only syntax (no `??`, no `.Where()`, no PS7-only features)
- [ ] Confirm AllSigned compatibility (no self-modifying behavior)
- [ ] Confirm admin/UAC gate hard-fails when not elevated
- [ ] Confirm wrappers use hidden launch contract (no console flashes)

### B) Baseline Restore Discovery + Import
- [ ] Locate PRE-install baseline deterministically (ProgramData baselines folder + manifest)
- [ ] If PRE baseline exists: import/restore firewall state from PRE
- [ ] If PRE baseline missing: log explicit fallback behavior (no silent destructive reset)

### C) POST-Uninstall Verification Exports
- [ ] Export POST-uninstall `.wfw`
- [ ] Export POST-uninstall `.json` inventory/metadata
- [ ] Export end-to-end artifact (e.g., `*.thc`) if baseline workflow uses it
- [ ] Hash all exported artifacts using the existing tamper hashing function

### D) Cleanup (Default vs Clean)
- [ ] Remove scheduled tasks (exact list + legacy aliases)
- [ ] Remove FirewallCore-owned firewall rules by Group tags (`FirewallCorev1/v2/v3`)
- [ ] Remove wrappers/protocol handlers/shortcuts created by FirewallCore
- [ ] Default uninstall preserves ProgramData Logs/Baselines/Diagnostics
- [ ] Clean uninstall purges ProgramData last (log persists until end)

### E) Event Log Lifecycle
- [ ] Default uninstall keeps FirewallCore event log history
- [ ] Clean uninstall supports optional event log definition removal (if enabled)

### F) Idempotency
- [ ] Default uninstall rerun → NOOP (2003) without error
- [ ] Clean uninstall rerun → NOOP (2103) without error

### G) Signing / Validation
- [ ] Strip old signature blocks (if any) before final signing
- [ ] Re-sign with A33 cert (SHA256)
- [ ] Verify `Get-AuthenticodeSignature` returns `Status=Valid`






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

---

## Addendum — PRE Baseline Restore (Explicit Requirements)

### Shared module requirement (no dupes)
Uninstall must import and use:
- `Tools/Modules/FirewallBaseline.psm1`

Do not duplicate fingerprint/hash/manifest logic.

### Restore decision tree (required)
1) Discover latest PRE baseline folder:
   - `C:\ProgramData\FirewallCore\Baselines\PREINSTALL_*` (latest by LastWriteTime)
2) If baseline folder exists:
   - Require `FirewallBaseline.manifest.sha256.json` to exist
   - Run `Test-FirewallBaselineManifest` before importing
     - If FAIL: log terminal FAIL and stop (do not apply partial restore)
3) Import PRE baseline firewall state (authoritative)
4) Export POST-uninstall artifacts + hash evidence (per baseline workflow)

### If PRE baseline is missing
- Must log explicit fallback behavior (no silent reset)
- Preferred fallback: NOOP restore + continue removing only FirewallCore-owned rules/tasks/files
- Must record reason in log/event message

### If manifest exists but verification fails
- Treat as FAIL (stop) unless running in an explicitly documented lab override mode.
