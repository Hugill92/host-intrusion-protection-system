param([switch]$DevMode = $true)



. "$PSScriptRoot\Test-Helpers.ps1"
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Import-Module "$ModulesDir\FirewallSnapshot.psm1" -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1" -Force

Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir | Out-Null
Start-Sleep 1
Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir | Out-Null

$diff = Compare-FirewallSnapshots

if (-not $diff.DiffPath -or -not (Test-Path $diff.DiffPath)) {
    Write-TestFail "Diff not created"
}
Write-TestPass "Diff created"
$diff | Format-List *
