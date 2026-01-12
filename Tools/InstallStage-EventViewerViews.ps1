[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$SourceDir = "Firewall\Monitor\EventViews",
  [switch]$FixAcl,
  [switch]$Strict
)

function Write-Log {
  param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray)
  Write-Host $Message -ForegroundColor $Color
}

$src = Join-Path $RepoRoot $SourceDir
if (-not (Test-Path -LiteralPath $src)) {
  throw "Missing source views directory: $src"
}

$dstUser = Join-Path $env:ProgramData "FirewallCore\User\Views"
$dstEv   = Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"

New-Item -ItemType Directory -Path $dstUser -Force | Out-Null
New-Item -ItemType Directory -Path $dstEv   -Force | Out-Null

$views = Get-ChildItem -LiteralPath $src -File -Filter "FirewallCore-*.xml" | Sort-Object Name
if (-not $views) {
  $msg = "No view files found in $src (FirewallCore-*.xml)"
  if ($Strict) { throw $msg }
  Write-Log "WARN: $msg" Yellow
  exit 0
}

Write-Log "STAGE: copying $($views.Count) views from:" Cyan
Write-Log "  $src" DarkGray
Write-Log "TO:" Cyan
Write-Log "  $dstUser" DarkGray
Write-Log "  $dstEv" DarkGray

foreach ($v in $views) {
  Copy-Item -LiteralPath $v.FullName -Destination (Join-Path $dstUser $v.Name) -Force
  Copy-Item -LiteralPath $v.FullName -Destination (Join-Path $dstEv   $v.Name) -Force
}

Write-Log "DONE: staged view files." Green

if ($FixAcl) {
  $aclTool = Join-Path $RepoRoot "Tools\Ensure-EventViewerViewAcl.ps1"
  if (-not (Test-Path -LiteralPath $aclTool)) { throw "Missing ACL tool: $aclTool" }
  Write-Log "ACL: applying read grants to staged views..." Cyan
  pwsh -NoProfile -ExecutionPolicy Bypass -File $aclTool -Strict:$Strict
  Write-Log "ACL: complete." Green
} else {
  Write-Log "ACL: skipped (run with -FixAcl to apply read grants)." DarkGray
}
