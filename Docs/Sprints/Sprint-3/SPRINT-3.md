# Sprint 3 — Installer Hardening & Install Signoff

**Last updated:** 2026-02-04 00:00:19

## Status
- ✅ Installer signoff (LIVE) complete: deterministic behavior, repeatable logs, and safe NO-OP confirmed.
- 🔒 Installer is now locked on main (no further changes unless regression forces a critical fix).

## What’s now guaranteed (Install)
### Deterministic Event Log telemetry
- \INSTALL START\ emitted on entry.
- \INSTALL NOOP\ emitted when already-installed (no side effects).

### Deterministic operator evidence
- Transcript logs created per run (timestamped artifacts).
- Console output is consistent/readable for operator validation.

### Signing integrity
- Installer artifacts are Authenticode-signed and verify Status=Valid using the hardware-backed signing certificate.

## Baseline capture enhancement (install-time, one-time)
- Extend installer to ensure a PRE-install baseline export exists:
  - If missing: capture once during install.
  - If present: verify it exists and is readable.
- Baseline export artifacts (minimum):
  - .wfw (authoritative firewall export)
  - .json (inventory/metadata)
  - Additional end-to-end artifact (e.g., *.thc) per baseline workflow
- Hash all baseline artifacts using the existing tamper-protection hashing function (same logic used for Golden baseline integrity).

## Uninstall direction (next)
- Build canonical uninstall engine Uninstall-FirewallCore.ps1 with wrappers.
- Uninstall removes:
  - Scheduled tasks (current + legacy map)
  - FirewallCore-owned rules/policy via PRE baseline restore (fallback behavior explicitly logged)
  - ProgramData + logs/queue + custom event log (complete removal)
- Deterministic uninstall logs + transcript required.

## Repo hygiene decision
- Sprint notes must live on main under Docs\Sprints\Sprint-* so sprint history is visible without digging through branches.
