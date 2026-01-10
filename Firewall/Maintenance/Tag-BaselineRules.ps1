# Tag-BaselineRules.ps1
param(
  [Parameter(Mandatory)][string]$OwnerTag  # e.g. "HomeBaseline" or "CorpStandard"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$BaselinePath = "C:\Firewall\State\baseline.json"
$MetaPath     = "C:\Firewall\State\baseline.meta.json"

if (!(Test-Path $BaselinePath)) { throw "Missing baseline.json" }

$version = "Unknown"
if (Test-Path $MetaPath) {
  try { $version = (Get-Content $MetaPath -Raw | ConvertFrom-Json).Version } catch {}
}

$baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json

foreach ($b in $baseline) {
  if (-not $b.Name) { continue }

  $desc = "FWCORE|Owner=$OwnerTag|Baseline=$version|Name=$($b.Name)"
  try {
    Set-NetFirewallRule -Name $b.Name -Group "FirewallCore" -Description $desc -ErrorAction Stop
  } catch {
    Write-Warning "Failed tagging $($b.Name): $($_.Exception.Message)"
  }
}

Write-Host "[OK] Tagged baseline rules with Owner=$OwnerTag and Baseline=$version"

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUe37urX/3umELAeU+533tT7T9
# ThegggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUHR4gV71tFas8MBu/7sZNbzSKPhcwDQYJ
# KoZIhvcNAQEBBQAEggEA1ED4393gi16w8PTvALVYrFmFI551UKH8Obb5DLjK2Tdw
# viDmy7W7tDrhZlZtRd+DVndo9qFagtD3pqS0gCXC2NFkTmZZfhH0JQN93qTVsGEp
# qq5zQIXxwboqeiu9GL2OuD4d7s0d6AN8Xvo2MiQS5LgUZ8bfsFzZAOaI9gT445TM
# wG+QXGXwjPfuOiprbX6vE68LeDpklej+GAET+FuWCW69SwWxbbbZALbjv6pjzWiN
# xZ/ec6HLM9eGFjsPvI3AwCalzrBTghNOaNXBpRKhG9IpCe8HaaPhgUg9pBLk23qY
# 3WlTvNtk/KC+FzDUbE0BKomYwFzhzDpDwl2abdOH/A==
# SIG # End signature block
