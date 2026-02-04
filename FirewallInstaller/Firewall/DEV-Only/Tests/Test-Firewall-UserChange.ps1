param([switch]$DevMode = $true)


. "$PSScriptRoot\Test-Helpers.ps1"
# Test-Firewall-EventOnly.ps1
# Purpose: Validate Firewall Event Logging ONLY
# No self-heal dependency


. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Write-Host "[INFO] Simulate user firewall change (manual test)"



. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "C:\Firewall\Modules\Firewall-EventLog.ps1"

# Pick a stable rule
$rule = Get-NetFirewallRule |
    Where-Object { $_.Enabled -eq "True" -and $_.Action -eq "Allow" } |
    Select-Object -First 1 Name, Direction

if (-not $rule) {
    Write-FirewallEvent -EventId 9001 -Type Error -Message "No suitable firewall rule found for event-only test."
    exit 1
}

$ruleName  = $rule.Name
$direction = $rule.Direction

Write-FirewallEvent -EventId 9100 -Type Information `
    -Message "TEST START: Temporarily disabling firewall rule '$ruleName'. Direction: $direction."

Disable-NetFirewallRule -Name $ruleName

Write-FirewallEvent -EventId 9101 -Type Warning `
    -Message "TEST ACTION: Firewall rule '$ruleName' disabled for event test."

Start-Sleep -Seconds 10

Enable-NetFirewallRule -Name $ruleName

Write-FirewallEvent -EventId 9102 -Type Information `
    -Message "TEST COMPLETE: Firewall rule '$ruleName' re-enabled successfully."

exit 0

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAKws16wovVbQ6a
# XzrBd2eVoDzuxT+4HiHtEIg4rOy9Q6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IDQCWPIWFcLEVbHYdUo+RaFuaCQFzUIKlf1Y6uNQZc8UMAsGByqGSM49AgEFAARI
# MEYCIQDC04HKi4h2BnfHruob+PiAr4SSrhUEnuA6ut2xNx/CzAIhAMnMakX4gbMl
# pdvnKzjp9LBaRQ1dbQxN51hEutWWmFux
# SIG # End signature block
