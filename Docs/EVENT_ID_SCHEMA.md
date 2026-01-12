# FirewallCore Event ID Schema

This document defines the **EventId bands**, their meaning, and the **actor attribution** fields expected in notifier payloads / logs.

## EventId bands (canonical)

<!-- BEGIN: EventIdBands -->
| Band | Range | Severity / Meaning | Notes |
|---:|---:|---|---|
| 3000 | 3000–3999 | **Info** | Informational / baseline / allowed outcomes |
| 4000 | 4000–4999 | **Warning** | Suspicious / needs review / policy drift |
| 8000 | 8000–8999 | **Test / Pentest / Diagnostics** | Synthetic events used by test harness |
| 9000 | 9000–9999 | **Critical** | Confirmed bad / requires manual review |
<!-- END: EventIdBands -->

## Actor attribution (canonical)

<!-- BEGIN: ActorAttribution -->
Recommended fields when emitting notifier payloads and/or audit logs:

- **Actor.User**: Username / SID context when relevant
- **Actor.ProcessName**: Image name (e.g. powershell.exe)
- **Actor.ProcessPath**: Full path when available
- **Actor.ProcessId**: PID when known
- **Actor.ParentProcessName** / **Actor.ParentProcessId**: Parent context (if known)
- **Actor.ServiceName**: If action occurred under a service
- **Actor.Hostname**: Machine name
- **Actor.Source**: Component emitting the event (e.g. FirewallCore.Notifiers, FirewallCore.Pentest)

Rules:
- Prefer stable **Source** and **ProcessPath** over fragile strings.
- If data is unknown, omit the field (don’t guess).
<!-- END: ActorAttribution -->

