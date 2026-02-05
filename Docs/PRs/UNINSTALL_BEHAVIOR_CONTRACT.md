# FirewallCore Uninstall Behavior Contract

## 1. Scope
This contract defines expected behavior for:
- Standard Uninstall (Default)
- Clean Uninstall (Clean / ForceClean)

This is a behavior + verification spec. Implementation details live elsewhere.

---

## 2. Uninstall Modes

### 2.1 Standard Uninstall (Mode=Default)
Intent: Remove FirewallCore runtime components while preserving the host firewall posture.

Must remove:
- Scheduled tasks created by FirewallCore (including notification engine tasks)
- C:\Firewall runtime folder (if present)

Must preserve:
- Windows Firewall rules (including FirewallCore rule groups)
- FirewallCore policy artifacts under ProgramData
- FirewallCore event log channel
- Logs under C:\ProgramData\FirewallCore\Logs

Must NOT:
- Reset Windows Firewall to baseline/default
- Delete firewall rules
- Delete the FirewallCore event log channel

---

### 2.2 Clean Uninstall (Mode=Clean / -ForceClean)
Intent: Remove FirewallCore and restore firewall configuration to a pre-FirewallCore baseline state.

Must remove:
- All FirewallCore scheduled tasks
- All FirewallCore firewall rules (groups: FirewallCorev1 / FirewallCorev2 / FirewallCorev3)
- FirewallCore policy artifacts and state
- C:\Firewall
- C:\ProgramData\FirewallCore\Policy (if present)

Must preserve:
- FirewallCore event log channel
- C:\ProgramData\FirewallCore\Logs (uninstall logs must remain)

Result:
- No FirewallCore rule groups remain
- No FirewallCore scheduled tasks remain
- Host firewall returns to OS-managed baseline posture

---

## 3. Verification (Deterministic)

### 3.1 Scheduled Tasks
```powershell
Get-ScheduledTask | Where-Object TaskName -like 'FirewallCore*' | Select TaskPath,TaskName,State
Get-ScheduledTask -TaskName 'Firewall-Defender-Integration' -ErrorAction SilentlyContinue | Select TaskPath,TaskName,State
```

Expected:
- Default uninstall: no FirewallCore* tasks; Defender integration task removed if it is FirewallCore-owned.
- Clean uninstall: same as above (no tasks remain).

### 3.2 Filesystem Paths
```powershell
Test-Path C:\Firewall
Test-Path C:\ProgramData\FirewallCore
Test-Path C:\ProgramData\FirewallCore\Logs
```

Expected:
- Default uninstall:
  - C:\Firewall = False
  - C:\ProgramData\FirewallCore = True
  - C:\ProgramData\FirewallCore\Logs = True
- Clean uninstall:
  - C:\Firewall = False
  - C:\ProgramData\FirewallCore = False (exception: logs may remain if Logs is preserved explicitly)

### 3.3 Firewall Rule Groups (Installer-Owned)
```powershell
netsh advfirewall firewall show rule name=all | findstr /i "FirewallCorev1 FirewallCorev2 FirewallCorev3"
```

Expected:
- Default uninstall: rules may still exist (preserved).
- Clean uninstall: no output (groups fully removed).

### 3.4 Event Log Channel
```powershell
wevtutil el | findstr /i "FirewallCore"
```

Expected:
- FirewallCore channel remains present after both uninstall modes.

---

## 4. Logging Contract

### 4.1 Log Location
All uninstall logs must write to:
- C:\ProgramData\FirewallCore\Logs

### 4.2 File Naming
- Uninstall-FirewallCore_Default_YYYYMMDD_HHMMSS.log
- Uninstall-FirewallCore_CLEAN_YYYYMMDD_HHMMSS.log

### 4.3 EVTX Event ID Continuity
Maintain stable ranges to avoid jumping numbers and to preserve operator confidence.

Recommended ranges:
- 1000-1099 : Install
- 2000-2099 : Default Uninstall
- 2100-2199 : Clean Uninstall
- 3000-3099 : Repair / Self-heal

### 4.4 Message Style
EVTX messages should use consistent Windows-like formatting.
- Prefer CamelCase field labels (visual parity with common Windows logs).

---

## 5. Reliability Rule (Critical)
Uninstall logic must not fail because a log file is locked.

If transcript logging or Add-Content fails due to file locks:
- Continue uninstall
- Record outcome in EVTX
- Best-effort file logging is secondary to correctness

---

## 6. Final States (Summary)

### Default Uninstall
- No FirewallCore scheduled tasks
- C:\Firewall removed
- Firewall rules preserved
- ProgramData preserved
- EVTX channel preserved
- Logs preserved

### Clean Uninstall
- No FirewallCore scheduled tasks
- No FirewallCore firewall rule groups
- C:\Firewall removed
- ProgramData policy removed
- EVTX channel preserved
- Logs preserved

