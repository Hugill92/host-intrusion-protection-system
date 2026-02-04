# FirewallCore — EVTX Event ID Continuity Contract

## Goal
Ensure installer and uninstaller Event Log entries are easy to correlate and do not “jump” or fragment.

## Requirements
1. Single log channel:
   - LogName: FirewallCore
2. Stable event sources:
   - FirewallCore-Installer (preferred single source)
   - Optionally FirewallCore-Uninstaller (allowed, but keep consistent)
3. Monotonic, non-jumping Event IDs:
   - IDs increase in small increments
   - Avoid large jumps that break operator mental mapping
   - Avoid reusing IDs for different meanings
4. Shared numeric space:
   - Install and Uninstall use the same ID range strategy
   - Do not reset numbering between phases

## Suggested ID bands (example)
- 1000–1099: Install START/OK/FAIL + major steps
- 1100–1199: Uninstall START/OK/FAIL + major steps
- 1200–1299: Clean Uninstall START/OK/FAIL + major steps
- 1300–1399: Verification / audit summaries

## Required events
- Install START, Install OK/FAIL
- Uninstall START, Uninstall OK/FAIL
- Clean Uninstall START, Clean Uninstall OK/FAIL
- Optional: step PASS/WARN/FAIL events with correlation/TestId

## Notes
- Event log should never be the sole evidence sink; file logs must mirror outcomes.
- Logging failures must not abort uninstall; emit WARN and continue.
