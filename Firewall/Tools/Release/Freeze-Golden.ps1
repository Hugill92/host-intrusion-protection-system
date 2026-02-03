<#
One-command “release freeze”.
1) Signs all scripts
2) Builds payload manifest
3) Verifies signatures + manifest sanity
#>

[CmdletBinding()]
param(
  [string]$Root = "C:\Firewall",
  [string]$Thumbprint = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function STEP($m){ Write-Host "[*] $m" }
function OK($m){ Write-Host "[OK] $m" }

# -----------------------------
# Resolve Release tools CORRECTLY
# -----------------------------
$ReleaseRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$sign = Join-Path $ReleaseRoot "Sign-FirewallCoreScripts.ps1"
$man  = Join-Path $ReleaseRoot "Build-FileManifest.ps1"

if (-not (Test-Path $sign)) { throw "Missing: $sign" }
if (-not (Test-Path $man))  { throw "Missing: $man"  }

# -----------------------------
# 1/3 Sign payload
# -----------------------------
STEP "1/3 Signing Firewall payload..."
& $sign -Root $Root -Thumbprint $Thumbprint

# -----------------------------
# 2/3 Build manifest
# -----------------------------
STEP "2/3 Building manifest..."
$out = Join-Path $Root "Golden\payload.manifest.sha256.json"
& $man -Root $Root -OutFile $out

# -----------------------------
# 3/3 Verify signatures
# -----------------------------
STEP "3/3 Verifying signatures..."

$bad = Get-ChildItem $Root -Recurse -File -Force |
  Where-Object { $_.Extension -in ".ps1",".psm1",".psd1" } |
  ForEach-Object {
    $s = Get-AuthenticodeSignature -FilePath $_.FullName
    if ($s.Status -ne "Valid") { $_.FullName }
  }

if ($bad) {
  throw ("Some scripts are not Valid-signed:`n" + ($bad -join "`n"))
}

OK "Golden freeze complete."
OK "Manifest written to:"
OK "  $out"

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUmICUVlyn/Z4L+b2eX/F+0y5D
# 2gSgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUQoX2VH74i4stC57yY82MkKqL3fQwCwYH
# KoZIzj0CAQUABEcwRQIgKnZdxZfQYv/VTPaZA2ZVE48evYctUv21RWwo6bbJ/iYC
# IQDdfr+LGr7W7antviBHG8axNJns68+zCzv8M8yRb8f4JA==
# SIG # End signature block

