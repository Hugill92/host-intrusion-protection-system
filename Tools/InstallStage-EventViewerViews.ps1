[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Strict
)

$ErrorActionPreference = 'Stop'

$src = Join-Path $RepoRoot 'Firewall\Monitor\EventViews'
if (!(Test-Path -LiteralPath $src)) {
  throw "Source views folder missing: $src"
}

$evViews   = Join-Path $env:ProgramData 'Microsoft\Event Viewer\Views'
$coreViews = Join-Path $env:ProgramData 'FirewallCore\User\Views'

New-Item -ItemType Directory -Path $evViews   -Force | Out-Null
New-Item -ItemType Directory -Path $coreViews -Force | Out-Null

$files = Get-ChildItem -LiteralPath $src -Filter '*.xml' -File -ErrorAction Stop
if ($files.Count -eq 0) { throw "No *.xml files found in: $src" }

foreach ($f in $files) {
  Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $evViews   $f.Name) -Force
  Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $coreViews $f.Name) -Force
}

# ACL pass (Users read) — avoids “Access denied” when a toast action tries to open a view
$aclTool = Join-Path $RepoRoot 'Tools\Ensure-EventViewerViewAcl.ps1'
& $aclTool -Path $evViews, $coreViews -Filter 'FirewallCore*.xml' -Strict:$Strict

Write-Host "Install-stage complete: Event Viewer views staged + ACL ensured." -ForegroundColor Green

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU9wUgvsRIxxWiVw44vejff8pq
# CZigggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUStx6mfPX41U4rxgZhiAsxMUxKGcwCwYH
# KoZIzj0CAQUABEcwRQIhANDht7nF1Lo3PgiPmlMYO8IjlwI8FxD4h5RP+bImRs3c
# AiBVe9k0Tb56w9etJffo+4fzdfMd+5VW6lYeXeZ/ebkM0w==
# SIG # End signature block
