# FirewallCore Admin Panel — Stabilize Runtime + Align UI to Target Layout

## Context
Admin panel script: `C:\FirewallInstaller\Firewall\User\FirewallAdminPanel.ps1`
PowerShell: Windows PowerShell 5.1
Current failures observed:
- Repeated console spam from AsyncTimer tick: "Get-Command is not recognized" / missing helper function calls
- Checklist/refresh gate throws: variable `$state` not set
- Close button fails: `$btnClose` or `$win` is `$null` (wiring finds missing/renamed XAML element)
- Several Tests buttons show "Control missing" (XAML names mismatch or missing container wiring)

## Goals (Must-Haves)
### A) ZERO red spam / ZERO infinite refresh loops
- Timer tick must NEVER throw even if optional helpers are absent.
- Refresh/checklist pipeline must not reference `$state` unless it is initialized.
- Any periodic work must be guarded with:
  - `try/catch` around tick body
  - re-entrancy guard (prevent overlapping ticks)
  - explicit disable if critical deps missing

### B) Close button must always work
- If XAML defines `x:Name="BtnClose"` then script must bind:
  - click => `$win.Close()`
  - ESC key => `$win.Close()` (optional)
- If Close button cannot be resolved, log a single warning and continue without crashing.

### C) UI must match the target screenshot layout (to be implemented exactly)
- Implement the layout shown in user-provided screenshot(s) with arrows.
- Follow Phase-A design: checklist grid + actions + tests section + dev-mode gate.
- Ensure visual refresh does not cause cascading reflow or flicker after each row passes.

### D) No breaking changes / keep PS5.1 compatibility
- No PS7-only operators (`??`, etc.)
- No WinRT event subscriptions in PS5.1
- No backtick-in-double-quote markdown parser hazards in generator scripts

## Evidence / Repro
Observed console errors (examples):
- `Get-Command : The term 'Get-Command' is not recognized ...` inside AsyncTimer tick
- `$state cannot be retrieved because it has not been set`
- `$btnClose.Add_Click({ $win.Close() })` => null-valued expression

## Required Implementations

### 1) Add a strict “timer safe runner”
Create a single helper (or inline pattern) used by ALL timers:
- Re-entrancy guard: `$script:TickBusy = $true/$false`
- `try { ... } catch { log once per minute max } finally { $script:TickBusy=$false }`
- Tick must not call missing helpers; probe with `Get-Command` safely.

IMPORTANT: In this codebase, `Get-Command` must remain available.
If the function name `Get-Command` appears "not recognized", something is shadowing it.
Investigate and resolve any function/alias/variable named `Get-Command` or scoping that breaks command resolution.

### 2) Fix checklist state initialization
Before any refresh gate uses `$state`, ensure `$state` is initialized:
- `$state = [ordered]@{ ... }` or a dedicated state object
- Must exist before:
  - Invoke-Checklist
  - refresh gate
  - any background task processor

### 3) Fix Close binding robustly
- Resolve `$win` first (the Window object).
- Resolve Close button by known names:
  - `BtnClose`, `btnClose`, `CloseButton`, etc.
- If found: bind click to `$win.Close()`.
- Bind `KeyDown` handler on the Window to close on Escape (optional but desired).
- Must not introduce parsing errors; keep script syntactically valid.

### 4) Fix missing controls vs. XAML names
If script expects controls (Quick Health Check, Notification Demo, Drift Check, Inbound Allow Risk Report, etc):
- Ensure XAML defines those named controls OR script uses the correct names.
- Must eliminate "Control missing" warnings for intended features.

### 5) Logging
Write deterministic logs to:
`C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log`
Include:
- startup
- tick start/stop (rate limited)
- control binding success/fail (one-time)
- checklist start/stop outcomes

## Acceptance Criteria (PASS/FAIL)
PASS means all are true:
1) Launch produces NO repeating red exceptions.
2) UI renders and is interactive; Close works.
3) No infinite refresh loop.
4) Tests buttons exist (no "Control missing") OR are intentionally hidden with a clear reason.
5) Timer tick cannot crash the UI even if optional helpers are absent.
6) UI matches screenshot layout (pixel-approx ok; structure and placement must match).

## Files
- `Firewall\User\FirewallAdminPanel.ps1`
- any referenced XAML embedded inside the script

## Notes
- Avoid patching via regex replacement in production logic; implement actual fixes in source.
- Keep PS5.1 compatibility. 
