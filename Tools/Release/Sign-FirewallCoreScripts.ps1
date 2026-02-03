<#
Signs all signable payload scripts under a root folder.
- Signs: .ps1, .psm1, .psd1
- Does NOT sign: .cmd/.bat (not reliably Authenticode-signed for your use case)
- Requires a Code Signing cert with a private key.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$Root = "C:\Firewall",

  # Optional: pin to a thumbprint if you want deterministic signing
  [string]$Thumbprint = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function STEP($m){ Write-Host "[*] $m" }
function OK($m){ Write-Host "[OK] $m" }
function WARN($m){ Write-Warning $m }

function Get-CodeSignCert {
  param([string]$Thumbprint)

  $stores = @("Cert:\CurrentUser\My","Cert:\LocalMachine\My")
  $cands = foreach ($s in $stores) {
    Get-ChildItem $s -ErrorAction SilentlyContinue
  }

  if ($Thumbprint) {
    $cert = $cands | Where-Object { $_.Thumbprint -eq $Thumbprint -and $_.HasPrivateKey }
    if (-not $cert) { throw "No cert with private key found for thumbprint $Thumbprint" }
    return $cert | Select-Object -First 1
  }

  $cert = $cands | Where-Object {
    $_.HasPrivateKey -and
    ($_.EnhancedKeyUsageList.FriendlyName -contains "Code Signing")
  } | Sort-Object NotAfter -Descending | Select-Object -First 1

  if (-not $cert) { throw "No Code Signing cert with private key found in CurrentUser\My or LocalMachine\My" }
  return $cert
}

STEP "Signing payload under: $Root"
$cert = Get-CodeSignCert -Thumbprint $Thumbprint
OK ("Using cert: {0} ({1}) Expires={2}" -f $cert.Subject, $cert.Thumbprint, $cert.NotAfter)

$targets = Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
  Where-Object { $_.Extension -in ".ps1",".psm1",".psd1" }

STEP ("Found {0} files to sign" -f $targets.Count)

$failed = @()
foreach ($f in $targets) {
  try {
    # Skip already-valid signatures if you want: comment out if you want to re-sign every time
    $sig = Get-AuthenticodeSignature -FilePath $f.FullName
    if ($sig.Status -eq "Valid") {
      continue
    }

    Set-AuthenticodeSignature -FilePath $f.FullName -Certificate $cert -TimestampServer "http://timestamp.digicert.com" | Out-Null
  } catch {
    $failed += $f.FullName
    WARN ("Failed to sign: {0} :: {1}" -f $f.FullName, $_.Exception.Message)
  }
}

if ($failed.Count -gt 0) {
  throw ("Signing failed for {0} files. Fix and re-run." -f $failed.Count)
}

OK "Signing complete"

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUhvPbOpSOHrxJIWi5zXiBMHqu
# VpigggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIjCCAR4CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUH+hMjzqxyIl04+8ne6ySBOUK7xkwCwYH
# KoZIzj0CAQUABEYwRAIgYAM51DWcGWm03vgU7R340znMJ4FzCqfeZ4/OD6VVf9wC
# IERghv9lKU3WxPmQYWw3EjeBuXamvD1T62KWErhgVIeA
# SIG # End signature block
