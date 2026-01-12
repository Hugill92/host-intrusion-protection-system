[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Strict
)

$ErrorActionPreference = 'Stop'

$src = Join-Path $RepoRoot 'Firewall\Monitor\EventViews'
if (!(Test-Path -LiteralPath $src)) {
  throw "Source views folder missing: $src"
}

$evViews   = Join-Path $env:ProgramData 'Microsoft\Event Viewer\Views'
$coreViews = Join-Path $env:ProgramData 'FirewallCore\User\Views'

New-Item -ItemType Directory -Path $evViews   -Force | Out-Null
New-Item -ItemType Directory -Path $coreViews -Force | Out-Null

$files = Get-ChildItem -LiteralPath $src -Filter '*.xml' -File -ErrorAction Stop
if ($files.Count -eq 0) { throw "No *.xml files found in: $src" }

foreach ($f in $files) {
  Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $evViews   $f.Name) -Force
  Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $coreViews $f.Name) -Force
}

# ACL pass (Users read) — avoids “Access denied” when a toast action tries to open a view
$aclTool = Join-Path $RepoRoot 'Tools\Ensure-EventViewerViewAcl.ps1'
& $aclTool -Path $evViews, $coreViews -Filter 'FirewallCore*.xml' -Strict:$Strict

Write-Host "Install-stage complete: Event Viewer views staged + ACL ensured." -ForegroundColor Green
