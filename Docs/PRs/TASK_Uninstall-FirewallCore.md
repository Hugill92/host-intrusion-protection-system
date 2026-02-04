# Tasking — Uninstall-FirewallCore (Canonical Uninstall Engine + Wrappers)

## Objective
Implement a canonical uninstall workflow that removes FirewallCore completely and deterministically.

## Constraints / Standards
- PowerShell 5.1 compatible syntax only.
- Deterministic logs + transcript required.
- Use the standard process launch contract for wrappers/tasks:
  powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden (plus -ExecutionPolicy Bypass only when necessary).
- Avoid destructive global resets unless explicitly required and clearly logged.
- Do not modify installer files during this task.

## Inputs Observed (current tasks to remove)
Remove scheduled tasks by exact name (and include a small legacy alias map):
- Firewall-Defender-Integration
- FirewallCore Toast Listener
- FirewallCore Toast Watchdog
- FirewallCore User Notifier
- FirewallCore-ToastListener

## Required Outputs
1) Canonical script:
   - Tools\Uninstall\Uninstall-FirewallCore.ps1 (or agreed canonical path)
2) Wrapper(s):
   - Uninstall.cmd (calls canonical script with hidden launch contract)
3) Logging:
   - Writes uninstall events to FirewallCore event log
   - Writes transcript to ProgramData log folder
4) Cleanup behaviors:
   - Remove tasks (current + legacy)
   - Remove FirewallCore binaries/scripts/wrappers
   - Remove ProgramData (including Logs + NotifyQueue + user scripts)
   - Remove FirewallCore custom Event Log definition if created by installer (optional: retain EVTX export as evidence before removal)
   - Restore firewall state using PRE-install baseline if present

## Baseline Restore Contract
- If PRE baseline exists: import/restore deterministically.
- If PRE baseline missing: choose explicit fallback behavior (do not silently destroy unrelated configuration).
- Export/verify artifacts on uninstall end:
  - POST uninstall .wfw + .json (+ end-to-end artifact if present) and hash them using existing hashing logic.

## Acceptance Criteria
- Uninstall completes with ExitCode 0 on a healthy install.
- Re-run uninstall immediately after: idempotent NO-OP behavior with deterministic log message.
- No background console flashes (hidden launch contract enforced).
- After uninstall: no FirewallCore tasks, no FirewallCore ProgramData tree, no FirewallCore-owned firewall rules/policy, and firewall state restored per baseline contract.
