# New-BaselineVersion.ps1
# Creates a versioned baseline snapshot + activates it
# Run elevated

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$StateDir   = "C:\Firewall\State"
$GoldenDir  = "C:\Firewall\Golden\Baselines"
$Baseline   = Join-Path $StateDir "baseline.json"
$HashFile   = Join-Path $StateDir "baseline.hash"
$MetaFile   = Join-Path $StateDir "baseline.meta.json"

New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
New-Item -ItemType Directory -Path $GoldenDir -Force | Out-Null

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")

# Capture baseline (stable fields; include DisplayName for better logs)
$rules = Get-NetFirewallRule |
  Select-Object Name, DisplayName, Enabled, Direction, Action, Profile, Group, Description |
  Sort-Object Name

$rulesJson = $rules | ConvertTo-Json -Depth 4
$rulesJson | Set-Content $Baseline -Encoding utf8

$hash = (Get-FileHash $Baseline -Algorithm SHA256).Hash
$hash | Set-Content $HashFile -Encoding ascii

$meta = [pscustomobject]@{
  Version     = $stamp
  CreatedUtc  = (Get-Date).ToUniversalTime().ToString("o")
  CreatedBy   = "$env:COMPUTERNAME\$env:USERNAME"
  RuleCount   = ($rules | Measure-Object).Count
  BaselineSha256 = $hash
}
($meta | ConvertTo-Json -Depth 3) | Set-Content $MetaFile -Encoding utf8

# Persist a versioned copy
$verBase = Join-Path $GoldenDir "baseline.v$stamp"
Copy-Item $Baseline "$verBase.json" -Force
Copy-Item $HashFile "$verBase.hash" -Force
Copy-Item $MetaFile "$verBase.meta.json" -Force

Write-Host "[OK] Baseline version created and activated: v$stamp"
Write-Host "     RuleCount=$($meta.RuleCount) SHA256=$hash"

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUFgOUEeubQtBtumUP3tW2sBQq
# V/agggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUZ70K4/U5RV5P9APdGsO7rl59YzgwDQYJ
# KoZIhvcNAQEBBQAEggEAh7sRAEEEPGHNO4radWKzf8pzkcQA5rIvlyFK45sNLcTK
# aMrO68wJe0CM5U9aoSzdk3D3VYT1gEqvJvb2R8GlJihvOYBDCrMTkbQVRotlIX+T
# wTb7FPxZ0o3jLOlmr1Vl8LjzhBeNlxIYRK6A+sSt1Ymy4uT5trMmFzAr8TJWU5K5
# lOEPZiroGEpcHewKADaQWyBP08sawH7O7Dt/AmcsCp8OG9J3p+Rx6BcgjbgmEIeW
# f4gKzxtok7cxLPYkuxJdumyqkbk++dyUW7WvQGaJe1HE+C+sSGGLE+XO8c/oXEvJ
# dd07fEI6FslzTjTJfr4s/W5aFYZiBfRhD6wrmHYQjA==
# SIG # End signature block
