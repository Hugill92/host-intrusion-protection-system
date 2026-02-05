# Uninstall Engine Contract (FirewallCore v1)

## Goals
- PowerShell 5.1 compatible
- ExecutionPolicy AllSigned compatible
- Deterministic logging: Windows Event Log + durable file log per run
- Idempotent: repeated runs are NOOP and do not error
- No policy regression: do not modify `Firewall/Policy` artifacts

## Modes
### Default
- Remove installed runtime components (tasks/services/files as applicable)
- Preserve ProgramData evidence (logs/baselines/exports)

### Clean
- Requires `-ForceClean`
- Executes Default actions, then purges `C:\ProgramData\FirewallCore` as final step
- Optional: remove FirewallCore event log definition (Clean only)

## Logging
- Always write a run log to `C:\ProgramData\FirewallCore\Logs\...`
- Emit event log entries to the dedicated `FirewallCore` Windows Event Log

## Gates (required before merging)
1) Parse gate (0 parser errors)
2) PS5.1 gate (no PS7-only syntax)
3) ScheduledTaskAction gate (-Argument single string)
4) Signing gate (re-sign changed scripts and verify Status=Valid)
5) Run gate (DEV run under AllSigned)

