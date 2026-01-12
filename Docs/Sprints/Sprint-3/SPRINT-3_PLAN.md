# Sprint 3 — Install / Repair / Uninstall (Plan)

Date: 2026-01-12

## Objective
Harden the **install**, **repair**, and **uninstall** workflows so they are:

- **Deterministic** (repeatable results)
- **Idempotent** (safe to run more than once)
- **Resilient** (handles partial state / missing components)
- **Auditable** (clear evidence artifacts for PASS/FAIL)

This sprint is specifically focused on shipping-grade reliability for real-world usability.

---

## Scope

### In scope
1. **Install**
   - Preflight validation (admin, OS checks, disk/path sanity)
   - File deployment (repo → live)
   - ProgramData provisioning
   - Task/service registration
   - Event log / provider registration
   - Postflight verification + summary output

2. **Repair**
   - Recreate missing directories/files
   - Re-register tasks/services
   - Re-register Event Log / providers
   - Reapply required ACLs
   - Restore “known-good” live scripts and views

3. **Uninstall**
   - Remove tasks/services safely
   - Remove files and ProgramData state safely
   - Optional cleanup of Event Log
   - Robust handling when components are already missing

4. **Regression proof**
   - Add/extend tests that validate install/repair/uninstall behavior
   - Produce a compact evidence bundle per run (logs + summaries)

### Out of scope (Sprint 3)
- Net-new feature expansion (new monitors, new rule sets, new UI)
- Major refactors of unrelated subsystems
- Performance tuning unless blocking reliability

---

## Definition of Done (DoD)

### Install DoD
- Can run install **twice** without duplicating tasks, providers, or files.
- Missing components are restored on rerun.
- A single run emits:
  - Transcript log
  - Structured summary (JSON)
  - Clear PASS/FAIL indicators per phase

### Repair DoD
- Repair detects drift and restores invariants:
  - Missing files
  - Missing/disabled tasks
  - Broken ACLs
  - Missing ProgramData structure
  - Missing Event Log registration
- Repair emits a summary: **detected drift → actions taken → post-verify**

### Uninstall DoD
- Uninstall completes without terminating exceptions even if:
  - Tasks are missing
  - Files are missing
  - ProgramData is partially missing
  - Event Log already removed
- Uninstall emits a summary: **removed → skipped → failed + reason**

### Regression DoD
- One command runs install/repair/uninstall regression checks.
- Evidence bundle is produced for each run.

---

## Planned Work Items

### A) Install: phase structure + postflight verification
- Add explicit install phases:
  1) Preflight
  2) Deploy files
  3) Provision ProgramData
  4) Register tasks/services
  5) Register Event Log / providers
  6) Postflight verification + summary
- Postflight gates:
  - Required paths exist
  - Required tasks exist and are enabled
  - Event log exists
  - Required “live scripts” exist

**Acceptance criteria**
- Re-run install is safe (no duplicates).
- Postflight emits PASS/FAIL with details.

---

### B) Repair: implement “restore invariants”
- Repair actions:
  - Recreate ProgramData layout
  - Restore required files/scripts
  - Reapply ACLs
  - Re-register tasks/services
  - Re-register Event Log / providers
- Drift simulation checks:
  - Delete a file → repair restores
  - Disable a task → repair re-enables
  - Break ACL → repair re-applies

**Acceptance criteria**
- Repair returns system to expected baseline (deterministic).

---

### C) Uninstall: self-contained helpers + resilient cleanup
- Ensure uninstall does **not** depend on missing helper imports.
- Make cleanup tolerant of missing resources.
- Add explicit reporting (removed/skipped/failed).

**Acceptance criteria**
- Uninstall always completes with a clear summary.

---

### D) Regression harness: installer suite
- Add/extend tests:
  - `Test-Install-Core.ps1` (presence/registration checks)
  - `Test-Repair-Idempotent.ps1` (break → repair → verify)
  - `Test-Uninstall-Cleanup.ps1` (uninstall → verify removal)
- Evidence bundle:
  - installer summary JSON
  - transcript logs
  - relevant event query output

**Acceptance criteria**
- A single runner produces evidence for all scenarios.

---

## Risks / Notes
- Windows Event Log registration behavior can vary by environment; treat it as a dedicated install-time step with verification and clear failure messaging.
- ProgramData “NotifyQueue” can contain ghost/stuck items; preflight archiving/purge should remain mandatory before visual verification workflows.

---

## Deliverables
- Updated install/repair/uninstall scripts
- Installer regression tests + runner
- Sprint 3 docs + evidence collection guidance
