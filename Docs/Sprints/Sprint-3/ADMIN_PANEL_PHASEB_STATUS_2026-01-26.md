# Sprint 3 — Admin Panel Phase B — Status (2026-01-26)

## Summary
- Evidence paths (Open Logs / Open Event Viewer) work reliably.
- Export Diagnostics Bundle produces a new bundle in some runs, but can leave the UI in a degraded state until restart.
- Export Baseline + SHA256 does not reliably create a new baseline folder under C:\ProgramData\FirewallCore\Baselines.

## Observed behaviors
- UI can show refresh/dispatch failures; actions may fail with dispatch/async errors.
- After running Export Diagnostics Bundle, other buttons may become unusable until the Admin Panel is closed and reopened.
- Baseline artifacts are present inside the Diagnostics Bundle output (policy exports + hashes), but the Baselines folder does not update.

## Evidence
- Frozen log (local-only): C:\FirewallInstaller\Docs\_local\AdminPanel-Actions_2026-01-26_20260126_003219.log
- Runtime log: C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log

## Next steps
- Fix: Export Diagnostics Bundle must not brick/disable the UI; Busy/refresh gates must release deterministically.
- Fix: Export Baseline + SHA256 must create a new BASELINE_YYYYMMDD_HHMMSS folder per click and write expected artifacts.
- UX polish (later): evidence path readability without hover; selection highlight behavior.
