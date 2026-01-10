# Restore-BaselineVersion.ps1
param(
  [Parameter(Mandatory)]
  [string]$VersionStamp  # like 20260105-122233
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$StateDir  = "C:\Firewall\State"
$GoldenDir = "C:\Firewall\Golden\Baselines"

$srcBase = Join-Path $GoldenDir "baseline.v$VersionStamp"

if (!(Test-Path "$srcBase.json")) { throw "Missing $srcBase.json" }
if (!(Test-Path "$srcBase.hash")) { throw "Missing $srcBase.hash" }
if (!(Test-Path "$srcBase.meta.json")) { throw "Missing $srcBase.meta.json" }

Copy-Item "$srcBase.json"  (Join-Path $StateDir "baseline.json") -Force
Copy-Item "$srcBase.hash"  (Join-Path $StateDir "baseline.hash") -Force
Copy-Item "$srcBase.meta.json" (Join-Path $StateDir "baseline.meta.json") -Force

Write-Host "[OK] Restored baseline version v$VersionStamp to active baseline."

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU2jCdkD71mAKXL4b14pt7ZqDe
# nmegggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUfjcGylDRZRRWLDdY+ZgjatxjAcEwDQYJ
# KoZIhvcNAQEBBQAEggEA0gQ1D6w8uS2KxiBGG865ZAl8OISWSwCBtzzw7JHkKiUk
# DBOGnoScnQn4iQNarSu4g4bTZ1TVW/PNIOvrLfGFCKPa+0i+oLB0kP86cHks31T9
# 2yKODYTRm/NmbGhOLQC/Y40w7KFJj2MIzQKHNa0PmRjlJnYJZV57ivv7/dnhL4gx
# yjhVaECkhnao2Og/6SXdmM1EUbO83JdgDcrSe/QPjnUFqoMno28coj/sfFhxNBSW
# tOUEs7bP8olj7scZ7ZWxBDAseGCvrno4i7j1J3OJi4EGyde0fTOKJuySEub4dArV
# 0UBLjPmIn/L/IAQ+FH3xHafeY0rR9NKrM5N/PAPeIw==
# SIG # End signature block
