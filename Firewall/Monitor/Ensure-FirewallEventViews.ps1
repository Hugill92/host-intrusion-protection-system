# Ensures all FirewallCore Event Viewer Custom Views are registered
# by copying XML query files into ProgramData EV Views folder.

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

$src = "C:\FirewallInstaller\Firewall\Monitor\EventViews"
$dst = "C:\ProgramData\Microsoft\Event Viewer\Views"

if (-not (Test-Path $src)) {
    Write-Host "[WARN] Source EventViews folder missing: $src"
    exit 0
}

New-Item -ItemType Directory -Path $dst -Force | Out-Null

Get-ChildItem $src -Filter "*.xml" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $dst $_.Name) -Force
    Write-Host "[OK] Registered EV View: $($_.Name)"
}
