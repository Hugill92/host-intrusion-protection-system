# Test-Snapshot-Event.ps1
param([switch]$DevMode = $true)



. "$PSScriptRoot\Test-Helpers.ps1"
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode

Import-Module "$ModulesDir\FirewallSnapshot.psm1" -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1" -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
. "$ModulesDir\Firewall-EventLog.ps1"

$snap = Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir
$diff = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap `
    -Diff $diff `
    -Mode DEV `
    -RunId "DEV-SNAPSHOT-TEST"
Write-TestPass "Snapshot event emitted"