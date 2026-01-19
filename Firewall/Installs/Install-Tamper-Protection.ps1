<#
Install-Tamper-Protection.ps1

Purpose:
- Registers the scheduled task that runs the tamper check on a cadence.
- Supports DEV (installer sandbox) and LIVE (C:\Firewall) modes.
- Auto-elevates in LIVE mode.
- Does NOT sign anything. (Signing happens later.)
#>

param(
    [switch]$DevMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ================= EXECUTION POLICY SELF-BYPASS =================
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Error "Constrained language mode detected. Exiting."
    exit 1
}

if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass') {
    powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "$PSCommandPath" @args
    exit $LASTEXITCODE
}
# =================================================================

# ================== DEV / INSTALLER MODE ==================
# NEVER remove this section
# Controls whether script operates on LIVE system or INSTALLER sandbox

if ($DevMode) {
    $Root        = "C:\FirewallInstaller\Firewall"
    $ModulesDir  = Join-Path $Root "Modules"
    $StateDir    = Join-Path $Root "State"
    $Snapshots   = Join-Path $Root "Snapshots"
    $DiffDir     = Join-Path $Root "Diff"
    $LogsDir     = Join-Path $Root "Logs"
    $IsLive      = $false
} else {
    $Root        = "C:\Firewall"
    $ModulesDir  = Join-Path $Root "Modules"
    $StateDir    = Join-Path $Root "State"
    $Snapshots   = Join-Path $Root "Snapshots"
    $DiffDir     = Join-Path $Root "Diff"
    $LogsDir     = Join-Path $Root "Logs"
    $IsLive      = $true
}

# Safety guard + auto-elevate in LIVE
if ($IsLive) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-WindowStyle", "Hidden",
            "-ExecutionPolicy", "Bypass",
            "-File", "`"$PSCommandPath`""
        )
        exit
    }
}
# ==========================================================

# Ensure dirs exist (safe)
foreach ($d in @($Root,$ModulesDir,$StateDir,$Snapshots,$DiffDir,$LogsDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# Load event log helper (must exist in modules dir)
$eventLogHelper = Join-Path $ModulesDir "Firewall-EventLog.ps1"
if (Test-Path $eventLogHelper) {
    . $eventLogHelper
} else {
    Write-Warning "Event log helper missing: $eventLogHelper (continuing without events)"
}

# The actual tamper check script should live in the SAME root tree
# DEV => installer tree, LIVE => C:\Firewall tree
$tamperCheckPath = Join-Path $Root "Monitor\Firewall-Tamper-Check.ps1"
if (-not (Test-Path $tamperCheckPath)) {
    throw "Tamper check script not found: $tamperCheckPath"
}

# Scheduled task action:
# Always calls the tamper check under SYSTEM with explicit -DevMode when in DEV.
$argList = @(
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-NonInteractive",
    "-WindowStyle", "Hidden",
    "-File", "`"$tamperCheckPath`""
)

if ($DevMode) {
    $argList += "-DevMode"
}

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ($argList -join " ")

# Trigger: every 10 minutes indefinitely (use Daily repetition to satisfy Task Scheduler schema)
$Trigger = New-ScheduledTaskTrigger -Daily -At (Get-Date).Date.AddMinutes(1)
$Trigger.RepetitionInterval = New-TimeSpan -Minutes 10
$Trigger.RepetitionDuration = New-TimeSpan -Days 3650  # ~10 years (effectively "forever")

$Settings = New-ScheduledTaskSettingsSet `
    -Hidden `
    -Compatibility Win8 `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

$TaskName = "Firewall Tamper Guard"

# Replace existing task cleanly
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -User "SYSTEM" `
    -RunLevel Highest | Out-Null

if (Get-Command Write-FirewallEvent -ErrorAction SilentlyContinue) {
    Write-FirewallEvent -EventId 5200 -Type Information -Message "Tamper Protection installed. Mode=$([string]::Join('',@('LIVE','DEV')[$DevMode.IsPresent])) Task='$TaskName' Script='$tamperCheckPath'"
}

Write-Host "[OK] Installed scheduled task: $TaskName"
Write-Host "     Mode: " + ($(if ($DevMode) { "DEV (installer tree)" } else { "LIVE (C:\Firewall)" }))
Write-Host "     Script: $tamperCheckPath"
