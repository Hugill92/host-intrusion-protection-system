# FirewallCore Roadmap

This document defines the *implementation plan* and sequencing. It will change frequently.

---

## Current focus: Notifiers sprint (dev/notifiers)
Goals:
- Correct Info/Warn/Critical styles and sound mapping.
- Ensure "Click to Event Log / filtered view" works consistently.
- Make user vs admin behavior explicit and logged.
- Listener reliability: heartbeat + runner behavior must be stable.

Deliverables:
- Tests covering:
  - toast display
  - click-through behavior
  - sound playback routing
  - close/autoclose behaviors (as applicable)
- Logs that show:
  - which context ran (user/admin/SYSTEM)
  - which provider/event id fired
  - which action handlers executed

---

## Next: Architecture foundation (docs-first)
Create/update:
- Docs/ARCHITECTURE.md (invariants and core design)
- Docs/ERRORS.md (exit code + logging conventions)
- SECURITY_NOTES.md (artifact hygiene + baselines)
- Changelog entries for each planned capability (notes only initially)

Success criteria:
- We can explain the orchestrator/preflight/task model unambiguously.
- We have a checklist for “what must be true before install/repair proceeds.”

---

## Orchestrator framework (Phase 1 implementation)
Add an orchestrator wrapper (PowerShell first) that provides:
- Install / Repair / Uninstall / Verify / Stop
- Locking (prevent concurrent runs)
- Preflight validation gate before any worker starts
- Explicit failure messaging + standard exit codes

Notes:
- Do NOT replace existing installer scripts immediately.
- Start by wrapping existing flows safely.

---

## Preflight validation (Phase 2 hardening)
Add validations (incrementally):
- Script parse validation across repo
- Dependency checks required for the requested mode
- Guardrails for scheduling:
  - do not register tasks if verification fails
  - validate principal/service account constraints
- Managed endpoint / Defender coexistence checks (as feasible)

---

## Artifact hygiene + supply chain controls (Phase 3)
CI additions:
- Build output scanning:
  - expect one primary EXE (when applicable)
  - flag suspicious filenames/metadata
  - record sha256 and file version metadata
- Optional baseline enforcement:
  - “generate baseline” vs “enforce baseline” modes

---

## Packaging strategy (Phase 4)
- Confirm PyInstaller onefile path works end-to-end in CI.
- Decide whether MSI/WiX is needed for enterprise semantics:
  - repair/upgrade codes
  - rollback
  - registry injection requirements
- If MSI is adopted, define rules up front to prevent repair/install scope mismatch.

---

## Longer-term expansions
- Explicit GPO policy layer (documented and optional).
- File + registry scanning baseline enforcement.
- Network expansion features (separate roadmap section once core reliability is stable).

### Telemetry / Streaming (Deferred)
- Kafka streaming of notification events was prototyped (Confluent.Kafka) but rolled back due to native dependency packaging (librdkafka.dll) and config-schema guardrails. Revisit after v1 notifier signoff with a pinned dependency bundle and installer integration.

