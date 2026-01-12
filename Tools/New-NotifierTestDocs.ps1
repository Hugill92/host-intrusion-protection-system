[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [switch]$Force
)

$docsDir = Join-Path $RepoRoot "Docs"
New-Item -ItemType Directory -Path $docsDir -Force | Out-Null

function Write-Doc {
  param([string]$Path,[string]$Content,[switch]$Force)
  if ((Test-Path -LiteralPath $Path) -and -not $Force) {
    Write-Host "SKIP (exists): $Path  (use -Force to overwrite)" -ForegroundColor Yellow
    return
  }
  Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
  Write-Host "WROTE: $Path" -ForegroundColor Green
}

$eventSchemaPath = Join-Path $docsDir "EVENT_ID_SCHEMA.md"
$viewsPath       = Join-Path $docsDir "VIEWS.md"

$eventSchema = @"
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
- **Actor.ProcessName**: Image name (e.g. `powershell.exe`)
- **Actor.ProcessPath**: Full path when available
- **Actor.ProcessId**: PID when known
- **Actor.ParentProcessName** / **Actor.ParentProcessId**: Parent context (if known)
- **Actor.ServiceName**: If action occurred under a service
- **Actor.Hostname**: Machine name
- **Actor.Source**: Component emitting the event (e.g. `FirewallCore.Notifiers`, `FirewallCore.Pentest`)

Rules:
- Prefer stable **Source** and **ProcessPath** over fragile strings.
- If data is unknown, omit the field (don’t lie / don’t guess).
<!-- END: ActorAttribution -->
"@

$viewsDoc = @"
# FirewallCore Event Viewer Views

## Canonical view files
These views are shipped/staged to allow deterministic “Review Log” drill-down by severity and/or bands.

### Single EventId views
- `FirewallCore-EventId-3001.xml`
- `FirewallCore-EventId-4001.xml`
- `FirewallCore-EventId-9001.xml`

### Range views
- `FirewallCore-Range-3000-3999.xml` (Info band)
- `FirewallCore-Range-4000-4999.xml` (Warning band)
- `FirewallCore-Range-8000-8999.xml` (Test/Pentest band)
- `FirewallCore-Range-9000-9999.xml` (Critical band)

## Install-time staging targets
- `%ProgramData%\Microsoft\Event Viewer\Views`
- `%ProgramData%\FirewallCore\User\Views`

## Permissions (important)
Standard users must be able to **read** the XML in ProgramData view folders.
Use `Tools\Ensure-EventViewerViewAcl.ps1` after staging/copy.
"@

Write-Doc -Path $eventSchemaPath -Content $eventSchema -Force:$Force
Write-Doc -Path $viewsPath       -Content $viewsDoc   -Force:$Force
