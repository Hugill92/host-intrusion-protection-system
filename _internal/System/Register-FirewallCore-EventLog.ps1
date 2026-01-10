# Register-FirewallCore-EventLog.ps1
# Ensures one dedicated log: FirewallCore
# Ensures all FirewallCore.* sources are bound to that log (repairable)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

$LogName = "FirewallCore"
$Sources = @(
  "FirewallCore-Core",
  "FirewallCore-Pentest",
  "FirewallCore-Notifier"
)

function Get-SourceBoundLog([string]$SourceName) {
  $root = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog"
  $logs = Get-ChildItem $root -ErrorAction SilentlyContinue
  foreach ($l in $logs) {
    $p = Join-Path $l.PSPath $SourceName
    if (Test-Path $p) { return $l.PSChildName }
  }
  return $null
}

# Ensure log exists
if (-not [System.Diagnostics.EventLog]::Exists($LogName)) {
  New-EventLog -LogName $LogName -Source $Sources[0]
}

# Ensure each source is bound to FirewallCore (repair if bound elsewhere)
foreach ($s in $Sources) {
  $bound = Get-SourceBoundLog $s
  if ($bound -and $bound -ne $LogName) {
    try { [System.Diagnostics.EventLog]::DeleteEventSource($s) } catch {}
  }
  if (-not [System.Diagnostics.EventLog]::SourceExists($s)) {
    New-EventLog -LogName $LogName -Source $s
  }
}

Write-Host "[OK] FirewallCore Event Log ready (sources bound)"
