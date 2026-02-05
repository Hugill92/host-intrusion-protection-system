# PR Task Breakdown — Uninstall V2

## Task 1 — Normalize entrypoints
- Ensure `Uninstall.cmd` invokes `Tools\Uninstall\Uninstall-FirewallCore.ps1 -Mode Default`
- Ensure `Uninstall-Clean.cmd` invokes `... -Mode Clean -ForceClean`
- Ensure both run with the **hidden launch contract**:
  - `powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy AllSigned -File ...`

## Task 2 — Event ID allocation update
- Implement the 50-block allocation:
  - Install 1000–1049
  - Repair 1050–1079
  - Uninstall Default 1100–1149
  - Uninstall Clean 1150–1199
  - Verification 1200–1249
- Update EVTX messages to use **CamelCase labels**.

## Task 3 — Logging hardening (file lock resilience)
- Refactor uninstall logging so it never fatals on `Add-Content` file-in-use.
- Options:
  - Retry/backoff on sharing violations
  - Fallback file if locked
  - Prefer a single writer function using `[System.IO.FileStream]` with `FileShare.ReadWrite`
- Ensure transcript (if used) writes to a **separate** file from the primary log.

## Task 4 — Default uninstall behavior verification
- Ensure Default uninstall:
  - removes tasks
  - removes install root
  - preserves ProgramData and firewall policy
- Emit EVTX steps 1100–1149 as per spec.

## Task 5 — Clean uninstall behavior
- Ensure Clean uninstall:
  - removes FirewallCore rule groups `FirewallCorev1/v2/v3`
  - restores firewall defaults:
    - baseline restore if available, else `netsh advfirewall reset`
  - removes ProgramData unless `-KeepLogs`
- Emit EVTX steps 1150–1199 as per spec.

## Task 6 — Verification Ledger (no Admin Panel yet)
- Add a console-only `Verify-Uninstall.ps1` (or embedded function) that outputs:
  - tasks, paths, rule groups, event log presence, latest logs
- This will later be called by Admin Panel.

## Task 7 — Signing + AllSigned gate
- Ensure all modified scripts/modules are re-signed.
- Validate on a clean VM with `ExecutionPolicy AllSigned`:
  - Install → Uninstall Default → Install → Clean Uninstall

## Deliverables
- Updated scripts + updated docs:
  - `Docs\PRs\PR_Uninstall_UninstallV2_Spec.md`
  - `Docs\PRs\PR_Uninstall_UninstallV2_TaskBreakdown.md`

