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


<!-- LOCKIN:ToastMicroFlashError BEGIN -->

Periodic micro-flash (console) every few minutes

Cause: Toast Watchdog spawning Toast Listener without a strict hidden launch contract, and/or Listener crash in PS5.1 due to WinRT type resolution.

Fix: Patch Watchdog to fast-exit and only start Listener if not running using the hidden launch contract (powershell.exe -WindowStyle Hidden ...). Patch Listener to resolve WinRT types via ContentType=WindowsRuntime. Ensure Listener MultipleInstancesPolicy=IgnoreNew.@(
  Get-ScheduledTaskInfo -TaskName "FirewallCore Toast Listener"
  Get-ScheduledTaskInfo -TaskName "FirewallCore Toast Watchdog"
) | Select-Object TaskName, LastRunTime, LastTaskResult, NextRunTime |
  Format-Table -AutoSize
Expected: no idle flashes and stable task results.
<!-- LOCKIN:ToastMicroFlashError END -->


# === LOCKIN:InstallPolicyApplyLogging BEGIN ===
## Install policy apply visibility and verification (LOCKED)

**Requirement**
- Policy application must occur during install (before verification/tests) and must never be silent.

**Evidence**
- Policy apply output log must exist:
  - `C:\Firewall\Logs\Install\ApplyPolicy.log`

**Verification**
```powershell
Get-Content 'C:\Firewall\Logs\Install\ApplyPolicy.log' -Tail 80
(Get-NetFirewallRule | Measure-Object).Count
```
# === LOCKIN:InstallPolicyApplyLogging END ===

