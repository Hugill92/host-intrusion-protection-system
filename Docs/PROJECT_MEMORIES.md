## Firewall policy workflow (deterministic baselines + tagging)

### Rule tags (ownership)
- Do NOT tag Windows default rules (no "winDefault" tagging).
- Only tag installer-owned rules using the rule Group field:
  - FirewallCorev1
  - FirewallCorev2
  - FirewallCorev3
- Tag installer-owned rules via baseline diff vs DEFAULT (not by fuzzy string matching).
- Keep version tags stable (do not include change labels like "PM2" in rule Group tags).

### Baseline tags (evidence folders)
Baselines are tagged in the baseline folder name + README, not in rule tags:
- DEFAULT (machine default baseline)
- PRE-<change> (before applying policy/rule changes)
- POST-<change> (after applying policy/rule changes)

### Mandatory before/after steps for any firewall policy change
1) PRE: bulletproof export .wfw + SHA256 and capture PRE baseline
2) Apply change (hardening / import / rule adds)
3) POST: bulletproof export .wfw + SHA256 and capture POST baseline
4) Run Audit V2 CSV (risk report)
5) Tag new installer-owned rules (DEFAULT vs POST diff) to FirewallCorevX

### Notes
- V1 hardening may take time; record PRE/POST baseline names and the exported .wfw hash.
- Do not mutate built-in Windows rules just to add metadata tags.

<!-- LOCKIN:ToastRuntimeStability BEGIN -->
## Toast runtime stability: eliminate periodic console micro-flashes (LOCKED)

### Symptom
- A brief (~0.01–0.12s) console flash appeared every few minutes while idle.

### Root cause
- The Toast Watchdog periodically spawned the Toast Listener (or performed runtime checks) in a way that caused a visible console flash.
- Toast Listener could also exit with `LastTaskResult = 1` due to WinRT type resolution in Windows PowerShell 5.1.

### Fix (LOCKED)
1) **Watchdog no-flash behavior**
   - Watchdog must be fast-exit and **only start the Listener if it is not already running**.
   - When starting the Listener, enforce the hidden launch contract:
     - `powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File <Listener.ps1>`

2) **Toast Listener PS5.1 WinRT type resolution**
   - In Windows PowerShell 5.1, WinRT types must be referenced using WindowsRuntime ContentType.
   - Replace direct WinRT type references with:
     - `[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]`
   - Load `System.Runtime.WindowsRuntime` when available.

3) **Listener task instance policy**
   - `MultipleInstancesPolicy` must be `IgnoreNew` for the long-running listener.

### Verification (must pass)
Run:

```powershell
@(
  Get-ScheduledTaskInfo -TaskName "FirewallCore Toast Listener"
  Get-ScheduledTaskInfo -TaskName "FirewallCore Toast Watchdog"
) | Select-Object TaskName, LastRunTime, LastTaskResult, NextRunTime |
  Format-Table -AutoSize
Acceptance:

No periodic console flashes while idle.

Tasks run reliably; listener stays stable under normal operation.
<!-- LOCKIN:ToastRuntimeStability END -->


# === LOCKIN:InstallSignoffAndToastStability BEGIN ===
## Install signoff + toast runtime stability (LOCKED)

### Sprint
- This lock-in is part of **Sprint 2**.
- **Sprint 3** begins after Sprint 2 signoff and focuses on regression testing.

### Install signoff (VM)
- Entry point: `Install.cmd` (double-click → UAC → elevated install).
- Policy is applied during install and is not silent:
  - Output log: `C:\Firewall\Logs\Install\ApplyPolicy.log`
  - Optional lifecycle bundle export captures PRE/POST exports + SHA256 under:
    - `C:\ProgramData\FirewallCore\LifecycleExports\BUNDLE_INSTALL_*`

### Evidence (observed)
- PRE/POST SHA256 values differed across install when policy changed state.
- Rule inventory present after install (non-zero rule count).

### Toast runtime stability (console micro-flash eliminated)
**Symptom**
- Brief (~0.01–0.12s) console flash occurred periodically while idle.

**Fix (LOCKED)**
- Watchdog starts Listener **only if not already running**.
- Background tasks use hidden launch contract (`powershell.exe` with hidden window).
- Listener uses `MultipleInstancesPolicy = IgnoreNew` (long-running task safety).

### Verification commands (must pass)
```powershell
# Task health (TaskName accepts a single string; use ForEach for multiple tasks)
"FirewallCore Toast Listener","FirewallCore Toast Watchdog" |
  ForEach-Object { Get-ScheduledTaskInfo -TaskName $_ } |
  Select-Object TaskName, LastRunTime, LastTaskResult, NextRunTime |
  Format-Table -AutoSize

# Policy presence sanity check
(Get-NetFirewallRule | Measure-Object).Count

# Policy apply log visibility
Get-Content 'C:\Firewall\Logs\Install\ApplyPolicy.log' -Tail 80
```

### Acceptance
- No periodic console flashes while idle.
- Install produces non-silent policy apply logs and stable task execution.
# === LOCKIN:InstallSignoffAndToastStability END ===

