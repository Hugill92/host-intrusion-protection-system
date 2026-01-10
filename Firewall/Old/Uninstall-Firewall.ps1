# Uninstall-Firewall.ps1
# Requires elevated admin
# Removes Firewall Core enforcement safely

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "[*] Starting Firewall Core uninstall..."

# ---- Safety check ----
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges required."
    exit 1
}

# ---- Stop scheduled task ----
$taskName = "Firewall Core Monitor"
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "[OK] Scheduled task removed."
}

# ---- Optional: restore Windows defaults (commented by design) ----
# Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultInboundAction Allow

# ---- Preserve logs intentionally ----
Write-Host "[*] Firewall logs preserved at C:\Firewall\Logs"

# ---- Remove binaries ----
$paths = @(
    "C:\Firewall\Monitor",
    "C:\Firewall\Modules",
    "C:\Firewall\Maintenance"
)

foreach ($p in $paths) {
    if (Test-Path $p) {
        Remove-Item $p -Recurse -Force
        Write-Host "[OK] Removed $p"
    }
}

Write-Host "[DONE] Firewall Core uninstalled safely."

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUfh1cjOiNt9mE1yI1In7OTF2n
# 18egggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUcNhHG2yhLfkQ5CpnFtfRF0Im+iYwDQYJ
# KoZIhvcNAQEBBQAEggEAsF0fYn3nSN5Yk1ywpPR4Fb2VfxQSXkKDiAzeHNa9bRvC
# 6WeUJQaxnGnWM96jcS0boE2hDGgX80HJen9sCux0Y+scC5UsRFHaY89sCH/baCkX
# Utk52tB4wCKVJk6POwE9SeOOmDkmlpsUt2JUHDASSBV0BVIBP/Nvv1U3Rnba2VHl
# SopTeKp4huzQmfkgIUPAF6BlMju+2NkBkhh57hxwq4JpuQRIIl5Bg2NjvDbBNLMK
# PGij3vqWO5abnEl7VyMLyUH5uA2stgXrEssQ8YbqxV9kdjrNkFOis9W5XCiQ+aec
# +L/zlSju7LCDiRmVcclJ6jOUx38dO5nFDm4u6o84SQ==
# SIG # End signature block
