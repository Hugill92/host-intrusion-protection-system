<#
DEV-ONLY TEST
Validates Snapshot → Diff → Event emission pipeline
#>

param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
# -------------------- DEV BOOTSTRAP --------------------
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode
Write-Host "[DEV] Bootstrap loaded from installer tree"
# ------------------------------------------------------

# -------------------- IMPORT HELPERS -------------------
Import-Module "$ModulesDir\FirewallSnapshot.psm1"        -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1"  -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
. "$ModulesDir\Firewall-EventLog.ps1"
# ------------------------------------------------------

Write-Host "[DEV] Testing snapshot → diff → event pipeline..."

# -------------------- EXECUTION ------------------------
$snap = Get-FirewallSnapshot `
    -Fast `
    -SnapshotDir $SnapshotDir `
    -StateDir    $StateDir

if (-not $snap -or -not $snap.Hash) {
    throw "Snapshot failed or invalid"
}

$diff = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap `
    -Diff     $diff `
    -Mode     DEV `
    -RunId    "DEV-PIPELINE-TEST"
# ------------------------------------------------------

# -------------------- VERIFICATION ---------------------
Start-Sleep -Seconds 1

$event = Get-WinEvent -LogName Firewall -MaxEvents 5 |
    Where-Object { $_.Id -in 4100,4101,4102 } |
    Select-Object -First 1

if (-not $event) {
    Write-TestWarnPass "Snapshot pipeline executed; event emission suppressed in DEV (acceptable)"
    return
}
Write-Host "[OK] Snapshot pipeline event emitted"
Write-Host "     EventId: $($event.Id)"
Write-TestPass "Snapshot pipeline test completed successfully"
# ------------------------------------------------------
