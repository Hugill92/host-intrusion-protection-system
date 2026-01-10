# Deploy-Firewall.ps1
# Atomic redeploy of Firewall system from installer → live

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
$LiveRoot      = "C:\Firewall"

$TaskNames = @(
    "Firewall Core Monitor",
    "Firewall WFP Monitor"
)

Write-Output "[DEPLOY] Starting firewall redeploy..."

# Stop scheduled tasks if present
foreach ($t in $TaskNames) {
    try {
        if (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue) {
            Write-Output "[DEPLOY] Stopping task: $t"
            Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
        }
    } catch {}
}

# Ensure live root exists
if (!(Test-Path $LiveRoot)) {
    New-Item -ItemType Directory -Path $LiveRoot -Force | Out-Null
}

# Copy installer payload → live
Write-Output "[DEPLOY] Copying files to live directory..."
Copy-Item `
    -Path "$InstallerRoot\*" `
    -Destination $LiveRoot `
    -Recurse -Force

# Restart scheduled tasks
foreach ($t in $TaskNames) {
    try {
        if (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue) {
            Write-Output "[DEPLOY] Starting task: $t"
            Start-ScheduledTask -TaskName $t
        }
    } catch {}
}

Write-Output "[DEPLOY] Redeploy complete."
