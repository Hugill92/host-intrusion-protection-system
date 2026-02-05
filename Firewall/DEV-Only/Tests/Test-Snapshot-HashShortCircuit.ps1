<#
DEV TEST: Snapshot hash short-circuit
Validates that identical snapshots do NOT emit duplicate snapshot events
#>

param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
$ErrorActionPreference = "Stop"

# --- Bootstrap DEV paths ---
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Write-Host "[DEV] Testing snapshot hash short-circuit logic..."

# --- Import required modules ---
Import-Module "$ModulesDir\FirewallSnapshot.psm1" -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1" -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
. "$ModulesDir\Firewall-EventLog.ps1"

# --- Clear recent snapshot events ---
$startTime = Get-Date

# --- First snapshot (should emit event) ---
$snap1 = Get-FirewallSnapshot -Fast
$diff1 = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap1 `
    -Diff $diff1 `
    -Mode DEV `
    -RunId "DEV-HASH-TEST-1"

Start-Sleep -Seconds 2

# --- Second snapshot (no changes expected) ---
$snap2 = Get-FirewallSnapshot -Fast
$diff2 = Compare-FirewallSnapshots

try {
    Emit-FirewallSnapshotEvent `
        -Snapshot $snap2 `
        -Diff $diff2 `
        -Mode DEV `
        -RunId "DEV-HASH-TEST-2"
}
catch {
    # If the event layer rejects duplicate emits, that is acceptable as long as we do not log duplicates.
    Write-Warning ("Second snapshot emit threw (acceptable for short-circuit): " + $_)
}
Start-Sleep -Seconds 2

# --- Collect emitted snapshot events ---
$events = Get-WinEvent -FilterHashtable @{ LogName="Firewall"; StartTime=$startTime } -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -in 4100,4101,4102 -and $_.Message -like "*DEV-HASH-TEST-*" }

$eventCount = ($events | Measure-Object).Count

# --- Assert behavior ---
if ($eventCount -eq 1) {
    Write-TestPass "Snapshot hash short-circuit working (1 event emitted)"
}
else {
    Write-TestFail ("Expected 1 snapshot event, found " + $eventCount)
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCxqZ+2bYe7v/ET
# z0Jd1DCz6v2cJp1j0v3SPNN3Vk1Dp6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggE1MIIBMQIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IGEdpXnSTOmFGiwSdwIHfD2ZaTTWx3f4/9ej1+AGqqgCMAsGByqGSM49AgEFAARI
# MEYCIQDBqFr29pvfPnX4mYCKDIRyD/ScswqOmwpS/mnrvWjbbQIhAJhvxBHykYPt
# Kc4m+7C9EWmjIDBOp6oHjlxAMdQD1fDC
# SIG # End signature block
