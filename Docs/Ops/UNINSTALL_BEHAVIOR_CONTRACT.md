# FirewallCore — Uninstall & Clean Uninstall Behavior Contract

## Purpose
This document defines the authoritative uninstall behavior for FirewallCore, including:
- Standard Uninstall (safe, non-destructive)
- Clean Uninstall (explicit, destructive, baseline-restoring)
- Logging, verification, and Event Viewer continuity guarantees
- Admin Panel–ready verification semantics

This contract is binding for:
- CLI entrypoints (`Uninstall.cmd`, `Uninstall-Clean.cmd`)
- Admin Panel actions
- Test harnesses
- Future versions

## Definitions
### Standard Uninstall
Removes only FirewallCore-owned artifacts, preserving system state.

### Clean Uninstall
Fully removes FirewallCore and restores the system to the PRE-install baseline captured during installation.

Clean Uninstall is:
- Explicit
- Admin-only
- Destructive
- Logged and verified

## Non-negotiable rules
1. Baseline ≠ Reset  
   Baselines are used to restore PRE-install state, not factory defaults.
2. Standard Uninstall must not damage user, OEM, or domain firewall rules.
3. Clean Uninstall is the only path allowed to restore baseline.
4. Logging failures must not abort uninstall.
5. Event IDs must be monotonic and non-jumping.
6. Installer and Uninstaller share the same step-ledger model.

## Execution modes
| Mode | Behavior |
|---|---|
| DEV | Allows warnings, skips optional components |
| LIVE | Strict enforcement |
| CLEAN | Destructive, baseline restore, full teardown |

## Clean Uninstall — Step Ledger (Canonical)
Each step must:
- Log START
- Perform action
- Verify outcome
- Log PASS / WARN / FAIL
- Continue unless system integrity is at risk

### Phase 0 — Context & Safety
1. BEGIN CLEAN UNINSTALL  
   Capture: Mode=CLEAN, timestamp, user, computer, elevation status, correlation/TestId.
2. Preflight  
   Confirm Administrator. Confirm CLEAN explicitly requested. Disable self-heal / watchdog logic to prevent respawns during teardown.

### Phase 1 — Runtime Shutdown
3. Stop FirewallCore processes.
4. Stop FirewallCore services (if any).
5. Stop FirewallCore scheduled tasks (run state).

Verify: no FirewallCore runtime components active.

### Phase 2 — Scheduled Task Removal
6. Remove scheduled tasks:
   - FirewallCore Toast Listener
   - FirewallCore Toast Watchdog
   - Firewall-Defender-Integration
7. Verify tasks removed (exact-name + wildcard queries).

### Phase 3 — Firewall Rules & Baseline Restore (CLEAN-only)
8. Remove FirewallCore-owned rules by Group tags:
   - FirewallCorev1
   - FirewallCorev2
   - FirewallCorev3
9. Restore PRE-install firewall baseline captured during install.  
   Do not guess. Do not regenerate “defaults.”
10. Verify firewall state:
   - No FirewallCore rule groups remain
   - Firewall state matches PRE baseline (hash/compare when possible)

If PRE baseline is missing:
- WARN
- Fall back to removing FirewallCore-owned rules only
- Do not reset OS firewall

### Phase 4 — Artifacts & Event Logs
11. Event Log handling (CLEAN):
   - Remove FirewallCore event source
   - Optionally remove FirewallCore log channel (must be consistent and documented)
12. Remove filesystem artifacts:
   - C:\Firewall
   - C:\ProgramData\FirewallCore (all contents for CLEAN)
13. Verify removal:
   - Paths do not exist

### Phase 5 — Final Verification
14. Verification sweep:
   - No FirewallCore tasks
   - No FirewallCore rules
   - Baseline restored (if available)
   - No runtime artifacts
   - No lingering services
15. CLEAN UNINSTALL OK
   - Emit Event Log entry
   - Emit summary log including PASS/WARN/FAIL counts

## Logging contract
### File logs
Uninstall logs must align with install logging structure:

C:\ProgramData\FirewallCore\Logs\
- Uninstall-FirewallCore_<MODE>_<YYYYMMDD_HHMMSS>.log
- Uninstall-FirewallCore_<MODE>_<YYYYMMDD_HHMMSS>_transcript.log

### Reliability rule
Logging failures (file locks, access denied) must:
- Be logged as WARN
- Fall back to Event Log + console
- Never abort uninstall

## Event Viewer contract (EVTX)
- Log: FirewallCore
- Source: FirewallCore-Installer or FirewallCore-Uninstaller

Event IDs must:
- Increase monotonically
- Never jump by large ranges
- Never reset between install and uninstall

Required events:
- UNINSTALL START
- UNINSTALL STEP PASS/WARN/FAIL
- CLEAN UNINSTALL OK

## Lock-in statement
Any future change to uninstall behavior must update this contract and preserve safety guarantees.
