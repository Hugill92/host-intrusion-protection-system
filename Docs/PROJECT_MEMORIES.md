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



## Admin Panel: Export Baseline + Export Diagnostics — DONE (Maintenance-gated)

**Timestamp:** 2026-01-27 19:36

### Outcome
- Export Baseline + SHA256: **WORKING**
- Export Diagnostics Bundle: **WORKING**
- UI remains responsive during export/zip (no freeze observed)
- **Maintenance Mode enforcement:** exports are blocked when Maintenance Mode is OFF (popup shown), and allowed when ON

### Security / Gating Behavior
- When Maintenance Mode is **OFF**:
  - Clicking either export shows a warning popup and **does not create artifacts**
- When Maintenance Mode is **ON**:
  - Clicking exports creates the expected folder(s) and zip(s)

### Output Paths (current)
- Baselines:
  - C:\ProgramData\FirewallCore\Baselines\BASELINE_YYYYMMDD_HHMMSS\
  - C:\ProgramData\FirewallCore\Baselines\BASELINE_YYYYMMDD_HHMMSS.zip
- Diagnostics:
  - C:\ProgramData\FirewallCore\Diagnostics\DIAG_YYYYMMDD_HHMMSS\
  - C:\ProgramData\FirewallCore\Diagnostics\DIAG_YYYYMMDD_HHMMSS.zip

### Artifact Inventory (minimum)
**Baseline folder includes:**
- Firewall-Policy.wfw
- Firewall-Policy.wfw.sha256.txt
- Firewall-Rules.csv
- README.txt
- Zip of the folder

**Diagnostics folder includes:**
- systeminfo.txt
- ipconfig-all.txt
- whoami-all.txt
- Logs\AdminPanel-Actions.log (copied if present)
- 
otifyqueue_counts.json
- Zip of the folder

### Acceptance Checklist
- [x] Maintenance OFF blocks exports with popup
- [x] Maintenance ON allows exports
- [x] Exports produce both folder + zip
- [x] Multiple runs produce unique timestamped bundles
- [x] UI remains usable while zipping

### Notes / Follow-ups
- The current “Diagnostics” export contains system/environment collection (systeminfo/ipconfig/whoami). This is conceptually a **Support Bundle**.
- Proposed next step: move large collection export to:
  - C:\ProgramData\FirewallCore\SupportBundles\BUNDLE_YYYYMMDD_HHMMSS\ + .zip
  - Keep Diagnostics\ for app/runtime-only diagnostics (logs, queue health, etc.)


<!-- FIREWALLCORE_ADMINPANEL_BUNDLE_EXPORTS_20260127 BEGIN -->
## Admin Panel — Bundle exports hardened (Diagnostics + Support) (2026-01-27 23:28:56)

### What shipped / locked in ✅
- **Exports moved into Actions dropdown** (Quick Actions now only: **Open Logs** + **Open Event Viewer**).
- **Maintenance Mode gate enforced**:
  - Maintenance **OFF** → shows blocking popup (no export runs)
  - Maintenance **ON** → export executes and writes evidence paths + logs
- **Two distinct export intents (keep both)**:
  - **Export Diagnostics Bundle**: app/runtime diagnostics (logs, queue health, policy snapshot, etc.) → C:\ProgramData\FirewallCore\Diagnostics\DIAG_YYYYMMDD_HHMMSS.zip (or DIAG/BUNDLE naming as implemented)
  - **Export Support Bundle (ZIP)**: “send to support” package (safe for sharing with intent/controls) → C:\ProgramData\FirewallCore\SupportBundles\BUNDLE_YYYYMMDD_HHMMSS.zip

### Integrity + chain-of-custody 🛡️
- For every bundle export:
  - Create **folder manifest hash list**: hashes.sha256.txt (SHA256 per file, relative paths)
  - Create **zip hash**: <zipname>.sha256
- Log Start/Ok/Fail and evidence paths to C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log

### Option A — Confidential transport (v1) 🔒
- Support Bundle ZIP is **password-protected** using the **same Admin/Dev unlock password** used to enable Maintenance/Dev actions.
- If encryption tooling is unavailable on a target host, export must still succeed but clearly log:
  - Encryption=Skipped and why (dependency missing), and continue with hashing + warning text.

### Later (v2/v3)
- Replace password-based bundle encryption with **signing key / secure unlock** integration (hardware-backed unlock).
<!-- FIREWALLCORE_ADMINPANEL_BUNDLE_EXPORTS_20260127 END -->

