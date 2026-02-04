# Codex Task — FirewallCore Default Uninstall (Keep Logs)

## Goal
Implement a **default uninstall** path for FirewallCore that removes all product components while **preserving logs and evidence**.  
This uninstall must be deterministic, auditable, and safe to run repeatedly.

---

## Scope
- Primary file: `Uninstall-FirewallCore.ps1` (or equivalent existing uninstall script)
- Do NOT introduce new uninstall modes beyond:
  - Default uninstall (keep logs)
- Do NOT refactor installer logic unless strictly required

---

## Required Behavior (Acceptance Criteria)

### A) Always log every uninstall invocation
Each uninstall run must emit Event Viewer logs under:
- Log: `FirewallCore`
- Provider/Source: `FirewallCore-Installer`

Event IDs:
- **2000** — `UNINSTALL START`
- One of:
  - **2008** — `UNINSTALL OK`
  - **2003** — `UNINSTALL NOOP | reason=not-installed`
  - **2901** — `UNINSTALL FAIL | <exception>`

Never emit both OK and FAIL for the same run.

---

### B) File logging (durable)
Every uninstall invocation must create a file log:
- `C:\ProgramData\FirewallCore\Logs\Uninstall-FirewallCore_YYYYMMDD_HHMMSS.log`

Log must include:
- Start line (user, computer, elevated)
- Actions taken
- End state (OK / NOOP / FAIL)

---

### C) What must be removed
Default uninstall must remove **only FirewallCore-owned artifacts**:

- Scheduled Tasks:
  - `FirewallCore*`
  - Toast Listener / Watchdog tasks
- Installed scripts/binaries under:
  - `C:\Firewall\`
  - `C:\ProgramData\FirewallCore\User`
  - `C:\ProgramData\FirewallCore\System`
- Firewall rules owned by FirewallCore (Group tags only)
- Services or protocol handlers created by FirewallCore
- Shortcuts / UI artifacts

---

### D) What must be preserved
Default uninstall **must keep**:
- `C:\ProgramData\FirewallCore\Logs`
- Baselines / diagnostics folders (if present)
- Event Viewer **history** (do not delete the log)

---

### E) Idempotency
If FirewallCore is not installed:
- Emit `UNINSTALL NOOP`
- Do not throw
- Exit cleanly

Running uninstall multiple times must never error.

---

### F) Execution policy realism
Uninstall must run correctly under:
- `ExecutionPolicy = AllSigned`

PowerShell 5.1 compatible only.

---

## Implementation Notes
- Log START before any early-return logic
- Use try/catch/finally to guarantee logging
- Logging failures must not block uninstall
- Do not weaken system security or firewall posture

---

## Test Plan (Must Pass)

1) Run uninstall on an installed system
   - Expect 2000 → 2008
2) Run uninstall again
   - Expect 2000 → 2003
3) Verify logs remain on disk
4) Verify no FirewallCore tasks, rules, or services remain

---

## Changes Made / Implementations Done
(Fill this section in)

- [ ] Default uninstall implemented
- [ ] Deterministic logging added
- [ ] Idempotent behavior verified
- [ ] AllSigned execution verified
