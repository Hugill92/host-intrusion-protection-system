# Sprint 2 — Install Signoff (VM)

## Status
- PASS: Policy applied during install with PRE/POST export + SHA256 evidence; rule inventory present after install; toast micro-flash eliminated.

## Evidence checklist (operator)
- Double-click `Install.cmd` prompts UAC and runs elevated.
- `C:\Firewall\Logs\Install\ApplyPolicy.log` exists and contains policy apply output.
- Optional lifecycle bundle exists under `C:\ProgramData\FirewallCore\LifecycleExports\BUNDLE_INSTALL_*` with PRE/POST exports + SHA256.
- Task stability:
```powershell
"FirewallCore Toast Listener","FirewallCore Toast Watchdog" |
  ForEach-Object { Get-ScheduledTaskInfo -TaskName $_ } |
  Select-Object TaskName, LastRunTime, LastTaskResult, NextRunTime |
  Format-Table -AutoSize
```
- Rule count:
```powershell
(Get-NetFirewallRule | Measure-Object).Count
```
