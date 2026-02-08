<!-- SPRINT1_SNAPSHOT -->
# NOTIFIERS_SIGNOFF (Sprint 1 Snapshot)

> Snapshot taken: 2026-01-12 13:49:56 (commit 5465406)
> Canonical source of truth: Docs/NOTIFIERS_SIGNOFF.md

---
# Notifiers Signoff: Info / Warn / Critical

This document is the **signoff contract** for notification behavior and should be updated only when behavior requirements change.

---

## Notes and design constraints (read first)

### Fail early, fail loud
- Any notifier invocation must validate prerequisites early (toast listener available, Event Log access possible, required sound assets present).
- If validation fails, stop and log: root cause, phase, and a standard exit code when applicable.

### One orchestration brain
- Notifier workers/listeners should be started and supervised through a single coordinating flow (orchestrator pattern).
- Each time a worker starts, guardrails are re-validated (context, dependencies, integrity).

### Deterministic and auditable
- Behavior must be deterministic and consistent across runs.
- State and logs must be explicit (ProgramData state files + structured logs).

### Enterprise-friendly conventions
- Prefer standard exit codes and clear separation of install/repair/uninstall responsibilities.
- Be mindful of Defender/Tamper constraints and user vs admin context differences.

### Supply chain & artifact hygiene
- Sound assets and shipped artifacts must be predictable. Unexpected artifacts are treated as failures or elevated warnings.

---

## Severity behavior matrix (single source of truth)

| Severity  | Auto-close | Sound       | Click action | Close/X behavior | Reminder behavior |
|----------|------------|-------------|--------------|------------------|------------------|
| Info     | 15s        | ding.wav    | Open EV filtered view | Normal close allowed | None |
| Warn     | 30s        | chimes.wav  | Open EV filtered view | Normal close allowed | None |
| Critical | Never      | chord.wav   | Open EV filtered view | Close/X disabled; must use Manual Review | Remind every 10s until acknowledged |

---

## Invariants (must always be true)

- Click action must open the correct **Event Viewer filtered view**:
  - Log: FirewallCore dedicated log
  - Provider: FirewallCore.* (unified providers)
  - Correct EventId/filters for the alert shown
- Sound played must match the severity mapping above.
- Auto-close must match the mapping above and never rely on defaults.
- All actions must log: severity, event id, filter args, execution context (User/Admin/SYSTEM), and handler result.

---

## Critical acknowledgement model

Critical alerts require explicit operator acknowledgement.
- Close/X is disabled by design.
- A **Manual Review** action must be used to acknowledge.
- Until acknowledged, a reminder fires every **10 seconds** (throttle-safe).

Recommended implementation notes:
- Use a small state marker keyed by EventId + Correlation/TestId (e.g., ProgramData\\FirewallCore\\State\\ack\\<id>.flag).
- Reminder loop stops only after acknowledgement state is written.

---

## Signoff procedure (operator checklist)

For each severity (Info / Warn / Critical):
1. Trigger the notification.
2. Confirm style matches severity.
3. Confirm correct sound plays.
4. Confirm auto-close behavior:
   - Info closes ~15s
   - Warn closes ~30s
   - Critical never auto-closes
5. Confirm click opens correct EV filtered view for the event.
6. Confirm logs show click handler success/failure and context.
7. For Critical only:
   - Verify Close/X does not dismiss.
   - Verify Manual Review performs acknowledgement.
   - Verify reminder repeats every ~10s until acknowledged, then stops.

## Implementation status (2026-01-10 sprint)

### Verified wins
- Queue plumbing confirmed: payloads land in Pending and are moved by the listener.
- Custom WAV sounds confirmed (Windows system sounds suppressed for toasts).
- Protocol activation added for toast actions:
  - irewallcore-review:// opens Review Log / Details via FirewallToastActivate.ps1
- Warning dialog auto-close adjusted to 20s; reminder cadence preserved at 10s for manual review loops.

### Remaining signoff items (finish line)
- Restore/guarantee toast popup visibility (banner rendering) consistently across reboots and shell-host state.
- Ensure “Click to EV/Review” works for each severity with correct folder/file mapping.
- Finalize per-severity UX:
  - Info: fast, low friction, deterministic (tray/center visibility)
  - Warning: toast + optional dialog (Review Log)
  - Critical: toast + mandatory dialog + manual review loop


