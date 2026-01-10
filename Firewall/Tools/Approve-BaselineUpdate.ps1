# Approve-BaselineUpdate.ps1
# One-shot admin approved override token for baseline updates (tooling).
# Usage: powershell -ExecutionPolicy Bypass -File .\Approve-BaselineUpdate.ps1 -Minutes 10
param(
  [int]$Minutes = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. "C:\Firewall\Modules\Firewall-EventLog.ps1"

$token = "C:\Firewall\State\admin-override.token"
$until = (Get-Date).AddMinutes($Minutes)
$until.ToString("o") | Set-Content -Path $token -Encoding utf8

Write-FirewallEvent -EventId 3220 -Type Information -Message "Admin baseline update override enabled until $($until.ToString("o"))."
Write-Host "[OK] Admin override enabled until $($until.ToString("o"))"

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUCvZvalgK/D3Nw0r3kUsIZRk0
# /XygggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU6AeGQ6ypgK1vjr86lVraxbC+HCcwDQYJ
# KoZIhvcNAQEBBQAEggEARQ4TUWXW60ZrrqDqkHjaPw/VoKx2dXVJ2X2sjIEJn30F
# DxrttO8+QpCEa/dkLaCj/U9fNnhKBHYayy6wI0HOKFRnFfmFnCpoX16rYpvz02kY
# IUaJbVtku6/vy5/cS5dwraGgCIZvsD9wiroi9dePGKvIs5LU6JiDXzaQskzHX37n
# dxdC0fdVSWhg4/VI3/0D5DXHzAu6ETJ4M8bYFOuSYiAsuEZB+WVQ1qJ/LkYa7FpC
# vFisGK2DZPNkfYIKdIgspvpz3GmcIrGAmrz3WLnuAgUt1AWpr+ckCQA3i/5dOWg4
# uKVeUjcL7RmxgY8W5LDQAq/CdDUkff/5JKrs/8af0w==
# SIG # End signature block
