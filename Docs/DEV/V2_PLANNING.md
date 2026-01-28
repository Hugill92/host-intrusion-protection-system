# V2_PLANNING.md

## Feature: Registry Optimization Engine (REGOPT)

**Version:** v2  
**Type:** Hardening / Performance  
**Execution Model:** On-demand (Admin Panel action)

### Implementation Details
- Tool location:
  `C:\ProgramData\FirewallCore\Tools\Registry_Optimizations.ps1`
- Execution contract:
  `powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\ProgramData\FirewallCore\Tools\Registry_Optimizations.ps1"`

### Admin Panel Integration
Two Admin Panel actions will be introduced:

1) **Preview Registry Optimizations**
   - Invokes script with `-WhatIf`
   - No registry writes
   - Evidence links:
     - Latest `RegistryTweaks_Report_*.txt`
     - Latest `RegistryTweaks_Summary_*.txt` (user context only)

2) **Apply Registry Optimizations**
   - Executes full apply path
   - Requires admin privileges
   - Evidence links:
     - Detailed verification report
     - Registry backup folder

Both actions reuse the existing **Action → Evidence Path** pattern and are logged via `AdminPanel-Actions.log`.

### Safety & Constraints
- Script performs pre-change registry exports (`reg.exe export`) for touched keys
- Explicit allowlist of keys/values (no wildcard edits)
- Desktop output is suppressed or redirected when running under SYSTEM
- No scheduled enforcement in v2 (manual execution only)

### Future Enhancements (v3+)
- Drift detection (compare current state vs expected spec)
- Optional rollback action using stored `.reg` backups
- Enforcement under **ExecutionPolicy=AllSigned**
- Hardware-backed signing (YubiKey) integration

