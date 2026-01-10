# ================= EXECUTION POLICY SELF-BYPASS =================
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Error "Constrained language mode detected. Exiting."
    exit 1
}

if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass') {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSCommandPath" @args
    exit $LASTEXITCODE
}
# =================================================================



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

# Admin enforcement
#Requires -RunAsAdministrator

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

$RemoteAdminGroups = @(
    "Remote Desktop",
    "Remote Event Log Management",
    "Remote Scheduled Tasks Management",
    "Remote Service Management",
    "Remote Volume Management",
    "Routing and Remote Access"
)

Get-NetFirewallRule |
Where-Object { $RemoteAdminGroups -contains $_.Group } |
Set-NetFirewallRule -Action Block -Enabled True


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
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUbW/pbP0oNUM45/9YJbYUz+g0
# sg2gggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQURRsbNg93l9XoTPvTgA/PqcEsLZowDQYJ
# KoZIhvcNAQEBBQAEggEATojbwGf5x6O8XODPDWZ7DVraw2s1/M4cjvmIxd7hbeHZ
# d4OJ7OBSdvKT53QU3EPnngxYcW025KK+mEMr382X1sDOeTRzktAzJHyPwbcgKLaq
# LX4dVvLPLmRJhWkiuZ72Fxx9lJvGXi849w+T/KKnlDoHpAXR0UXtXTnpqLmDMjrT
# rVd3OBn9jDttoeGWc6mNkK9nvzaUcClm9W7MxUTc4go3GoqawU7LRFWUnHpJ6pE4
# 1q0sdL4lYnQzwbrQKb1fRuuxLF9WA5rzXw5e4sfciudJQCMNBkUCFY/EczYRIGEn
# Giid+MRmE8SQZcP/16v1zHzAT556Vgsxe4GBNG6+NA==
# SIG # End signature block
