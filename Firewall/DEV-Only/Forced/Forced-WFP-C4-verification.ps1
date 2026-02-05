param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "DEV"
)

Write-Host "Starting Forced-WFP-C4 test"

if ($Mode -ne "LIVE") {
    Write-Host "[FORCED-RESULT] SKIPPED"
    exit 0
}

# ---- Notification hook (v1, before exit) ----
try {
    Import-Module "C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop
    Send-FirewallNotification -Severity Critical -Title "WFP enforcement not active" -Message "LIVE WFP C4 validation failed - enforcement not wired." -Notify @("Popup","Event") -TestId "Forced-WFP-C4"
}
catch {
    # best-effort only
}

Write-Error "WFP C4 LIVE enforcement is not yet implemented."
Write-Host "[FORCED-RESULT] FAIL"
exit 1

# ---- v1 Notification Hook (import + call) ----
try {
    Import-Module "C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop

    Send-FirewallNotification `
        -Severity Critical `
        -Title "WFP enforcement not active" `
        -Message "LIVE WFP C4 validation failed ??? enforcement not wired." `
        -Notify @("Popup","Event") `
        -TestId "Forced-WFP-C4"
}
catch {
    # Notifications are best-effort only
}

# ---- v1 Notification Hook (import + call) ----
try {
    Import-Module "C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop

    Send-FirewallNotification `
        -Severity Critical `
        -Title "WFP enforcement not active" `
        -Message "LIVE WFP C4 validation failed ??? enforcement not wired." `
        -Notify @("Popup","Event") `
        -TestId "Forced-WFP-C4"
}
catch {
    # Notifications are best-effort only
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBE47PphBVLzEKk
# UKhhmSVLYO717anx4/pi4fTgmiDhH6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IP9sqA+9WSIfBAdHY7c/2+T9s7ILAn/1Em/EyooTdSGyMAsGByqGSM49AgEFAARI
# MEYCIQDNz+0lM7/Bw/DKssWrNh5sFKsPDyOjLYgZzJ6Hc+v6PwIhANXtnyg18/1a
# RbZDPeyBR/g9eQRB2RhQdq7wLu/xtu3X
# SIG # End signature block
