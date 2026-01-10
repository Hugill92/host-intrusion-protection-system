$BlockRules = @(
    # ===== CAST / MEDIA =====
    "Cast to Device functionality (qWave-TCP-In)",
    "Cast to Device functionality (qWave-UDP-In)",
    "Cast to Device SSDP Discovery (UDP-In)",
    "Cast to Device streaming server (HTTP-Streaming-In)",
    "Cast to Device streaming server (RTCP-Streaming-In)",
    "Cast to Device streaming server (RTSP-Streaming-In)",
    "Cast to Device UPnP Events (TCP-In)",

    # ===== FILE & PRINTER SHARING =====
    "File and Printer Sharing (LLMNR-UDP-In)",
    "File and Printer Sharing (NB-Datagram-In)",
    "File and Printer Sharing (NB-Name-In)",
    "File and Printer Sharing (NB-Session-In)",
    "File and Printer Sharing (SMB-In)",
    "File and Printer Sharing (Spooler Service - RPC)",
    "File and Printer Sharing (Spooler Service - RPC-EPMAP)",
    "File and Printer Sharing (Spooler Service Worker - RPC)",

    # Restrictive + ICMP
    "File and Printer Sharing (Restrictive) (Echo Request - ICMPv4-In)",
    "File and Printer Sharing (Restrictive) (Echo Request - ICMPv6-In)",
    "File and Printer Sharing (Restrictive) (LLMNR-UDP-In)",
    "File and Printer Sharing (Restrictive) (SMB-In)",
    "File and Printer Sharing (Restrictive) (Spooler Service - RPC)",
    "File and Printer Sharing (Restrictive) (Spooler Service - RPC-EPMAP)",
    "File and Printer Sharing (Restrictive) (Spooler Service Worker - RPC)",
    "File and Printer Sharing over SMBDirect (iWARP-In)",

    # ===== MEDIA CENTER / WMP =====
    "Media Center Extenders - HTTP Streaming (TCP-In)",
    "Media Center Extenders - Media Streaming (TCP-In)",
    "Media Center Extenders - qWave (TCP-In)",
    "Media Center Extenders - qWave (UDP-In)",
    "Media Center Extenders - RTSP (TCP-In)",
    "Media Center Extenders - SSDP (UDP-In)",
    "Media Center Extenders - WMDRM-ND/RTP/RTCP (UDP-In)",
    "Media Center Extenders - XSP (TCP-In)",

    "Windows Media Player Network Sharing Service (HTTP-Streaming-In)",
    "Windows Media Player Network Sharing Service (qWave-TCP-In)",
    "Windows Media Player Network Sharing Service (qWave-UDP-In)",
    "Windows Media Player Network Sharing Service (SSDP-In)",
    "Windows Media Player Network Sharing Service (Streaming-UDP-In)",
    "Windows Media Player Network Sharing Service (TCP-In)",
    "Windows Media Player Network Sharing Service (UDP-In)",
    "Windows Media Player Network Sharing Service (UPnP-In)",

    # ===== REMOTE DESKTOP / ASSISTANCE =====
    "Remote Desktop - Shadow (TCP-In)",
    "Remote Desktop - User Mode (TCP-In)",
    "Remote Desktop - User Mode (UDP-In)",
    "Remote Desktop - (TCP-WS-In)",
    "Remote Desktop - (TCP-WSS-In)",

    "Remote Assistance (DCOM-In)",
    "Remote Assistance (PNRP-In)",
    "Remote Assistance (RA Server TCP-In)",
    "Remote Assistance (SSDP TCP-In)",
    "Remote Assistance (SSDP UDP-In)",
    "Remote Assistance (TCP-In)",

    # ===== REMOTE MANAGEMENT =====
    "Remote Event Log Management (NP-In)",
    "Remote Event Log Management (RPC)",
    "Remote Event Log Management (RPC-EPMAP)",
    "Remote Event Monitor (RPC)",
    "Remote Event Monitor (RPC-EPMAP)",
    "Remote Scheduled Tasks Management (RPC)",
    "Remote Scheduled Tasks Management (RPC-EPMAP)",
    "Remote Service Management (NP-In)",
    "Remote Service Management (RPC)",
    "Remote Service Management (RPC-EPMAP)",
    "Inbound Rule for Remote Shutdown (RPC-EP-In)",
    "Inbound Rule for Remote Shutdown (TCP-In)",

    # ===== DISK / SYSTEM =====
    "Remote Volume Management - Virtual Disk Service (RPC)",
    "Remote Volume Management - Virtual Disk Service Loader (RPC)",
    "Remote Volume Management (RPC-EPMAP)",
    "Performance Logs and Alerts (DCOM-In)",
    "Performance Logs and Alerts (TCP-In)",
    "iSCSI Service (TCP-In)",
    "Routing and Remote Access (GRE-In)",
    "Routing and Remote Access (L2TP-In)",
    "Routing and Remote Access (PPTP-In)",
    "TPM Virtual Smart Card Management (DCOM-In)",
    "TPM Virtual Smart Card Management (TCP-In)",
    "Virtual Machine Monitoring (DCOM-In)",
    "Virtual Machine Monitoring (RPC)",

    # ===== PEER / DISCOVERY =====
    "Proximity sharing over TCP (TCP sharing-In)",
    "Windows Collaboration Computer Name Registration Service (PNRP-In)",
    "Windows Collaboration Computer Name Registration Service (SSDP-In)",
    "Windows Peer to Peer Collaboration Foundation (PNRP-In)",
    "Windows Peer to Peer Collaboration Foundation (SSDP-In)",
    "Windows Peer to Peer Collaboration Foundation (TCP-In)",
    "Windows Peer to Peer Collaboration Foundation (WSD-In)",

    # ===== FIREWALL REMOTE MGMT =====
    "Windows Defender Firewall Remote Management (RPC)",
    "Windows Defender Firewall Remote Management (RPC-EPMAP)",

    # ===== WMI =====
    "Windows Management Instrumentation (ASync-In)",
    "Windows Management Instrumentation (DCOM-In)",
    "Windows Management Instrumentation (WMI-In)",

    # ===== WINRM =====
    "Windows Remote Management (HTTP-In)"
	"Windows Remote Management - Compatibility Mode (HTTP-In)"
	"Windows Remote Management - Compatibility Mode (HTTP-In)"
)

