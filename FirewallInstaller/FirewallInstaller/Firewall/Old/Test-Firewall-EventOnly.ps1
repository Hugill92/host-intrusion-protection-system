# Test-Firewall-EventOnly.ps1
# Purpose: Validate Firewall Event Logging ONLY
# No self-heal dependency

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "C:\Firewall\Modules\Firewall-EventLog.ps1"

# Pick one enabled rule
$rule = Get-NetFirewallRule |
    Where-Object Enabled -eq True |
    Select-Object -First 1 Name, Direction

if (-not $rule) {
    Write-FirewallEvent -EventId 9001 -Type Error -Message "No enabled firewall rule found for test."
    exit 1
}

$ruleName = $rule.Name
$direction = $rule.Direction

# Log start
Write-FirewallEvent `
    -EventId 9100 `
    -Type Information `
    -Message "TEST START: Temporarily disabling firewall rule '$ruleName'. Direction: $direction."

# Disable rule
Disable-NetFirewallRule -Name $ruleName

Write-FirewallEvent `
    -EventId 9101 `
    -Type Warning `
    -Message "TEST ACTION: Firewall rule '$ruleName' disabled for event test."

# Wait briefly
Start-Sleep -Seconds 10

# Re-enable rule
Enable-NetFirewallRule -Name $ruleName

Write-FirewallEvent `
    -EventId 9102 `
    -Type Information `
    -Message "TEST COMPLETE: Firewall rule '$ruleName' re-enabled successfully."

exit 0

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCChwLI7VFQtql2f
# kAgoomr1pCpaKbXzr1Zj/gZO6w5cwaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ICrMR6Lj9HY/ODw+dQH8Qgr9VU57KY6kRQa6XQWImPUGMAsGByqGSM49AgEFAARH
# MEUCIF0Y1qT13s4szPfAJa5pI7bTxXjVS3l76QUchKDoUAjNAiEAjZWeY6mSc7af
# Q+yhhTw3I2izeTzUHjNJIFyEllzSZLg=
# SIG # End signature block
