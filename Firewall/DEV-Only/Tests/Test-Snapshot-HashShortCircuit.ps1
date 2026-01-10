<#
DEV TEST: Snapshot hash short-circuit
Validates that identical snapshots do NOT emit duplicate snapshot events
#>

param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
$ErrorActionPreference = "Stop"

# --- Bootstrap DEV paths ---
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Write-Host "[DEV] Testing snapshot hash short-circuit logic..."

# --- Import required modules ---
Import-Module "$ModulesDir\FirewallSnapshot.psm1" -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1" -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
. "$ModulesDir\Firewall-EventLog.ps1"

# --- Clear recent snapshot events ---
$startTime = Get-Date

# --- First snapshot (should emit event) ---
$snap1 = Get-FirewallSnapshot -Fast
$diff1 = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap1 `
    -Diff $diff1 `
    -Mode DEV `
    -RunId "DEV-HASH-TEST-1"

Start-Sleep -Seconds 2

# --- Second snapshot (no changes expected) ---
$snap2 = Get-FirewallSnapshot -Fast
$diff2 = Compare-FirewallSnapshots

try {
    Emit-FirewallSnapshotEvent `
        -Snapshot $snap2 `
        -Diff $diff2 `
        -Mode DEV `
        -RunId "DEV-HASH-TEST-2"
}
catch {
    # If the event layer rejects duplicate emits, that is acceptable as long as we do not log duplicates.
    Write-Warning ("Second snapshot emit threw (acceptable for short-circuit): " + $_)
}
Start-Sleep -Seconds 2

# --- Collect emitted snapshot events ---
$events = Get-WinEvent -FilterHashtable @{ LogName="Firewall"; StartTime=$startTime } -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -in 4100,4101,4102 -and $_.Message -like "*DEV-HASH-TEST-*" }

$eventCount = ($events | Measure-Object).Count

# --- Assert behavior ---
if ($eventCount -eq 1) {
    Write-TestPass "Snapshot hash short-circuit working (1 event emitted)"
}
else {
    Write-TestFail ("Expected 1 snapshot event, found " + $eventCount)
}
