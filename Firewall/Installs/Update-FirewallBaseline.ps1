# Update-FirewallBaseline.ps1
# Admin-only baseline update tool

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

$LiveStateDir = "C:\Firewall\State"
$BaselinePath = Join-Path $LiveStateDir "baseline.json"
$HashPath     = Join-Path $LiveStateDir "baseline.hash"
$OverrideTok  = Join-Path $LiveStateDir "admin-override.token"

if (!(Test-Path $OverrideTok)) {
    throw "Admin override token missing. Baseline update blocked."
}

Import-Module "C:\Firewall\Modules\FirewallSnapshot.psm1" -Force

Write-Output "[BASELINE] Capturing full snapshot..."

$snapshot = Get-FirewallSnapshot

# Persist baseline
Copy-Item $snapshot.Path $BaselinePath -Force

# Hash baseline
$hash = (Get-FileHash $BaselinePath -Algorithm SHA256).Hash
Set-Content -Path $HashPath -Value $hash -Encoding ascii

Write-Output "[BASELINE] Updated successfully"
Write-Output "  Baseline : $BaselinePath"
Write-Output "  Hash     : $hash"
