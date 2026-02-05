# PR: Uninstall V2 — Default vs Clean Behavior, Logging, and Verification

## Goals
- Keep **current working behavior** intact (Default uninstall preserves firewall policy; Clean uninstall removes everything and resets to Windows defaults).
- Make uninstall **deterministic** and **auditable**: consistent Event Viewer entries, consistent log paths, and a repeatable verification ledger.
- Harden reliability: uninstall must be resilient to **file locks**, **transcript quirks**, and **AllSigned** policy.

## Scope
This spec targets:
- `Tools\Uninstall\Uninstall-FirewallCore.ps1` (entrypoint)
- `\_internal\Uninstall-FirewallCore.ps1` (installer-tree runner, if applicable)
- Supporting uninstall modules/scripts under `Firewall\Installs\` / `Firewall\Modules\` as used by uninstall

Out of scope (for this PR):
- Redesigning policy engine or baseline format
- Changing rule group naming (must remain `FirewallCorev1` / `FirewallCorev2` / `FirewallCorev3`)
- Changing certificate/signing workflow beyond ensuring AllSigned safety

---

## Behavior Contract

### Modes
#### Mode=Default (standard uninstall)
**Intent:** remove FirewallCore runtime + tasks + binaries while **preserving** the system's firewall policy state.

**Must:**
- Remove install root (e.g., `C:\Firewall`) if it exists.
- Stop/disable/remove FirewallCore scheduled tasks:
  - `FirewallCore-ToastListener`
  - `FirewallCore Toast Watchdog`
  - (any other `FirewallCore*` tasks if present)
- Remove optional integration tasks owned by FirewallCore (e.g., `Firewall-Defender-Integration`) **only if created by installer**.
- Preserve `C:\ProgramData\FirewallCore` (logs + evidence), unless explicitly asked to remove logs.
- **Do NOT** reset Windows Firewall policy to defaults.
- Emit clear EVTX and file logs.

#### Mode=Clean (clean uninstall / remove everything)
**Intent:** remove everything and restore Windows firewall policy to a known-good default.

**Must:**
- Everything in **Mode=Default**, plus:
- Remove FirewallCore rule groups (`FirewallCorev1/v2/v3`) and any other installer-owned firewall artifacts.
- Restore Windows Firewall policy to the baseline default state.
  - Preferred: restore from a captured **WinDefault/DEFAULT** baseline taken on that machine (if present).
  - Acceptable fallback: `netsh advfirewall reset` (documented + logged).
- Remove (or optionally archive) `C:\ProgramData\FirewallCore` depending on `-KeepLogs` (default for clean is usually **remove**, but keep log bundle output).
- Remove FirewallCore Event Log **only if** user passes explicit `-RemoveEventLog` / `-PurgeEventLog` (default: keep for audit).
- Emit clear EVTX and file logs.

### Safe defaults
- `Uninstall.cmd` → Mode=Default
- `Uninstall-Clean.cmd` → Mode=Clean + `-ForceClean`
- Clean must require an explicit operator intent (e.g., `-ForceClean`) to reduce accidental policy resets.

---

## Logging Contract

### Log locations (file)
All uninstall runs must write:
- Primary: `C:\ProgramData\FirewallCore\Logs\Uninstall-FirewallCore_<MODE>_<YYYYMMDD_HHMMSS>.log`
- Transcript: `...\Uninstall-FirewallCore_<MODE>_<...>_transcript.log` (if transcript used)

**File lock resilience (must):**
- Uninstall must never fail just because it cannot append to its own log.
- Logging implementation must tolerate:
  - transcript file open/locked
  - operator tailing log in another process
- If `Add-Content` fails due to file-in-use, retry with backoff, or fall back to:
  - `Write-EventLog` (EVTX) and/or
  - a secondary log file (e.g., `Uninstall-FirewallCore_<...>_fallback.log`)

### Event Viewer (EVTX)
- Provider: `FirewallCore-Installer` (or existing installer provider)
- Channel: `FirewallCore` (custom log)
- Messages use consistent **CamelCase labels** to match Windows built-in logs style:
  - Example: `Mode=Clean`, `User=Owner`, `Computer=...`, `Admin=True`, `Result=Ok`

---

## Event ID Continuity and Allocation

### What “good” looks like
- IDs are **stable** (same meaning forever).
- IDs are **monotonic within each operation** (BEGIN → step → END).
- IDs do **not** need to be globally contiguous across Windows—only coherent within FirewallCore.

### Recommended allocation (realistic, expandable)
Use **blocks of 50** (not 100) to keep things tight while leaving room for growth:

- **Install:** `1000–1049`
- **Repair/SelfHeal/Reinstall:** `1050–1079`
- **Uninstall (Default):** `1100–1149`
- **Uninstall (Clean):** `1150–1199`
- **Verification / PostCheck ledger:** `1200–1249`
- **Reserved / future:** `1250–1299`

Rationale: provider-defined IDs are not required to be sequential; block sizing is an internal convention. citeturn2view0turn4view0

### Minimal required IDs (V2)
#### Install (sample; existing IDs may already be in use)
- `1000` BEGIN
- `1010` PolicyApplied + BaselinesCaptured
- `1020` TasksRegistered
- `1049` END (Result=Ok/Warn/Fail)

#### Uninstall Default
- `1100` BEGIN (Mode=Default)
- `1110` StopTasks (Ok/Warn)
- `1120` RemoveInstallRoot (Ok/Warn)
- `1130` PreserveProgramData (Ok)
- `1140` PreserveFirewallPolicy (Ok)
- `1149` END (Result=Ok/Warn/Fail)

#### Uninstall Clean
- `1150` BEGIN (Mode=Clean)
- `1160` StopTasks (Ok/Warn)
- `1170` RemoveFirewallCoreRuleGroups (Ok/Warn/Fail)
- `1180` RestoreFirewallPolicyDefault (Ok/Warn/Fail) + Method=(Baseline|NetshReset)
- `1190` RemoveProgramDataState (Ok/Warn) + KeepLogs=(True/False)
- `1199` END (Result=Ok/Warn/Fail)

---

## Verification Ledger (Admin Panel ready)
The Admin Panel will later run the same verification steps and present PASS/FAIL with evidence paths.

### Post-uninstall verification checks
1) **Tasks**
- `Get-ScheduledTask | ? TaskName -like "FirewallCore*"`
- `Get-ScheduledTask -TaskName "Firewall-Defender-Integration" -EA SilentlyContinue`

2) **Paths**
- `Test-Path C:\Firewall` (must be False)
- `Test-Path C:\ProgramData\FirewallCore`:
  - Default uninstall: True (expected)
  - Clean uninstall: False unless `-KeepLogs`

3) **Firewall rules**
- Count rules in groups `FirewallCorev1/v2/v3`
  - Default uninstall: allowed to remain (policy preserved)
  - Clean uninstall: must be 0

4) **Firewall policy reset**
- Clean uninstall must show evidence of baseline restore or `netsh advfirewall reset` having run.

5) **Event log**
- `wevtutil el | findstr /i "FirewallCore"` should still show `FirewallCore` unless `-RemoveEventLog`.

6) **Logs**
- Uninstall log exists under ProgramData log path (or exported bundle path if clean removes ProgramData).

### Ledger output format
- Each check logs a row:
  - `CheckName`, `Expected`, `Observed`, `Result`, `EvidencePath` (when applicable)

---

## Constraints (non-negotiable)
- **PS 5.1 compatible** (no `??`, `.Where()`, etc.)
- **AllSigned-safe**: all invoked scripts/modules must be signed, and task actions must use the hidden launch contract.
- ScheduledTask action `-Argument` must be **one string** (no arrays).
- Keep public docs free of any AI/model references.

---

## Acceptance Criteria
- Default uninstall:
  - Removes FirewallCore runtime and tasks, preserves firewall policy, leaves ProgramData by default.
- Clean uninstall:
  - Removes FirewallCore runtime, tasks, ProgramData (unless KeepLogs), **and** restores firewall defaults.
- Both modes:
  - Produce deterministic EVTX entries (CamelCase labels) and file logs.
  - Do not fail due to file locks on their own logs.
  - Pass the verification ledger checks.

