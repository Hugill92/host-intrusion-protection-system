# Verify-Installer.ps1
# Verifies installer-side modules and logic only

# ================== DEV / INSTALLER MODE ==================
# NEVER remove this section
# Controls whether script operates on LIVE system or INSTALLER sandbox

param(
    [switch]$DevMode
)

if ($DevMode) {
    $Root        = "C:\FirewallInstaller\Firewall"
    $ModulesDir  = "$Root\Modules"
    $StateDir    = "$Root\State"
    $Snapshots   = "$Root\Snapshots"
    $DiffDir     = "$Root\Diff"
    $LogsDir     = "$Root\Logs"
    $IsLive      = $false
} else {
    $Root        = "C:\Firewall"
    $ModulesDir  = "$Root\Modules"
    $StateDir    = "$Root\State"
    $Snapshots   = "$Root\Snapshots"
    $DiffDir     = "$Root\Diff"
    $LogsDir     = "$Root\Logs"
    $IsLive      = $true
}

# Safety guard
if ($IsLive -and -not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Live mode requires elevation"
}
# ==========================================================


Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstallerRoot = "C:\FirewallInstaller\Firewall"

Write-Output "=== VERIFY INSTALLER ==="

# Import modules from installer only
Import-Module "$InstallerRoot\Modules\FirewallSnapshot.psm1" -Force
Import-Module "$InstallerRoot\Modules\Diff-FirewallSnapshots.psm1" -Force
. "$InstallerRoot\Modules\Firewall-EventLog.ps1"

Write-Output "[VERIFY] Modules imported successfully"

# Snapshot test (installer context)
$snapshot = Get-FirewallSnapshot -Fast -SnapshotDir "$InstallerRoot\Snapshots"

if (-not $snapshot.Path) {
    throw "Snapshot failed"
}

Write-Output "[VERIFY] Snapshot OK"
Write-Output "  Path : $($snapshot.Path)"
Write-Output "  Hash : $($snapshot.Hash)"
Write-Output "  Rules: $($snapshot.RuleCount)"

# Diff test
$diff = Compare-FirewallSnapshots `
    -SnapshotDir "$InstallerRoot\Snapshots" `
    -DiffDir "$InstallerRoot\Diff"

if ($diff) {
    Write-Output "[VERIFY] Diff OK"
    Write-Output "  Added   : $($diff.AddedCount)"
    Write-Output "  Removed : $($diff.RemovedCount)"
    Write-Output "  Modified: $($diff.ModifiedCount)"
} else {
    Write-Output "[VERIFY] Diff skipped (not enough snapshots)"
}

# Event emission test (noisy but safe)
Write-FirewallEvent `
    -EventId 4099 `
    -Type Information `
    -Message "Installer verification test event"

Write-Output "=== VERIFY COMPLETE ==="
