[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Old,
  [Parameter(Mandatory)][string]$New,
  [string]$OutFile = "C:\FirewallInstaller\Tools\Snapshot-Diff.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Lines($p) { Get-Content -LiteralPath $p -ErrorAction Stop }

$oldLines = Get-Lines $Old
$newLines = Get-Lines $New

# Line diff (simple + reliable)
$diff = Compare-Object -ReferenceObject $oldLines -DifferenceObject $newLines -IncludeEqual:$false -PassThru |
  ForEach-Object { $_ }

New-Item -ItemType Directory -Path (Split-Path -Parent $OutFile) -Force | Out-Null

"Snapshot Diff" | Set-Content $OutFile
"OLD: $Old" | Add-Content $OutFile
"NEW: $New" | Add-Content $OutFile
"Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $OutFile
"" | Add-Content $OutFile

"==============================" | Add-Content $OutFile
"RAW LINE DIFF" | Add-Content $OutFile
"==============================" | Add-Content $OutFile
$diff | Add-Content $OutFile

"" | Add-Content $OutFile
"==============================" | Add-Content $OutFile
"NOTE" | Add-Content $OutFile
"==============================" | Add-Content $OutFile
"RAW LINE DIFF is blunt by design. Use it to verify tasks, rules, profile defaults, golden files, and signature changes." | Add-Content $OutFile

Write-Host "[OK] Wrote diff: $OutFile"

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWua7rq1mCyCcTO6yRX4Lt3Xe
# NtGgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUj6rYMu8GCTC+/J7ucFj1JcokKiIwCwYH
# KoZIzj0CAQUABEcwRQIhANRhpneit4YCoujBkNi2mDNvxPuVxoiAlJ34NlItNhkx
# AiAyTnISvJk7XtkbG3HgOJoxB8XRnaAB3AVu3prJEGNqcg==
# SIG # End signature block