Get-NetFirewallRule |
Where-Object { $BlockRules -contains $_.DisplayName } |
Set-NetFirewallRule -Action Block -Enabled True -Confirm:$false


Write-Host "HOME profile applied - remote management fully blocked."
# ===== FORCE BLOCK VM MONITORING INBOUND =====
$VmRules = @(
    "Virtual Machine Monitoring (Echo Request - ICMPv4-In)",
    "Virtual Machine Monitoring (Echo Request - ICMPv6-In)",
    "Virtual Machine Monitoring (NB-Session-In)"
)

foreach ($rule in $VmRules) {
    Set-NetFirewallRule -DisplayName $rule -Action Block -Enabled True -Confirm:$false
}
# ===== ALLOW BASIC ICMP (PING) FOR FILE & PRINTER SHARING =====
$AllowIcmpRules = @(
    "File and Printer Sharing (Echo Request - ICMPv4-In)",
    "File and Printer Sharing (Echo Request - ICMPv6-In)",
    "Wireless Display (TCP-In)",
    "Wireless Display Infrastructure Back Channel (TCP-In)"
)

foreach ($rule in $AllowIcmpRules) {
    Set-NetFirewallRule -DisplayName $rule -Action Block -Enabled True -Confirm:$false
}
Set-NetFirewallRule -DisplayName "SNMP Trap Service (UDP In)" -Action Block -Enabled True

Set-NetFirewallRule -DisplayName "Key Management Service (TCP-In)" -Action Block -Enabled True
# SNMP Trap Service (not needed on home systems)
Set-NetFirewallRule -DisplayName "SNMP Trap Service (UDP In)" `
    -Action Block -Enabled True -Confirm:$false

# Key Management Service (enterprise KMS only)
Set-NetFirewallRule -DisplayName "Key Management Service (TCP-In)" `
    -Action Block -Enabled True -Confirm:$false

# DIAL protocol server (Chromecast / smart TV discovery)
Set-NetFirewallRule -DisplayName "DIAL protocol server (HTTP-In)" `
    -Action Block -Enabled True -Confirm:$false


Write-Host "Inbound Connections Blocked and Enabled"

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUcbs0QYMfEEay0pnDleuIko+j
# hOygggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU/H1Lzung0dg/ErGFo0PvYnzjXQIwDQYJ
# KoZIhvcNAQEBBQAEggEASMvNqXIs2bnLFL5AHdGAchMHr8dcheuyNtSkZ6AePD6u
# q8qynKLsoHd9eWwweZqv3V2x79giRaElw6GwnjM6A5HjPNT6QDUHNz9Aq1tpMv2p
# k57Qx0sbjBuI1PHzOkncBfaOKtRvF659bLYei2GclFS8qggo7XUBsBvwPzb96+cY
# L9NSz9B6uxC+KFjqK5UeLt72j0TsiY4pl5IjtDA6JhfK+A29rVrNHfIaKNQMRwjv
# PWFwQiKgagw62TkD+ggfBOsbhGPo2n4mEIOXA2coffMD59EQ68Fin/gNXmdbheqt
# ZCJa2tLxL4QemrUO5VO4Je2dfLeH9MBQiedpgnopvg==
# SIG # End signature block
