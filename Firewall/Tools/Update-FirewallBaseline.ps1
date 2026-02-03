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
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUZrk8F+/B9dN0Mu/vrs3RKss4
# zECgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
# hvcNAQELBQAwJzElMCMGA1UEAwwcRmlyZXdhbGxDb3JlIE9mZmxpbmUgUm9vdCBD
# QTAeFw0yNjAyMDMwNzU1NTdaFw0yOTAzMDkwNzU1NTdaMFgxCzAJBgNVBAYTAlVT
# MREwDwYDVQQLDAhTZWN1cml0eTEVMBMGA1UECgwMRmlyZXdhbGxDb3JlMR8wHQYD
# VQQDDBZGaXJld2FsbENvcmUgU2lnbmF0dXJlMFkwEwYHKoZIzj0CAQYIKoZIzj0D
# AQcDQgAExBZAuSDtDbNMz5nbZx6Xosv0IxskeV3H2I8fMI1YTGKMmeYMhml40QQJ
# wbEbG0i9e9pBd3TEr9tCbnzSOUpmTKNvMG0wCQYDVR0TBAIwADALBgNVHQ8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFKm7zYv3h0UWScu5+Z98
# 7l7v7EjsMB8GA1UdIwQYMBaAFCwozIRNrDpNuqmNvBlZruA6sHoTMA0GCSqGSIb3
# DQEBCwUAA4IBAQCbL4xxsZMbwFhgB9cYkfkjm7yymmqlcCpnt4RwF5k2rYYFlI4w
# 8B0IBaIT8u2YoNjLLtdc5UXlAhnRrtnmrGhAhXTMois32SAOPjEB0Fr/kjHJvddj
# ow7cBLQozQtP/kNQQyEj7+zgPMO0w65i5NNJkopf3+meGTZX3oHaA8ng2CvJX/vQ
# ztgEa3XUVPsGK4F3HUc4XpJAbPSKCeKn16JDr7tmb1WazxN39iIhT25rgYM3Wyf1
# XZHgqADpfg990MnXc5PCf8+1kg4lqiEhdROxmSko4EKfHPTHE3FteWJuDEfpW8p9
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBJDCCASACAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUKz+JY0DvRdXc80qO/NqhWKuFWDswCwYH
# KoZIzj0CAQUABEgwRgIhAPCqf7CKdGZ54Q3Wwz1oZnpun2yRxTc7q9bAZFLXUIRu
# AiEAyQn4W2V5ERvkIMygdSFsaKqRPkkLYzjBJvzCkc9Kf1M=
# SIG # End signature block
