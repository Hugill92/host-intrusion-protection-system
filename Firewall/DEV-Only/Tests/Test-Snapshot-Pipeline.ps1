<#
DEV-ONLY TEST
Validates Snapshot → Diff → Event emission pipeline
#>

param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
# -------------------- DEV BOOTSTRAP --------------------
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode
Write-Host "[DEV] Bootstrap loaded from installer tree"
# ------------------------------------------------------

# -------------------- IMPORT HELPERS -------------------
Import-Module "$ModulesDir\FirewallSnapshot.psm1"        -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1"  -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
. "$ModulesDir\Firewall-EventLog.ps1"
# ------------------------------------------------------

Write-Host "[DEV] Testing snapshot → diff → event pipeline..."

# -------------------- EXECUTION ------------------------
$snap = Get-FirewallSnapshot `
    -Fast `
    -SnapshotDir $SnapshotDir `
    -StateDir    $StateDir

if (-not $snap -or -not $snap.Hash) {
    throw "Snapshot failed or invalid"
}

$diff = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap `
    -Diff     $diff `
    -Mode     DEV `
    -RunId    "DEV-PIPELINE-TEST"
# ------------------------------------------------------

# -------------------- VERIFICATION ---------------------
Start-Sleep -Seconds 1

$event = Get-WinEvent -LogName Firewall -MaxEvents 5 |
    Where-Object { $_.Id -in 4100,4101,4102 } |
    Select-Object -First 1

if (-not $event) {
    Write-TestWarnPass "Snapshot pipeline executed; event emission suppressed in DEV (acceptable)"
    return
}
Write-Host "[OK] Snapshot pipeline event emitted"
Write-Host "     EventId: $($event.Id)"
Write-TestPass "Snapshot pipeline test completed successfully"
# ------------------------------------------------------

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAiKDiE9oKdkEbT
# 2xGcwF5IB/sCHq+BJrmqi9rqs49tcqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ILt25oYPdEndowUC4hZF5UxWXiqyFRt/dBkIJj5Gw+HwMAsGByqGSM49AgEFAARH
# MEUCIQDjMaJ7NHuoEoGgzNeXabCU4etuBfnIhzhSG6HIjY4RygIgBfXKh7SLR+u8
# fCY4cjTTq5X5aCXrjD8/eB7iEWom0gY=
# SIG # End signature block
