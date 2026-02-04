# Codex Task — FirewallCore Clean Uninstall (Full Purge)

## Goal
Implement a **clean uninstall** that removes FirewallCore **completely**, including logs, baselines, queues, and optional event logs.  
This is intended for lab resets, test VMs, and full teardown scenarios.

---

## Scope
- Same uninstall script as default uninstall
- Clean uninstall is triggered via:
  - `-Mode Clean`
- No other modes allowed

---

## Required Behavior (Acceptance Criteria)

### A) Always log every invocation
Emit Event Viewer logs under:
- Log: `FirewallCore`
- Provider: `FirewallCore-Installer`

Event IDs:
- **2100** — `CLEAN UNINSTALL START`
- One of:
  - **2108** — `CLEAN UNINSTALL OK`
  - **2103** — `CLEAN UNINSTALL NOOP`
  - **2901** — `CLEAN UNINSTALL FAIL`

---

### B) File logging before purge
Clean uninstall must:
1. Write its uninstall log to:
   - `C:\ProgramData\FirewallCore\Logs\Uninstall-FirewallCore_CLEAN_YYYYMMDD_HHMMSS.log`
2. Complete uninstall
3. **Then** delete ProgramData FirewallCore folders as the final step

(Logging must not disappear mid-run.)

---

### C) What must be removed (everything)
Clean uninstall must remove:

- All items removed by default uninstall
- Entire folders:
  - `C:\ProgramData\FirewallCore\Logs`
  - `Baselines`
  - `NotifyQueue` + archives
- Optional:
  - Remove the `FirewallCore` Event Viewer log itself

---

### D) Safety constraints
- Admin-only
- Explicit confirmation prompt or hard gate
- Idempotent: running clean uninstall twice must not error

---

### E) Execution policy
- Must run under `ExecutionPolicy = AllSigned`
- PowerShell 5.1 compatible

---

## Test Plan (Must Pass)

1) Run clean uninstall on installed system
   - Expect 2100 → 2108
2) Verify **no FirewallCore artifacts remain**
3) Verify Event Viewer log removed (if implemented)
4) Run clean uninstall again
   - Expect 2100 → 2103

---

## Changes Made / Implementations Done
(Fill this section in)

- [ ] Clean uninstall implemented
- [ ] Full purge verified
- [ ] Logging-before-purge verified
- [ ] Idempotent behavior verified
