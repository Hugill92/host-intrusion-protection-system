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
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUe37urX/3umELAeU+533tT7T9
# ThegggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUHR4gV71tFas8MBu/7sZNbzSKPhcwCwYH
# KoZIzj0CAQUABEgwRgIhAMiqHZBzVvRUzXETQPjZPMV5zT8k/CfEreRmL5tdkoL4
# AiEA9w0cbj81HVC3PQmzGyq5qWjRSSkrdg8Vp1gTH2bUJMc=
# SIG # End signature block
