[CmdletBinding(SupportsShouldProcess)]
param(
  # One or more directories that contain Event Viewer view XML files
  [string[]]$Roots = @(
    (Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"),
    (Join-Path $env:ProgramData "FirewallCore\User\Views")
  ),

  # Which views to touch
  [string]$Pattern = "FirewallCore-*.xml",

  # Principal that must be able to read the view XMLs
  [string]$Principal = "BUILTIN\Users",

  # Use (R) to be maximally compatible; Event Viewer reads fine with this.
  [ValidateSet("R","RX")]
  [string]$Right = "R"
)

$ErrorActionPreference = "Stop"

function Grant-Read([string]$FilePath) {
  $grant = "${Principal}:($Right)"
  if ($PSCmdlet.ShouldProcess($FilePath, "icacls /grant $grant")) {
    & icacls $FilePath /grant $grant | Out-Null
  }
}

$changed = 0
$missing = 0

foreach ($root in $Roots) {
  if (!(Test-Path -LiteralPath $root)) {
    Write-Host "SKIP (missing): $root" -ForegroundColor DarkGray
    $missing++
    continue
  }

  Write-Host "SCAN: $root" -ForegroundColor Cyan

  $files = Get-ChildItem -LiteralPath $root -File -Filter $Pattern -ErrorAction SilentlyContinue
  if (!$files) {
    Write-Host "  none matching $Pattern" -ForegroundColor DarkGray
    continue
  }

  foreach ($f in $files) {
    Grant-Read -FilePath $f.FullName
    $changed++
  }
}

Write-Host "DONE. Updated ACL on $changed file(s). Missing roots: $missing" -ForegroundColor Green
