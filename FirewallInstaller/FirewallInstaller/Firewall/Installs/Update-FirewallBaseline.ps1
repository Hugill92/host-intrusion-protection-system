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

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCvu5lKh+iIE4S/
# 2k/+WdxCXhNRzXbaSv57GWJdMPIuR6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggEzMIIBLwIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IAn16D/yGhXAM6jEfvkJZ6YyJQafaaF4mSYWoWXBLrdAMAsGByqGSM49AgEFAARG
# MEQCIBYa1E2k56mXqRNXpeUj2zpiJ37/QHoov8U/40CgPJRwAiBP0h357xcM6u5I
# N3UPz8oQy7HCDIXBQEntcjWQKohwuw==
# SIG # End signature block
