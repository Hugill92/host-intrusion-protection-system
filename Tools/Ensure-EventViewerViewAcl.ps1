[CmdletBinding()]
param(
  [string[]]$Roots = @(
    (Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"),
    (Join-Path $env:ProgramData "FirewallCore\User\Views")
  ),
  [string]$Pattern = "FirewallCore-*.xml",
  [string]$Principal = "BUILTIN\Users",
  [switch]$WhatIf,
  [switch]$Strict
)

function Write-Log {
  param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray)
  Write-Host $Message -ForegroundColor $Color
}

$foundAny = $false
$changed = 0
$seen = 0

foreach ($root in $Roots) {
  if (-not (Test-Path -LiteralPath $root)) {
    Write-Log "SKIP: Root not found: $root" DarkGray
    continue
  }

  $files = Get-ChildItem -LiteralPath $root -File -Filter $Pattern -ErrorAction SilentlyContinue
  if (-not $files) {
    Write-Log "INFO: No matching files in: $root ($Pattern)" DarkGray
    continue
  }

  $foundAny = $true
  foreach ($f in $files) {
    $seen++
    Write-Log "CHECK: $($f.FullName)" Cyan

    # Always grant read; icacls is idempotent enough for our use case
    $grant = "${Principal}:(R)"

    if ($WhatIf) {
      Write-Log "WHATIF: icacls `"$($f.FullName)`" /grant `"$grant`"" Yellow
      continue
    }

    & icacls $f.FullName /grant "$grant" | Out-Null
    $changed++
    Write-Log "OK: granted $grant" Green
  }
}

if (-not $foundAny) {
  $msg = "No Event Viewer view files found for Pattern=$Pattern in Roots: $($Roots -join ', ')"
  if ($Strict) { throw $msg }
  Write-Log "WARN: $msg" Yellow
}

Write-Log ("DONE: files_seen={0} grants_applied={1}" -f $seen, $changed) Green
