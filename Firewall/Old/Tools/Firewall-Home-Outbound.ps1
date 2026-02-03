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
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUjC8OlUIJd5bGxSPDCn27ZkCp
# 3CagggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBJDCCASACAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUc7t24sp78GYWW8qfl++7U3wUAdowCwYH
# KoZIzj0CAQUABEgwRgIhAI7GuxiLytjMn/jud4hkS/BhLmqxCXMhGTf2TQpUqZo5
# AiEAi1LAEG0U5h6WG2/D4v8zJw+pJ/E0GqipBSg5p7G8TbM=
# SIG # End signature block
