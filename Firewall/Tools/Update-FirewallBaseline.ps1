# Update-FirewallBaseline.ps1
# Writes a new baseline.json + baseline.hash from the CURRENT firewall rules.
# Guarded by admin-override.token OR local admin membership.
#
# Usage:
#   1) Run Approve-BaselineUpdate.ps1 (short window), OR run as local admin
#   2) powershell -ExecutionPolicy Bypass -File .\Update-FirewallBaseline.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. "C:\Firewall\Modules\Firewall-EventLog.ps1"

$stateDir = "C:\Firewall\State"
if (!(Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

$tokenPath = Join-Path $stateDir "admin-override.token"
$baseline  = Join-Path $stateDir "baseline.json"
$hashPath  = Join-Path $stateDir "baseline.hash"

function Is-LocalAdmin {
  try {
    $me = [Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = New-Object Security.Principal.WindowsPrincipal($me)
    return $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function TokenValid {
  if (!(Test-Path $tokenPath)) { return $false }
  try {
    $until = (Get-Content $tokenPath -Raw -Encoding utf8).Trim() | Get-Date
    return ((Get-Date) -lt $until)
  } catch { return $false }
}

if (-not (Is-LocalAdmin) -and -not (TokenValid)) {
  Write-FirewallEvent -EventId 3222 -Type Error -Message "Baseline update denied: not admin and no valid admin-override.token."
  throw "Denied: not admin and no valid admin-override.token"
}

$rules = Get-NetFirewallRule | Select Name, DisplayName, Enabled, Direction, Action, Profile
($rules | ConvertTo-Json -Depth 4) | Set-Content -Path $baseline -Encoding utf8

$hash = (Get-FileHash $baseline -Algorithm SHA256).Hash
$hash | Set-Content -Path $hashPath -Encoding ascii

Write-FirewallEvent -EventId 3221 -Type Information -Message "Firewall baseline updated and locked. Rules=$($rules.Count)."
Write-Host "[OK] Baseline updated and locked. Rules=$($rules.Count)"

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUoIbhaAlrXAbYDUngG5fvGF5e
# PgegggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUrr9MakaPPMGbUlkD6Cc+VByB+BMwDQYJ
# KoZIhvcNAQEBBQAEggEAwDrrodb5XwJRRRmsGYb1/Kwg8B9A4tUNc8f2/iKD5k5M
# HPF4E6JXDueEKcrFjOXBsecvTWpUiru5pcsn4/C6inYjGlhKvxF2MsTH8X3akd1b
# NYvY8DDrDNaZTsT0zhq1vLgyiEqc2Mj89Q1jurvf0LuEUkCU3MxvHcC7dwNOz/r7
# OxM2ItiBVqoKxuVLcla371GZsLQKEy6sHMLOYmkJefyHbASz4VhtX1W0Ua7MDcuO
# lFE/DUz1wjZ2C+SFFqIYFO6mvUjcpr4GXOrANoTLwXLH0MdRj18KCDK10FasSL2N
# TORlNC13vYdu2t/qbd5HaV/iwROYlL1obtwXXf8TIg==
# SIG # End signature block
