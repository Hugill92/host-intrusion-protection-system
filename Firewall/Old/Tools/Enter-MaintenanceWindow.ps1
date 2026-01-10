# Enter-MaintenanceWindow.ps1
# Usage: powershell -ExecutionPolicy Bypass -File .\Enter-MaintenanceWindow.ps1 -Minutes 30
param(
  [int]$Minutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. "C:\Firewall\Modules\Firewall-EventLog.ps1"

$token = "C:\Firewall\State\maintenance.token"
$until = (Get-Date).AddMinutes($Minutes)
$until.ToString("o") | Set-Content -Path $token -Encoding utf8

Write-FirewallEvent -EventId 3211 -Type Information -Message "Maintenance window enabled until $($until.ToString("o"))."
Write-Host "[OK] Maintenance window enabled until $($until.ToString("o"))"

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUT2CCWJLtC+JwmARPConeKmBN
# 8/OgggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUm0ih8Pnr4EFfwFEE0aY7XVazEMcwDQYJ
# KoZIhvcNAQEBBQAEggEAWXcbEQiWeiAknJWz9CibYyXnJrGd7G8XGPIo6zvoV4Wl
# SCEFXa4wGZiVEpEYa9+8FUQaevFI6fYnZdhxbfnTWBvaa6s4f93H7hJ151nX9Q3u
# aqbEbSn20rjQPYmzsM0UMkHsQ+PQQkgp4NiYDhrII7JOSX1yCZluENH9Sx05R1P/
# pPP7reQ3/ivpJI30X95aKEOeF8pCalAj0NC1iHDLsfULTk6mRMAty63Q/fj/6Rij
# BQbvXKh7kpBgMG2/1YyfaIWvtZCcpCvcgX++mMl26bWZ87ZBNAEYb/o3wwBhYQE5
# RueYy1mUkxhFfnBlk2J6Qq1J+cI5R51/7Pv/guqH/w==
# SIG # End signature block
