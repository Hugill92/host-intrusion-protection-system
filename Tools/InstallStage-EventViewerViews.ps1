[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [switch]$Strict
)

$ErrorActionPreference = "Stop"

$src = Join-Path $RepoRoot "Firewall\Monitor\EventViews"
if (!(Test-Path -LiteralPath $src)) { throw "Missing views source: $src" }

$destCore = Join-Path $env:ProgramData "FirewallCore\User\Views"
$destEV   = Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"

New-Item -ItemType Directory -Path $destCore, $destEV -Force | Out-Null

# Copy all FirewallCore*.xml (EventId + Range views)
Copy-Item -Path (Join-Path $src "FirewallCore-*.xml") -Destination $destCore -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $src "FirewallCore-*.xml") -Destination $destEV   -Force -ErrorAction SilentlyContinue

# Ensure ACLs so non-admin Review Log doesn't hit Access Denied
$aclTool = Join-Path $RepoRoot "Tools\Ensure-EventViewerViewAcl.ps1"
& $aclTool -Directories @($destEV, $destCore) -Pattern "FirewallCore-*.xml" -Strict:$Strict
