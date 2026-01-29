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
## Admin Panel — Maintenance Mode + Exports (Sprint 3 Phase B)

### Implemented ✅
- Maintenance Mode header button is working (icon + ON/OFF text), admin-gated unlock validated under a standard user.
- Export buttons are Maintenance Mode gated: when OFF, user sees “Maintenance Mode must be ON to run exports.”
- Exports are now **non-bricking**: no BusyGate/async refresh engine is used for exports.
- Exports run via a **detached hidden worker** process (no UI lockups); worker is pinned to Windows PowerShell 5.1.

### Current export outputs 📦
- Diagnostics bundle:
  - Root: `C:\ProgramData\FirewallCore\Diagnostics`
  - Folder: `BUNDLE_yyyyMMdd_HHmmss\`
  - Includes: `Logs\`, `Reports\` (if present), `bundle.manifest.txt`, `SHA256SUMS.txt`
  - Zip is best-effort: `BUNDLE_yyyyMMdd_HHmmss.zip` (non-fatal if zip fails)
- Baseline export:
  - Root: `C:\ProgramData\FirewallCore\Baselines`
  - Folder: `BASELINE_yyyyMMdd_HHmmss\`
  - Includes: `Firewall-Policy.wfw` (netsh export), `SHA256SUMS.txt`

### Notes / guardrails 🔒
- Export operations must not brick the UI; exports must not touch the refresh engine.
- “Maintenance Mode” is required for exports and other privileged maintenance actions.


## Admin Panel — Maintenance Mode + Exports (Sprint 3 Phase B)

### Implemented ✅
- Maintenance Mode header button is working (icon + ON/OFF text), admin-gated unlock validated under a standard user.
- Export buttons are Maintenance Mode gated: when OFF, user sees “Maintenance Mode must be ON to run exports.”
- Export Diagnostics now runs without bricking the full Admin Panel UI and produces bundles deterministically.

### Current export outputs 📦
- Diagnostics bundle:
  - Root: `C:\ProgramData\FirewallCore\Diagnostics`
  - Folder: `BUNDLE_yyyyMMdd_HHmmss\`
  - Includes: `Logs\`, `Reports\` (if present), `bundle.manifest.txt`, `SHA256SUMS.txt`
- Baseline export:
  - Root: `C:\ProgramData\FirewallCore\Baselines`
  - Folder: `BASELINE_yyyyMMdd_HHmmss\`
  - Includes: `Firewall-Policy.wfw` (netsh export) + `SHA256SUMS.txt`

### Notes / guardrails 🔒
- Export operations must never brick the UI or stall refresh loops.
- Maintenance Mode is required for exports and other privileged maintenance actions.



<!-- FIREWALLCORE_ADMINPANEL_BUNDLE_EXPORTS_20260127 BEGIN -->
## Admin Panel — Bundle exports hardened (Diagnostics + Support) (2026-01-27 23:28:56)

### What shipped / locked in ✅
- **Exports moved into Actions dropdown** (Quick Actions now only: **Open Logs** + **Open Event Viewer**).
- **Maintenance Mode gate enforced**:
  - Maintenance **OFF** → shows blocking popup (no export runs)
  - Maintenance **ON** → export executes and writes evidence paths + logs
- **Two distinct export intents (keep both)**:
  - **Export Diagnostics Bundle**: app/runtime diagnostics (logs, queue health, policy snapshot, etc.) → C:\ProgramData\FirewallCore\Diagnostics\DIAG_YYYYMMDD_HHMMSS.zip (or DIAG/BUNDLE naming as implemented)
  - **Export Support Bundle (ZIP)**: “send to support” package (safe for sharing with intent/controls) → C:\ProgramData\FirewallCore\SupportBundles\BUNDLE_YYYYMMDD_HHMMSS.zip

### Integrity + chain-of-custody 🛡️
- For every bundle export:
  - Create **folder manifest hash list**: hashes.sha256.txt (SHA256 per file, relative paths)
  - Create **zip hash**: <zipname>.sha256
- Log Start/Ok/Fail and evidence paths to C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log

### Option A — Confidential transport (v1) 🔒
- Support Bundle ZIP is **password-protected** using the **same Admin/Dev unlock password** used to enable Maintenance/Dev actions.
- If encryption tooling is unavailable on a target host, export must still succeed but clearly log:
  - Encryption=Skipped and why (dependency missing), and continue with hashing + warning text.

### Later (v2/v3)
- Replace password-based bundle encryption with **signing key / secure unlock** integration (hardware-backed unlock).
<!-- FIREWALLCORE_ADMINPANEL_BUNDLE_EXPORTS_20260127 END -->

## Registry Optimization Engine (v2)

**Status:** Planned (v2)  
**Owner:** Platform / Hardening  
**Scope:** Local system optimization (deterministic, auditable, reversible)

### Description
Introduce a first-class **Registry Optimization Engine** to apply a curated set of low-level Windows performance and scheduling optimizations. The engine is implemented as a signed PowerShell tool deployed under ProgramData and executed only via controlled entry points (Admin Panel or manual invocation).

This replaces ad-hoc tuning with a **repeatable, logged, and reversible** mechanism aligned with FirewallCore’s hardening and evidence model.

### Key Characteristics
- Deployed to:
  `C:\ProgramData\FirewallCore\Tools\Registry_Optimizations.ps1`
- Supports **Preview mode (`-WhatIf`)** and **Apply mode**
- Creates:
  - `.reg` backups prior to any modification
  - Detailed verification report (ProgramData)
  - Human-readable summary (user Desktop when applicable)
- Idempotent: safe to re-run
- Explicit non-goals:
  - Does **not** manage CPU affinity or runtime priority (delegated to Process Lasso)
  - Does **not** overwrite unrelated registry values

### Evidence & Audit
- All executions generate timestamped reports under:
  `C:\ProgramData\RegistryTweaksBackup`
- Desktop summary is generated only when run in user context (non-SYSTEM)
- Designed for later enforcement under **ExecutionPolicy=AllSigned** (Sprint 4+)

### System Integrity Repair (DISM + SFC)
- Admin-initiated system repair capability
- Supports online and offline Windows images
- Deterministic DISM → SFC execution order
- Structured JSON output for automation
- Integrated into Diagnostics Bundle
- Exposed via Admin Panel (Maintenance Mode)

### V2 – Registry Optimization Engine (REGOPT)
- Completed: V1 logic validated
- Completed: Deterministic logging
- Completed: Desktop and ProgramData traceability
- Completed: Single entry point architecture
- Planned: Rollback snapshot
- Planned: Drift detection
- Planned: Authenticode enforcement
