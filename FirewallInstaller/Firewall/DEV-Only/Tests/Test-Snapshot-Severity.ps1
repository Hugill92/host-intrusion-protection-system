param([switch]$DevMode = $true)



. "$PSScriptRoot\Test-Helpers.ps1"
# =========================================
# DEV Bootstrap (installer-safe)
# =========================================
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Write-Host "[DEV] Testing snapshot severity escalation..."

# =========================================
# Imports
# =========================================
Import-Module "$ModulesDir\FirewallSnapshot.psm1" -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1" -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
. "$ModulesDir\Firewall-EventLog.ps1"

# =========================================
# Baseline snapshot (no change expected)
# =========================================
$snap1 = Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir
Start-Sleep -Seconds 2
$snap2 = Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir
$diff  = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap2 `
    -Diff $diff `
    -Mode DEV `
    -RunId "DEV-SEVERITY-NOCHANGE"

# =========================================
# Verify 4100
# =========================================
$info = Get-WinEvent -LogName Firewall -MaxEvents 5 |
    Where-Object { $_.Id -eq 4100 -and $_.Message -like "*DEV-SEVERITY-NOCHANGE*" }

if (-not $info) {
    Write-TestFail "Expected Information (4100) event not found"
}

Write-Host "[OK] Information severity verified (4100)"

# =========================================
# Create TEMP rule (Added → Error)
# =========================================
$ruleName = "DEV-SEVERITY-ADD-TEST"

New-NetFirewallRule `
    -Name $ruleName `
    -DisplayName "DEV Severity Add Test" `
    -Direction Outbound `
    -Action Allow `
    -Program "$env:SystemRoot\System32\notepad.exe" | Out-Null

Start-Sleep -Seconds 2

$snap3 = Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir
$diff2 = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap3 `
    -Diff $diff2 `
    -Mode DEV `
    -RunId "DEV-SEVERITY-ADD"

$err = Get-WinEvent -LogName Firewall -MaxEvents 5 |
    Where-Object { $_.Id -eq 4102 -and $_.Message -like "*DEV-SEVERITY-ADD*" }

if (-not $err) {
    Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
    Write-TestFail "Expected Error (4102) event not found"
}

Write-Host "[OK] Error severity verified (4102)"

# =========================================
# Cleanup
# =========================================
Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue

Write-TestPass "Snapshot severity escalation test completed successfully"

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCLk22fU1YAbrYu
# Ic6yAuAbAlBxr1oTQHSJxxtGh1P0KaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# INH/Yg4yfod+qI9yhDNlUOuywnRPqJO9QkbHV+hFF+KSMAsGByqGSM49AgEFAARG
# MEQCIB+ShHD8N+uaFv2jJbiBdJjIiqRmCVr8zENHgMcKkxjAAiBFsQ3Razz2FV+p
# xx7Exb7nHcrV6viQXZl1JUEyL2VdWA==
# SIG # End signature block
