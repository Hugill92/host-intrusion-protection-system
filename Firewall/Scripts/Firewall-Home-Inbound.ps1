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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBnbFkSIIXLDZcd
# 4waJ4O1BJQbKJUu4ADo8nV+/5VZrXaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IIVf+R5gC6i93LjwXdxYEeKDCKGTyCfwOT0JooKcJ27/MAsGByqGSM49AgEFAARH
# MEUCIQCKWtUeuBK6eiTqAJqYMMx9Co+Tol1hfllwDsGTvjOWbAIgUuDnjWNT6lJx
# Nel2jfSWMD4gprZoQfBdgJP0jlPGUio=
# SIG # End signature block
