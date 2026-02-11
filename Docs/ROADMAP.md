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

## V2 Roadmap Additions (planned)
- **FeatureSet V2: Windows Optional Features** — manifest-driven converge during install/update/repair (AuditOnly + Enforce).
- **Network Admin Suite** — deterministic network inventory + repair actions + safe profile/sharing convergence + Windows Security visibility.
  - Planning reference: `Docs/Sprints/Sprint-3/NetworkAdmin_V2_NetworkingSuiteAndSharing.md`
<!-- BEGIN V2_OPTIMIZATIONS -->
## v2 — Optimizations and Experimental Feature Flags

### Admin Panel: Optimizations
- New section: **Actions → Optimizations** (not Quick Actions)
- Checkbox packages (default simple view):
  - Performance (Safe)
  - Latency Tweaks (Medium)
  - UI/Telemetry Lean (Medium)
  - Cross-Device Resume Disable (User-level; HKCU)
- Preview Changes (read-only) available without Maintenance Mode
- Apply / Verify / Rollback are **Maintenance Mode gated**
- Evidence + support workflow:
  - Export targeted rollback snapshots **before** applying changes
  - Write deterministic logs to ProgramData (JSON + WhatItDoes + verification)

### Admin Panel: Experimental Feature Flags
- Separate section: **Actions → Experimental Feature Flags**
- Supports a drop-in tool runner located in ProgramData (not shipped inside FirewallCore)
- Logs tool file hashes, arguments, stdout/stderr, and exit code per run
- Requires explicit confirmation each run; labeled Experimental

### Registry snapshot baseline (install-time)
- On v2 install, capture a targeted “pre-change” snapshot of all registry keys managed by the optimization manifest.
<!-- END V2_OPTIMIZATIONS -->

