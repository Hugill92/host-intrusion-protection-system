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
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSCommandPath" @args
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
            "-NoProfile",
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

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU8VhxpR2DTfpc6gkUrADUpLt/
# 6hOgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
# hvcNAQELBQAwJzElMCMGA1UEAwwcRmlyZXdhbGxDb3JlIE9mZmxpbmUgUm9vdCBD
# QTAeFw0yNjAyMDMwNzU1NTdaFw0yOTAzMDkwNzU1NTdaMFgxCzAJBgNVBAYTAlVT
# MREwDwYDVQQLDAhTZWN1cml0eTEVMBMGA1UECgwMRmlyZXdhbGxDb3JlMR8wHQYD
# VQQDDBZGaXJld2FsbENvcmUgU2lnbmF0dXJlMFkwEwYHKoZIzj0CAQYIKoZIzj0D
# AQcDQgAExBZAuSDtDbNMz5nbZx6Xosv0IxskeV3H2I8fMI1YTGKMmeYMhml40QQJ
# wbEbG0i9e9pBd3TEr9tCbnzSOUpmTKNvMG0wCQYDVR0TBAIwADALBgNVHQ8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFKm7zYv3h0UWScu5+Z98
# 7l7v7EjsMB8GA1UdIwQYMBaAFCwozIRNrDpNuqmNvBlZruA6sHoTMA0GCSqGSIb3
# DQEBCwUAA4IBAQCbL4xxsZMbwFhgB9cYkfkjm7yymmqlcCpnt4RwF5k2rYYFlI4w
# 8B0IBaIT8u2YoNjLLtdc5UXlAhnRrtnmrGhAhXTMois32SAOPjEB0Fr/kjHJvddj
# ow7cBLQozQtP/kNQQyEj7+zgPMO0w65i5NNJkopf3+meGTZX3oHaA8ng2CvJX/vQ
# ztgEa3XUVPsGK4F3HUc4XpJAbPSKCeKn16JDr7tmb1WazxN39iIhT25rgYM3Wyf1
# XZHgqADpfg990MnXc5PCf8+1kg4lqiEhdROxmSko4EKfHPTHE3FteWJuDEfpW8p9
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIjCCAR4CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUZoMdfgscWdEzoVcTinfF1ySehhIwCwYH
# KoZIzj0CAQUABEYwRAIgf5OM08S0eu48WJoH+PSmzL30QRJzh/qpX812xgZDZ9QC
# IAq1/C3CK38DReIf9BJ7XAJMFOw6qoBYfQ5JWtGDjHos
# SIG # End signature block
