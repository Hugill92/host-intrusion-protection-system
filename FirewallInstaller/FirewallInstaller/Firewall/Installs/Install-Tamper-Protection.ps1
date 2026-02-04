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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC0lDekyhMn9joJ
# xhtl+FjUPppJEkAETG5z82RYQut+VaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
# YA1JZL+WI1Yn9crpsTANBgkqhkiG9w0BAQsFADAnMSUwIwYDVQQDDBxGaXJld2Fs
# bENvcmUgT2ZmbGluZSBSb290IENBMB4XDTI2MDIwMzA3NTU1N1oXDTI5MDMwOTA3
# NTU1N1owWDELMAkGA1UEBhMCVVMxETAPBgNVBAsMCFNlY3VyaXR5MRUwEwYDVQQK
# DAxGaXJld2FsbENvcmUxHzAdBgNVBAMMFkZpcmV3YWxsQ29yZSBTaWduYXR1cmUw
# WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATEFkC5IO0Ns0zPmdtnHpeiy/QjGyR5
# XcfYjx8wjVhMYoyZ5gyGaXjRBAnBsRsbSL172kF3dMSv20JufNI5SmZMo28wbTAJ
# BgNVHRMEAjAAMAsGA1UdDwQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNV
# HQ4EFgQUqbvNi/eHRRZJy7n5n3zuXu/sSOwwHwYDVR0jBBgwFoAULCjMhE2sOk26
# qY28GVmu4DqwehMwDQYJKoZIhvcNAQELBQADggEBAJsvjHGxkxvAWGAH1xiR+SOb
# vLKaaqVwKme3hHAXmTathgWUjjDwHQgFohPy7Zig2Msu11zlReUCGdGu2easaECF
# dMyiKzfZIA4+MQHQWv+SMcm912OjDtwEtCjNC0/+Q1BDISPv7OA8w7TDrmLk00mS
# il/f6Z4ZNlfegdoDyeDYK8lf+9DO2ARrddRU+wYrgXcdRzhekkBs9IoJ4qfXokOv
# u2ZvVZrPE3f2IiFPbmuBgzdbJ/VdkeCoAOl+D33Qyddzk8J/z7WSDiWqISF1E7GZ
# KSjgQp8c9McTcW15Ym4MR+lbyn3+CigGOrl89lzhMymm6rj6vSbvSMml2AEQgH0x
# ggE0MIIBMAIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IEtHEwdPxXA5lf91RyKPfIxzvWZt+hH9q8uJbMQ6u7ZOMAsGByqGSM49AgEFAARH
# MEUCIEYnovy74nRQc8+BKCdMOXylWTFZZM3UeAfHPzT+UVKSAiEAuixTzZF8yzWd
# cJQEO0CNvqmO5v7gaXXzw+ICAd89Tj8=
# SIG # End signature block
