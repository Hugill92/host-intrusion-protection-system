# Known Errors & Limitations

This document records known issues, their impact, and sprint ownership.

---

## Scheduled Task Creation Failure (Resolved - Sprint 1)

**Status**
- Fixed.

**Resolution**
- Task action arguments are passed as a single deterministic string.

---

## Installer Script Path Drift (Resolved - Sprint 1)

**Status**
- Fixed.

**Resolution**
- Canonical internal script layout enforced.
- Installer derives its root dynamically at runtime.

---

## Event Viewer Views (Completed - Prior Sprint)

**Status**
- Stable and functional.

**Notes**
- Deterministic view staging completed before Sprint 1.
- Sprint 1 validated stability only.

---

## Ghost Console Window on Review Actions (Planned - Sprint 2)

**Symptom**
- A brief console window appears when selecting:
  - "Review Event Viewer Logs"
  - "Review Logs"

**Impact**
- Cosmetic only.

**Planned Resolution**
- Execute review actions fully hidden.

---

## Event Viewer ACL Hardening (Planned - Sprint 2)

**Status**
- Not a Sprint 1 blocker.

**Planned Resolution**
- Separate and harden ACLs for Event Viewer view access.
- Improve diagnostics and install-time validation.

---

<!-- BEGIN SPRINT2_UNINSTALL_RESOLVED -->
## Resolved - Sprint 2 (Uninstall reliability)
- Issue: Uninstall runs could appear successful while leaving ambiguity (hang perception or incomplete evidence).
- Resolution: deterministic uninstall ordering + explicit start/end markers + post-action verification script (tasks/process/rules/profile).
- Outcome: Clean Uninstall validated (tasks removed/missing, no toast listener processes, project-tag rules absent, owned paths removed).
<!-- END SPRINT2_UNINSTALL_RESOLVED -->
