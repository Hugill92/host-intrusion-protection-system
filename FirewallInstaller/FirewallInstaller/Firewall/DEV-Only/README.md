# Firewall Core – Forced Test Framework (DEV-Only)

This package locks forced-test execution behind an explicit manifest gate.

## Files
- `DEV-Test-Manifest.json` – SchemaVersion 1.0 (canonical contract)
- `Run-Forced-Dev-Tests.ps1` – deterministic runner (DEV by default)
- `Forced\Forced-*.ps1` – forced tests (each re-checks manifest gate)

## Safety / LIVE mode
LIVE mode is **disabled by default**.

To allow LIVE:
1) Edit `DEV-Test-Manifest.json` – SchemaVersion 1.0 (canonical contract)
   - set `_meta.LiveEnabled` to `true`
   - for each test you want, set `AllowLive` to `true` (or set category `AllowLive`)
2) Run:
   - `.\Run-Forced-Dev-Tests.ps1 -Mode LIVE -EnableLive`

If either gate is missing, LIVE will be refused or skipped.

## Notifications
Runner sends a best-effort notification on FAIL / ALERT markers:
- Toast via BurntToast (if installed), else
- Application event log (`FirewallCore-ForcedTests` source) if permitted, else
- Console warning/error.

## Logs / Results (installer-local)
All outputs are written under:
- `DEV-Only\State\ForcedTests\Run_yyyyMMdd_HHmmss\`
  - `*.stdout.txt`, `*.stderr.txt`
  - `forced-test-results_*.json`


## Schema freeze
This build aligns the runner and forced tests to the original SchemaVersion 1.0 manifest you provided. LIVE integration is deferred until DEV runs match baseline.
