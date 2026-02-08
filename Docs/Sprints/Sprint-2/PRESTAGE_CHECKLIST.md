# Sprint 2 - Prestage Checklist (Install/Uninstall Seamless Deploy)

- Updated: 2026-01-12 14:03:02
- Purpose: ensure a clean install/uninstall cycle on a fresh machine with no repo-path dependencies.

## Gate 1 - Repo-path bleed (must be zero)
- Run:
  - `git grep -n "C:\\FirewallInstaller\\" -- _internal Install.cmd Uninstall.cmd Tools`
- Acceptance:
  - No scheduled task actions or runtime paths reference the repo root.

## Gate 2 - Install outputs (must exist after install)
### Live scripts
- `C:\Firewall\User\FirewallToastListener.ps1`
- `C:\Firewall\User\FirewallToastListener-Runner.ps1`
- `C:\Firewall\System\FirewallToastWatchdog.ps1`

### Sounds
- `C:\Firewall\Sounds\ding.wav`
- `C:\Firewall\Sounds\chimes.wav`
- `C:\Firewall\Sounds\chord.wav`

### ProgramData (installer-owned)
- `C:\ProgramData\FirewallCore\...` (only owned artifacts required for runtime)

### Protocol handler
- `HKLM:\Software\Classes\firewallcore-review` exists

### Event log
- `FirewallCore` event log exists (and providers are bound)

## Gate 3 - Scheduled tasks (must be deterministic)
- `Firewall-Defender-Integration`
- `FirewallCore Toast Listener`
- `FirewallCore Toast Watchdog`

Acceptance:
- Task action Arguments is a single string (PS5.1-safe).
- Task action includes `-WindowStyle Hidden` and `-NonInteractive` where applicable.
- Task action `-File` points to `C:\Firewall\...` live paths.

## Gate 4 - Uninstall removes owned artifacts (idempotent)
Acceptance:
- Tasks removed across all TaskPaths.
- Protocol handler removed (HKLM and HKCU if used).
- No toast listener processes remain (`powershell.exe` command lines).
- ProgramData owned folder removed or archived per contract.
- Uninstall safe to run twice with OK/WARN logs (no hard failures).

## Evidence capture (attach to sprint notes / PR)
- Install log path(s)
- Uninstall log path(s)
- Task action dumps:
  - `(Get-ScheduledTask -TaskName "...").Actions | Format-List *`
- Running PowerShell processes:
  - `Get-CimInstance Win32_Process | ? Name -eq "powershell.exe" | select ProcessId,CommandLine`
- Event log check:
  - `Get-WinEvent -ListLog "FirewallCore"`

