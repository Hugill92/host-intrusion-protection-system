param([switch]$DevMode = $true)



. "$PSScriptRoot\Test-Helpers.ps1"
# =========================================
# DEV Bootstrap (installer-safe)
# =========================================
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Write-Host "[DEV] Testing snapshot severity escalation..."

# =========================================
# Imports
# =========================================
Import-Module "$ModulesDir\FirewallSnapshot.psm1" -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1" -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
. "$ModulesDir\Firewall-EventLog.ps1"

# =========================================
# Baseline snapshot (no change expected)
# =========================================
$snap1 = Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir
Start-Sleep -Seconds 2
$snap2 = Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir
$diff  = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap2 `
    -Diff $diff `
    -Mode DEV `
    -RunId "DEV-SEVERITY-NOCHANGE"

# =========================================
# Verify 4100
# =========================================
$info = Get-WinEvent -LogName Firewall -MaxEvents 5 |
    Where-Object { $_.Id -eq 4100 -and $_.Message -like "*DEV-SEVERITY-NOCHANGE*" }

if (-not $info) {
    Write-TestFail "Expected Information (4100) event not found"
}

Write-Host "[OK] Information severity verified (4100)"

# =========================================
# Create TEMP rule (Added → Error)
# =========================================
$ruleName = "DEV-SEVERITY-ADD-TEST"

New-NetFirewallRule `
    -Name $ruleName `
    -DisplayName "DEV Severity Add Test" `
    -Direction Outbound `
    -Action Allow `
    -Program "$env:SystemRoot\System32\notepad.exe" | Out-Null

Start-Sleep -Seconds 2

$snap3 = Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir
$diff2 = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap3 `
    -Diff $diff2 `
    -Mode DEV `
    -RunId "DEV-SEVERITY-ADD"

$err = Get-WinEvent -LogName Firewall -MaxEvents 5 |
    Where-Object { $_.Id -eq 4102 -and $_.Message -like "*DEV-SEVERITY-ADD*" }

if (-not $err) {
    Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
    Write-TestFail "Expected Error (4102) event not found"
}

Write-Host "[OK] Error severity verified (4102)"

# =========================================
# Cleanup
# =========================================
Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue

Write-TestPass "Snapshot severity escalation test completed successfully"
