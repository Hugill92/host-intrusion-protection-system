# ==========================================================
# FIREWALL HOME PROFILE – INBOUND + OUTBOUND HARDENING
# ==========================================================
# • Blocks selected inbound and outbound Windows firewall rules
# • Enables rules and sets Action = Block
# • Silent / MSI-safe / Idempotent
# ==========================================================

# -------------------------------
# INBOUND RULES TO BLOCK
# -------------------------------
$InboundBlockRules = @(
    # Cast to Device
    "Cast to Device functionality (qWave-TCP-In)",
    "Cast to Device functionality (qWave-UDP-In)",
    "Cast to Device SSDP Discovery (UDP-In)",
    "Cast to Device streaming server (HTTP-Streaming-In)",
    "Cast to Device streaming server (RTCP-Streaming-In)",
    "Cast to Device streaming server (RTSP-Streaming-In)",
    "Cast to Device UPnP Events (TCP-In)",

    # Proximity
    "Proximity sharing over TCP (TCP sharing-In)"


    # File & Printer Sharing
    "File and Printer Sharing (Echo Request - ICMPv4-In)",
    "File and Printer Sharing (Echo Request - ICMPv6-In)",
    "File and Printer Sharing (LLMNR-UDP-In)",
    "File and Printer Sharing (NB-Datagram-In)",
    "File and Printer Sharing (NB-Name-In)",
    "File and Printer Sharing (NB-Session-In)",
    "File and Printer Sharing (SMB-In)",
    "File and Printer Sharing (Spooler Service - RPC)",
    "File and Printer Sharing (Spooler Service - RPC-EPMAP)",
    "File and Printer Sharing (Spooler Service Worker - RPC)",
    
	"Inbound Rule for Remote Shutdown (TCP-In)",

    # SNMP
    "SNMP Trap Service (UDP In)",

    # Firewall Remote Management
    "Windows Defender Firewall Remote Management (RPC)",
    "Windows Defender Firewall Remote Management (RPC-EPMAP)"

    # Restrictive variants
    "File and Printer Sharing (Restrictive) (Echo Request - ICMPv4-In)",
    "File and Printer Sharing (Restrictive) (Echo Request - ICMPv6-In)",
    "File and Printer Sharing (Restrictive) (LLMNR-UDP-In)",
    "File and Printer Sharing (Restrictive) (SMB-In)",
    "File and Printer Sharing (Restrictive) (Spooler Service - RPC)",
    "File and Printer Sharing (Restrictive) (Spooler Service - RPC-EPMAP)",
    "File and Printer Sharing (Restrictive) (Spooler Service Worker - RPC)",
    "File and Printer Sharing over SMBDirect (iWARP-In)",

    # Remote Desktop / Assistance
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

    # Remote Management
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

    # System / Disk / VM
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
    "Virtual Machine Monitoring (Echo Request - ICMPv4-In)",
    "Virtual Machine Monitoring (Echo Request - ICMPv6-In)",
    "Virtual Machine Monitoring (NB-Session-In)",

    # WMI / WinRM
    "Windows Management Instrumentation (ASync-In)",
    "Windows Management Instrumentation (DCOM-In)",
    "Windows Management Instrumentation (WMI-In)",
    "Windows Remote Management (HTTP-In)"
	
	    # --- WinRM ---
    "Windows Remote Management (HTTP-In)",
    "Windows Remote Management - Compatibility Mode (HTTP-In)",

    # --- Wireless / Miracast ---
    "Wireless Display (TCP-In)",
    "Wireless Display Infrastructure Back Channel (TCP-In)",

    # --- Portable Devices ---
    "Wireless Portable Devices (SSDP-In)",
	"Wireless Portable Devices (UPnP-In)",

    # --- Windows Media Player Sharing ---
    "Windows Media Player Network Sharing Service (HTTP-Streaming-In)",
    "Windows Media Player Network Sharing Service (qWave-TCP-In)",
    "Windows Media Player Network Sharing Service (qWave-UDP-In)",
    "Windows Media Player Network Sharing Service (SSDP-In)",
    "Windows Media Player Network Sharing Service (Streaming-UDP-In)",
    "Windows Media Player Network Sharing Service (TCP-In)",
    "Windows Media Player Network Sharing Service (UDP-In)",
    "Windows Media Player Network Sharing Service (UPnP-In)",

    # --- Peer-to-Peer / Discovery ---
    "Windows Peer to Peer Collaboration Foundation (PNRP-In)",
    "Windows Peer to Peer Collaboration Foundation (SSDP-In)",
    "Windows Peer to Peer Collaboration Foundation (TCP-In)",
    "Windows Peer to Peer Collaboration Foundation (WSD-In)"

)
# -------------------------------
# OUTBOUND RULES TO BLOCK
# -------------------------------
$OutboundBlockRules = @(
    # Cast / Media
    "Cast to Device functionality (qWave-TCP-Out)",
    "Cast to Device functionality (qWave-UDP-Out)",
    "Cast to Device streaming server (RTP-Streaming-Out)"

    # File & Printer Sharing
    "File and Printer Sharing (Echo Request - ICMPv4-Out)",
    "File and Printer Sharing (Echo Request - ICMPv6-Out)",
    "File and Printer Sharing (LLMNR-UDP-Out)",
    "File and Printer Sharing (NB-Datagram-Out)",
    "File and Printer Sharing (NB-Name-Out)",
    "File and Printer Sharing (NB-Session-Out)",
    "File and Printer Sharing (SMB-Out)",

    "File and Printer Sharing (Restrictive) (Echo Request - ICMPv4-Out)",
    "File and Printer Sharing (Restrictive) (Echo Request - ICMPv6-Out)",
    "File and Printer Sharing (Restrictive) (LLMNR-UDP-Out)",
    "File and Printer Sharing (Restrictive) (SMB-Out)",

    # Remote Assistance / Routing
    "Remote Assistance (PNRP-Out)",
    "Remote Assistance (RA Server TCP-Out)",
    "Remote Assistance (SSDP TCP-Out)",
    "Remote Assistance (SSDP UDP-Out)",
    "Remote Assistance (TCP-Out)",
    "Routing and Remote Access (GRE-Out)",
    "Routing and Remote Access (L2TP-Out)",
    "Routing and Remote Access (PPTP-Out)",

    # WMI / WinRM
    "Windows Management Instrumentation (WMI-Out)",
    "Windows Remote Management (HTTP-Out)",

    # Media / Peer
    "Windows Media Player Network Sharing Service (HTTP-Streaming-Out)",
    "Windows Media Player Network Sharing Service (qWave-TCP-Out)",
    "Windows Media Player Network Sharing Service (qWave-UDP-Out)",
    "Windows Media Player Network Sharing Service (SSDP-Out)",
    "Windows Media Player Network Sharing Service (Streaming-TCP-Out)",
    "Windows Media Player Network Sharing Service (Streaming-UDP-Out)",
    "Windows Media Player Network Sharing Service (TCP-Out)",
    "Windows Media Player Network Sharing Service (UDP-Out)",
    "Windows Media Player Network Sharing Service (UPnP-Out)",
    "Windows Media Player Network Sharing Service (UPnPHost-Out)",

    "Windows Peer to Peer Collaboration Foundation (PNRP-Out)",
    "Windows Peer to Peer Collaboration Foundation (SSDP-Out)",
    "Windows Peer to Peer Collaboration Foundation (TCP-Out)",
    "Windows Peer to Peer Collaboration Foundation (WSD-Out)",

    # Wireless / TPM
    "Wireless Portable Devices (SSDP-Out)",
    "Wireless Portable Devices (TCP-Out)",
    "Wireless Portable Devices (UPnP-Out)",
    "Wireless Portable Devices (UPnPHost-Out)",
    "TPM Virtual Smart Card Management (TCP-Out)"
	
	# --- Wireless / Miracast ---
    "Wireless Display (TCP-Out)",
    "Wireless Display Infrastructure Back Channel (TCP-Out)",
	"Wireless Display (UDP-Out)"

)

# -------------------------------
# APPLY INBOUND BLOCKS
# -------------------------------
Get-NetFirewallRule -Direction Inbound |
Where-Object { $InboundBlockRules -contains $_.DisplayName } |
Set-NetFirewallRule -Enabled True -Action Block -Confirm:$false

# -------------------------------
# APPLY OUTBOUND BLOCKS
# -------------------------------
Get-NetFirewallRule -Direction Outbound |
Where-Object { $OutboundBlockRules -contains $_.DisplayName } |
Set-NetFirewallRule -Enabled True -Action Block -Confirm:$false

Write-Host "Inbound and Outbound Firewall Rules applied."

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCmzLbETjCLuPu9
# Koo56mX5CFw5ymznqOYheOZrxtqtfaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# INtOQp9S2xiBtYBM0a7A8HHsWIdAfYX0Zu8S0BI83BTNMAsGByqGSM49AgEFAARH
# MEUCIFPWgM8kq6opkGpWUE+g3upkwxt4HINr+68e7DXvSG5ZAiEAkxgRfOz9mWOL
# xKVuDZAodMTcC4U2W8JrW+rz5CNhgRs=
# SIG # End signature block
