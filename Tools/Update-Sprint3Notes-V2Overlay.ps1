[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$PreBundle,
  [Parameter(Mandatory)][string]$PostBundle,
  [Parameter(Mandatory)][string]$AuditPath,
  [string]$SprintNotesPath = "C:\FirewallInstaller\Docs\Sprints\Sprint-3\SPRINT_3_NOTES.md",
  [string]$VmName = $env:COMPUTERNAME
)

$ErrorActionPreference = "Stop"
$NL = [Environment]::NewLine
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$dir = Split-Path -Parent $SprintNotesPath
New-Item -ItemType Directory -Path $dir -Force | Out-Null

if (-not (Test-Path -LiteralPath $SprintNotesPath)) {
  Set-Content -LiteralPath $SprintNotesPath -Encoding UTF8 -Value ("# Sprint 3 Notes" + $NL)
}

$block = @()
$block += ""
$block += "## V2 overlay hardening inside V1 scope (locked)"
$block += ""
$block += ("Logged: **" + $stamp + "** | VM: **" + $VmName + "**")
$block += ""
$block += "Decision:"
$block += "- Proceed with V2 hardening as **overlay-only** within V1 policy scope."
$block += "- Overlay contract: **Enabled + Block only** (never Disable + Allow; never weaken base rules)."
$block += "- Overlay ownership: Group tag stays **FirewallCorev2** (stable)."
$block += "- \"True V2 scope\" (refactor/consolidation/import/ownership overhaul) is deferred until install/uninstall/repair + regression suites are green."
$block += ""
$block += "Evidence:"
$block += ("- PRE bundle: `"${PreBundle}`"")
$block += ("- POST bundle: `"${PostBundle}`"")
$block += ("- Audit gate: `"${AuditPath}`"")
$block += ""
$block += "Pipeline (repeatable):"
$block += "- PRE bundle → apply overlay → POST bundle → Audit-OverlayChange PASS → manual spot-check"
$block += ""

Add-Content -LiteralPath $SprintNotesPath -Encoding UTF8 -Value ($block -join $NL)
Write-Host ("Updated Sprint 3 notes: " + $SprintNotesPath) -ForegroundColor Green
