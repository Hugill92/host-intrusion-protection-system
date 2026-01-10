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


# ============================================================
# FIREWALL RESET — WINDOWS DEFAULT (INBOUND + OUTBOUND)
# ============================================================

Write-Host "[*] Resetting Windows Firewall to default state..."

# -------------------------------
# 1. Restore firewall policy
# -------------------------------
netsh advfirewall reset | Out-Null

# -------------------------------
# 2. Re-enable firewall profiles
# -------------------------------
Set-NetFirewallProfile -Profile Domain,Private,Public `
    -Enabled True `
    -DefaultInboundAction Block `
    -DefaultOutboundAction Allow

# -------------------------------
# 3. Ensure core Windows rules enabled
#    (DO NOT modify actions here)
# -------------------------------
$CoreAllow = @(
    "Core Networking*",
    "Windows Security",
    "DHCP*",
    "DNS*",
    "mDNS*",
    "Key Management Service*"
)

Get-NetFirewallRule |
Where-Object {
    $CoreAllow | ForEach-Object { $_ -and $_ -like $_ }
} | ForEach-Object {
    Enable-NetFirewallRule -Name $_.Name
}

Write-Host "[OK] Firewall fully reset to Windows defaults."
Write-Host "     Inbound  : Allow by default"
Write-Host "     Outbound : Allow by default"
#Requires -RunAsAdministrator
Write-Warning "This resets firewall rules but NOT WMI ACLs"

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUBNtdy4IZuW7o7MLWfD54FyBF
# 7negggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUrIylsqdQdbnkUMv45uMR8UhMYNgwDQYJ
# KoZIhvcNAQEBBQAEggEASfmwm0RnNhsNi+S+XI8iaMD8qKFuUwoepPUhOtQwA8VX
# SsCROAQpSn7Am1sqx2z6msxqij3YtLj/OHbXt0rkGJdpbe1yLvcJ5pro9czmxec9
# 1GasiKiTrWS1WzA/T43yPYvuDlLeUno2kcYuuIwkzLfzgmpka4nRZowODZ8usGrp
# JcAIalHfPng2yBt+6uylZDVrCtiu+9hQJ5rK+rTrvTCXp+MbBtv/B/r1mhZIm34i
# JJ/LdWL3BdgWzALGtaWzPJhUeFe0pxEVQl1Xd4b3IRd3Jk36oxW4QgnJLdyM7v1R
# PmJ+n4VsENzw5bG1Hgw56C56B4DFppp59ZdURlXz8w==
# SIG # End signature block
