# Sprint 2 Plan - Install & Uninstall Hardening

## Theme
Stability, lifecycle correctness, and execution hardening.

## Focus
1. Installer idempotency + deterministic logs
2. Uninstaller completeness + safety (ready to reinstall)
3. Remove ghost consoles (background components run hidden)
4. Tight validation loop: install -> uninstall -> reinstall

## Phases

### Phase 1 - Install Hardening
- Safe to rerun
- Scheduled tasks created deterministically (PS5.1-safe)
- Clear, actionable logs

### Phase 2 - Uninstall Completeness
- Remove all installer-owned tasks/keys/files
- Safe to rerun uninstall
- System ready for immediate reinstall

### Phase 3 - Failure Recovery
- Uninstall cleans partial installs
- Install fails loud with precise logs

### Phase 4 - Execution Hardening
- Background components run hidden
- Eliminate visible console windows from listener/runner and review actions

## Validation
- Canonical loop: install -> verify -> uninstall -> verify -> reinstall
- Evidence: logs + task actions + running process command lines

## Guardrails
- Work on local-only branches during triage
- Fix one failure class at a time
- Keep `_internal` as canonical script location
- Preserve uninstall symmetry (if install creates it, uninstall removes it)

## Reference
- `Docs/Sprints/Sprint-2/SPRINT_2_TRIAGE.md`


<!-- SPRINT2_PROGRESS -->

## Current Status

- Updated: 2026-01-12 13:03:51
- W1/W2 validated (task args PS5.1-safe + hidden execution + live paths).
- Next validation gates: W3 (uninstall) and Loop C reinstall determinism.


<!-- BEGIN PHASE_MAINTENANCE_UI -->
## Phase - Maintenance UI (Operator workflow)

Purpose:
- Provide a safe, repeatable operator entrypoint for lifecycle actions.

Scope:
- Read-only status panel + elevation workflow.
- Admin-only actions: Install, Clean Uninstall, Repair (stub allowed if repair contract not finalized).

Non-goals:
- No extra utility buttons (logs/event viewer/restart/archive).
- No new features beyond lifecycle workflow.

Deliverables:
- Maintenance dialog script under Firewall\User\
- Wrapper launcher under Tools\
- Logging to deterministic file paths
<!-- END PHASE_MAINTENANCE_UI -->
