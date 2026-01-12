[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$docPath = Join-Path $RepoRoot "Docs\EVENT_ID_SCHEMA.md"
if (!(Test-Path -LiteralPath $docPath)) {
  throw "Missing $docPath. Run Tools\New-NotifierTestDocs.ps1 first."
}

$beginBands = "<!-- BEGIN: EventIdBands -->"
$endBands   = "<!-- END: EventIdBands -->"
$beginActor = "<!-- BEGIN: ActorAttribution -->"
$endActor   = "<!-- END: ActorAttribution -->"

$bandsBlock = @(
  $beginBands
  "| Band | Range | Severity / Meaning | Notes |"
  "|---:|---:|---|---|"
  "| 3000 | 3000–3999 | **Info** | Informational / baseline / allowed outcomes |"
  "| 4000 | 4000–4999 | **Warning** | Suspicious / needs review / policy drift |"
  "| 8000 | 8000–8999 | **Test / Pentest / Diagnostics** | Synthetic events used by test harness |"
  "| 9000 | 9000–9999 | **Critical** | Confirmed bad / requires manual review |"
  $endBands
) -join "`r`n"

$actorBlock = @(
  $beginActor
  "Recommended fields when emitting notifier payloads and/or audit logs:"
  ""
  "- **Actor.User**: Username / SID context when relevant"
  "- **Actor.ProcessName**: Image name (e.g. `powershell.exe`)"
  "- **Actor.ProcessPath**: Full path when available"
  "- **Actor.ProcessId**: PID when known"
  "- **Actor.ParentProcessName** / **Actor.ParentProcessId**: Parent context (if known)"
  "- **Actor.ServiceName**: If action occurred under a service"
  "- **Actor.Hostname**: Machine name"
  "- **Actor.Source**: Component emitting the event (e.g. `FirewallCore.Notifiers`, `FirewallCore.Pentest`)"
  ""
  "Rules:"
  "- Prefer stable **Source** and **ProcessPath** over fragile strings."
  "- If data is unknown, omit the field (don’t guess)."
  $endActor
) -join "`r`n"

function Upsert-Section {
  param([string]$Content,[string]$Begin,[string]$End,[string]$NewBlock,[switch]$Force)
  $b = [regex]::Escape($Begin)
  $e = [regex]::Escape($End)
  $pattern = "(?s)$b.*?$e"

  if ($Content -match $pattern) {
    return [regex]::Replace($Content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $NewBlock }, 1)
  }

  if (-not $Force) {
    throw "Missing required markers ($Begin / $End). Re-run with -Force to append them."
  }

  return ($Content.TrimEnd() + "`r`n`r`n" + $NewBlock + "`r`n")
}

$raw = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8

$updated = Upsert-Section -Content $raw -Begin $beginBands -End $endBands -NewBlock $bandsBlock -Force:$Force
$updated = Upsert-Section -Content $updated -Begin $beginActor -End $endActor -NewBlock $actorBlock -Force:$Force

$bak = "$docPath.bak_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item -LiteralPath $docPath -Destination $bak -Force

Set-Content -LiteralPath $docPath -Value $updated -Encoding UTF8
Write-Host "UPDATED: $docPath" -ForegroundColor Green
Write-Host "Backup : $bak" -ForegroundColor DarkGray
