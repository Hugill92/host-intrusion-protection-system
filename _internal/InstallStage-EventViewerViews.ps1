[CmdletBinding()]
param(
  # Path to the ACL tool (default repo-relative)
  [string]$AclTool = (Join-Path $PSScriptRoot "Ensure-EventViewerViewAcl.ps1"),

  # If you want to include View_#.xml cleanup/permissioning later
  [switch]$IncludeNumberedViewXml,

  # Fail hard if ACL application is skipped due to not being admin
  [switch]$RequireAdmin
)

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (!(Test-Path -LiteralPath $AclTool)) {
  throw "Missing ACL tool: $AclTool"
}

$evRoot = Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"
if (!(Test-Path -LiteralPath $evRoot)) {
  # Not an error: Event Viewer folder may not exist yet in some images; install can create it later
  Write-Warning "Event Viewer views folder not found yet: $evRoot"
}

$isAdmin = Test-IsAdmin
if ($RequireAdmin -and -not $isAdmin) {
  throw "RequireAdmin set but not running elevated."
}

# Run ACL tool in strict mode: nonzero exit is failure
$argList = @()
if ($IncludeNumberedViewXml) { $argList += "-IncludeNumberedViewXml" }

& powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $AclTool @argList
if ($LASTEXITCODE -ne 0) {
  throw "ACL tool failed with exit code $LASTEXITCODE"
}

Write-Host "Install-stage view ACL complete." -ForegroundColor Green
