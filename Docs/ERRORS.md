# Known Errors & Resolutions

This document records known installer and runtime errors encountered during development
and the deterministic fixes applied.

---

## Scheduled Task Creation Failure
[unchanged]

---

## Installer Script Not Found / Path Drift
[unchanged]

---

## Event Viewer View Access (Historical)
[unchanged]

---

## Ghost Console Window on Review Actions

**Symptom**
- A brief PowerShell console window flashes when selecting:
  - "Review Event Viewer Logs"
  - "Review Logs"
- Observed from both toast notifications and dialog boxes.

**Impact**
- Cosmetic only.
- Does not affect log review functionality or system state.

**Status**
- Known issue.
- Not a blocker for Sprint 1 completion.

**Planned Resolution**
- Eliminate visible console windows when invoking log review actions.
- Ensure review actions execute fully hidden.

---
