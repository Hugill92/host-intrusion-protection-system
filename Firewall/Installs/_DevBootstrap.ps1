param(
    [switch]$DevMode
)

if (-not $DevMode) {
    return
}

# Root of installer tree
$global:RootDir = "C:\FirewallInstaller\Firewall"

# Core directories (DEV-SAFE)
$global:ModulesDir  = Join-Path $RootDir "Modules"
$global:InstallsDir = Join-Path $RootDir "Installs"
$global:SnapshotDir = Join-Path $RootDir "Snapshots"
$global:StateDir    = Join-Path $RootDir "State"
$global:LogDir      = Join-Path $RootDir "Logs"
$global:DiffDir     = Join-Path $RootDir "Diff"

# Ensure DEV directories exist
foreach ($dir in @(
    $ModulesDir,
    $InstallsDir,
    $SnapshotDir,
    $StateDir,
    $LogDir,
    $DiffDir
)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Write-Host "[DEV] Bootstrap loaded from installer tree" -ForegroundColor Cyan
