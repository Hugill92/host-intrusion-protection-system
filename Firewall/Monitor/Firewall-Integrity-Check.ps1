# Firewall-Integrity-Check.ps1
# Silent integrity verifier (NO logging, NO enforcement)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$baselineFile = "C:\Firewall\State\baseline.integrity.json"

# If baseline is missing, silently fail (Core remains authoritative)
if (-not (Test-Path $baselineFile)) {
    exit 1
}

$baseline = Get-Content $baselineFile -Raw | ConvertFrom-Json

$currentRules = Get-NetFirewallRule |
    Select Name, Enabled, Direction, Action, Profile |
    Sort-Object Name

$json = $currentRules | ConvertTo-Json -Depth 3

$currentHash = (Get-FileHash -InputStream (
    [System.IO.MemoryStream]::new([byte[]][char[]]$json)
) -Algorithm SHA256).Hash

$currentCount = $currentRules.Count

# Integrity OK
if ($currentHash -eq $baseline.Hash -and $currentCount -eq $baseline.RuleCount) {
    exit 0
}

# Integrity drift detected (no logging here)
exit 2

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUrbqxXbeocb67fcAvY+rnqw9T
# H9igggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUqW4e+M0OCeGKI2/Xt0LoBpqTQyIwDQYJ
# KoZIhvcNAQEBBQAEggEAQiqzJmJtNJcgaeDAL68x084UdWW/sTUBaejBPBf4BXOj
# JFLyfD0GHaxGoiMFNpj1egHG/SvK38m3Oh3y+O16VWKseWhgJSpTmbB9IWon7hBY
# AtlX3bFs6ddVBmTB1cvQm1vijg2nkSBKtZ2qDCFAB1t0Vwl5czFEnNgmBgUS+5sh
# QqLVuIJRo5V7eAeBnCYEUuG1IJhMx/8WX/6Zmr6q7sFoIMEYA6OPw+pcENnjVFQn
# /brru8hnECE3fkCzf6IXSKAwE+6rmuBCyuRcTjs/zCA60Ft70X3I+CV+Wwb9NoBA
# w//nNqyGR2KnVlbMZVF8r8kA9vkVQkO59NtC6b483Q==
# SIG # End signature block
