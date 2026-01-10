# Test-Diff.ps1
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode

Import-Module "$ModulesDir\FirewallSnapshot.psm1" -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1" -Force

Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir | Out-Null
Start-Sleep -Seconds 2
Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir | Out-Null

$diff = Compare-FirewallSnapshots

if (-not $diff -or -not $diff.DiffPath) {
    throw "Diff logic failed"
}

Write-Host "[OK] Diff created"
$diff | Format-List *
