# PR Spec — Uninstall + Clean Uninstall Step Ledger + Logging

## Objective
Implement uninstall behavior exactly per:
- Docs/Ops/UNINSTALL_BEHAVIOR_CONTRACT.md
- Docs/Ops/EVTX_EVENTID_CONTINUITY_CONTRACT.md
- Docs/AdminPanel/UNINSTALL_VERIFICATION_LEDGER.md

No scope creep. No refactors unrelated to uninstall.

## Scope
1. Uninstall.cmd and Uninstall-Clean.cmd remain the user-facing entrypoints.
2. PowerShell uninstaller scripts implement:
   - Step-ledger logging (START/PASS/WARN/FAIL)
   - Deterministic verification after each step
3. Logging:
   - File log + transcript under ProgramData Logs
   - Event Log entries with monotonic IDs
   - Logging failures do not abort uninstall (fallback to EVTX/console)
4. Clean Uninstall:
   - Removes FirewallCore-owned rules by Group tags
   - Restores PRE-install baseline if present
   - Removes C:\Firewall and C:\ProgramData\FirewallCore
   - Optional: removes FirewallCore event log channel/source per contract

## Constraints
- Must be PS5.1 compatible.
- Must preserve AllSigned operation; all touched scripts must be re-signed after edits.
- Must not change install behavior.
- Must not delete or alter policy assets beyond uninstall scope.

## Acceptance Criteria
- Standard Uninstall:
  - Removes FirewallCore tasks and FirewallCore-owned firewall rules
  - Leaves non-FirewallCore rules untouched
  - Keeps logs by default
  - Emits UNINSTALL OK (EVTX + file log)
- Clean Uninstall:
  - Full teardown + PRE baseline restore when available
  - Removes ProgramData + C:\Firewall
  - Emits CLEAN UNINSTALL OK (EVTX + file log)
- EVTX IDs:
  - Monotonic, non-jumping, consistent mapping across install/uninstall/clean

## Evidence to capture (manual)
- VM run: uninstall + clean uninstall logs
- Task list before/after
- Rule group counts before/after
- Event log entries showing START/OK with IDs
