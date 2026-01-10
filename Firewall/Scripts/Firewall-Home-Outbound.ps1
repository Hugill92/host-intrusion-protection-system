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
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUjC8OlUIJd5bGxSPDCn27ZkCp
# 3CagggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
# AQsFADAkMSIwIAYDVQQDDBlGaXJld2FsbENvcmUgQ29kZSBTaWduaW5nMB4XDTI2
# MDEwNTE4NTkwM1oXDTI3MDEwNTE5MTkwM1owJDEiMCAGA1UEAwwZRmlyZXdhbGxD
# b3JlIENvZGUgU2lnbmluZzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# AO9vgGkuxnRNQ6dCFa0TeSA8dI6C3aapCB6GSxZB+3OZNMqvmYxZGZ9g4vZVtjJ4
# 6Ffulr3b/KUcxQRiSj9JlFcUB39uWHCZYpGfPlpA9JXiNJuwPNAaWdG1S5DnjLXh
# QH0PAGJH/QSYfVzVLf6yrAW5ID30Dz14DynBbVAQuM7iuOdTu9vhdcoAi37T9O4B
# RjflfXjaDDWfZ9nyF3X6o5Z5pUmC2mUKuTXc9iiUGkWQoLe3wGDQBWZxgTONOr6s
# d1EfeQ2OI6PPoM54iqv4s2offPxl2jBd2aESkT+MK88e1iQGRLT8CC3IMKEvWb4q
# sY0jodjxx/EFW7YvmMmM+aUCAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBTz2KaYa/9Nh8LQ78T5DHApaEhuYzAN
# BgkqhkiG9w0BAQsFAAOCAQEAxu2SpjRshKTSAWeQGtiCWbEVP7OT02vnkSfX7kr0
# bSkyKXaizhA6egp6YWdof86uHLyXRny28sQSMzRqIW7zLFqouvoc83CF4GRexPqH
# cwt55G2YU8ZbeFJQPpfVx8uQ/JIsTyaXQIo6fhBdm4qAA20K+H214C8JL7oUiZzu
# L+CUHFsSbvjx4FyAHVmkRSlRbrqSgETbwcMMB1corkKY990uyOJ6KHBXTd/iZLZi
# Lg4e2mtfV7Jn60ZlzO/kdOkYZTxv2ctNVRnzP3bD8zTjagRvvp7OlNJ6MSUZuJPJ
# 1Cfikoa43Cqw6BN0tLRP80UKTFB484N3bgGU9UAqCKeckDGCAdkwggHVAgEBMDgw
# JDEiMCAGA1UEAwwZRmlyZXdhbGxDb3JlIENvZGUgU2lnbmluZwIQJzQwIFZoAq5J
# jY+vZKoYnzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUc7t24sp78GYWW8qfl++7U3wUAdowDQYJ
# KoZIhvcNAQEBBQAEggEAMH4R1TMplQJp4lmk8ufryYtxqX/r4HiC8hWwMcqyXpRC
# RReSCp4sae2BFHUv6PA9l0hShshW9aKbq3xwZ+FMFg+kp95Wtvh/NbnYytiqb8j6
# 5ESdp2RKdOe19P1JIO7pUsLJehD2MkWrt4yCPNdqhcv+wlKNfUqSD3WxGwCe2YMo
# E9mDfhegwyGhNzrqDWgNYj32OIK8HvchRrtoOMvpMlVQDi4ovtL63Exlp3SFP01E
# PVAt5fkmo/wbWe/mOQNmYga3Xk0ovZpwL9gAX7cxJVHuRiDEm4j5dbPKikx7PmAT
# 1xblNvwjg+Zdtf7YkX/sSqEWPZiQ3AJH7C3pGuVmRA==
# SIG # End signature block
