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
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUcbs0QYMfEEay0pnDleuIko+j
# hOygggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU/H1Lzung0dg/ErGFo0PvYnzjXQIwCwYH
# KoZIzj0CAQUABEcwRQIgZmWw54r0lEdShwWYSkfuTcehzoptsnO3IHeG5WWJW2EC
# IQCveomdmSUNPmm8smYwENdKGSwZCSfWawOxgzXQVsKUeg==
# SIG # End signature block
