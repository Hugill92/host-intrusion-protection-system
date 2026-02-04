# ===============================
# HOME OUTBOUND – CHUNK 1
# BLOCK Cast + File/Printer Sharing
# ===============================

$BlockOutboundRules = @(
    # ===== CAST TO DEVICE =====
    "Cast to Device functionality (qWave-TCP-Out)",
    "Cast to Device functionality (qWave-UDP-Out)",
    "Cast to Device streaming server (RTP-Streaming-Out)",

    # ===== FILE & PRINTER SHARING – ICMP =====
    "File and Printer Sharing (Echo Request - ICMPv4-Out)",
    "File and Printer Sharing (Echo Request - ICMPv6-Out)",

    # ===== FILE & PRINTER SHARING – DISCOVERY / SMB =====
    "File and Printer Sharing (LLMNR-UDP-Out)",
    "File and Printer Sharing (NB-Datagram-Out)",
    "File and Printer Sharing (NB-Name-Out)",
    "File and Printer Sharing (NB-Session-Out)",
    "File and Printer Sharing (SMB-Out)",

    # ===== RESTRICTIVE VARIANTS (OUTBOUND) =====
    "File and Printer Sharing (Restrictive) (Echo Request - ICMPv4-Out)",
    "File and Printer Sharing (Restrictive) (Echo Request - ICMPv6-Out)",
    "File and Printer Sharing (Restrictive) (LLMNR-UDP-Out)",
    "File and Printer Sharing (Restrictive) (SMB-Out)"
)

foreach ($rule in $BlockOutboundRules) {
    Set-NetFirewallRule `
        -DisplayName $rule `
        -Direction Outbound `
        -Action Block `
        -Enabled True `
        -Confirm:$false
}


# ===============================
# HOME OUTBOUND – CHUNK 2
# Block Remote Assistance, WMI,
# Media Sharing, P2P, RRAS
# ===============================

$BlockOutboundRules_Chunk2 = @(
    # ===== REMOTE ASSISTANCE =====
    "Remote Assistance (PNRP-Out)",
    "Remote Assistance (RA Server TCP-Out)",
    "Remote Assistance (SSDP TCP-Out)",
    "Remote Assistance (SSDP UDP-Out)",
    "Remote Assistance (TCP-Out)",

    # ===== ROUTING AND REMOTE ACCESS =====
    "Routing and Remote Access (GRE-Out)",
    "Routing and Remote Access (L2TP-Out)",
    "Routing and Remote Access (PPTP-Out)",

    # ===== WMI =====
    "Windows Management Instrumentation (WMI-Out)",

    # ===== WINDOWS MEDIA PLAYER NETWORK SHARING =====
    "Windows Media Player Network Sharing Service (HTTP-Streaming-Out)",
    "Windows Media Player Network Sharing Service (qWave-TCP-Out)",
    "Windows Media Player Network Sharing Service (qWave-UDP-Out)",
    "Windows Media Player Network Sharing Service (SSDP-Out)",
    "Windows Media Player Network Sharing Service (Streaming-TCP-Out)",
    "Windows Media Player Network Sharing Service (Streaming-UDP-Out)",
    "Windows Media Player Network Sharing Service (TCP-Out)",
    "Windows Media Player Network Sharing Service (UDP-Out)",
    "Windows Media Player Network Sharing Service (UPnPHost-Out)",
    "Windows Media Player Network Sharing Service (UPnP-Out)",

    # ===== WINDOWS PEER TO PEER =====
    "Windows Peer to Peer Collaboration Foundation (PNRP-Out)",
    "Windows Peer to Peer Collaboration Foundation (SSDP-Out)",
    "Windows Peer to Peer Collaboration Foundation (TCP-Out)",
    "Windows Peer to Peer Collaboration Foundation (WSD-Out)"
)

foreach ($rule in $BlockOutboundRules_Chunk2) {
    Set-NetFirewallRule `
        -DisplayName $rule `
        -Direction Outbound `
        -Action Block `
        -Enabled True `
        -Confirm:$false
}


# ===============================
# HOME OUTBOUND – CHUNK 3
# Block Wireless Display + WPD
# ===============================

$BlockOutboundRules_Chunk3 = @(
    # ===== WIRELESS DISPLAY =====
    "Wireless Display (TCP-Out)",
    "Wireless Display (UDP-Out)",

    # ===== WIRELESS PORTABLE DEVICES =====
    "Wireless Portable Devices (SSDP-Out)",
    "Wireless Portable Devices (TCP-Out)",
    "Wireless Portable Devices (UPnPHost-Out)",
    "Wireless Portable Devices (UPnP-Out)"
)

foreach ($rule in $BlockOutboundRules_Chunk3) {
    Set-NetFirewallRule `
        -DisplayName $rule `
        -Direction Outbound `
        -Action Block `
        -Enabled True `
        -Confirm:$false
}


# ===== TPM VIRTUAL SMART CARD (OUTBOUND BLOCK) =====
$TPMBlockOutbound = @(
    "TPM Virtual Smart Card Management (TCP-Out)"
)

Get-NetFirewallRule |
Where-Object {
    $_.Direction -eq 'Outbound' -and
    $TPMBlockOutbound -contains $_.DisplayName
} |
Set-NetFirewallRule -Action Block -Enabled True -Confirm:$false

Write-Host "Outbound Connections Blocked and Enabled"
# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBuqiw9DJxfz1Y5
# XzYyd0+d4lGPix96/UrHRNSxk4veOaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# INkIzt5PdZ7oxa+XHyxh2pTMm0+IXJWOLZjKWBJbClSsMAsGByqGSM49AgEFAARG
# MEQCIByebfkxGl8XStE7UhQnB+B+8gpF7Hs5ago9gFcRfe4lAiAmrvzW+QP3MD3I
# 71cLvlx9OQmDhHu5froxzPc4YjS0kw==
# SIG # End signature block
