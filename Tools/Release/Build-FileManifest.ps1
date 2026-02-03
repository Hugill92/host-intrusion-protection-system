<#
Builds a SHA256 manifest for all payload files.
Outputs JSON with paths relative to root.
Recommended output path:
  C:\Firewall\Golden\payload.manifest.sha256.json
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$Root = "C:\Firewall",

  [string]$OutFile = "C:\Firewall\Golden\payload.manifest.sha256.json",

  # What to include
  [string[]]$IncludeExtensions = @(".ps1",".psm1",".psd1",".cmd",".bat",".json",".md",".txt",".cer",".count",".hash"),

  # Optional: exclude transient logs/state
  [string[]]$ExcludePathContains = @("\Logs\", "\State\wfp.bookmark.json", "\State\wfp.strikes.json", "\State\wfp.blocked.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function STEP($m){ Write-Host "[*] $m" }
function OK($m){ Write-Host "[OK] $m" }

$rootFull = (Resolve-Path $Root).Path
STEP "Building manifest for: $rootFull"

$files = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force |
  Where-Object { $IncludeExtensions -contains $_.Extension.ToLowerInvariant() }

# Exclusions (by substring match)
if ($ExcludePathContains.Count -gt 0) {
  $files = $files | Where-Object {
    $p = $_.FullName
    -not ($ExcludePathContains | Where-Object { $p -like "*$_*" })
  }
}

STEP ("Hashing {0} files..." -f $files.Count)

$items = foreach ($f in $files) {
  $rel = $f.FullName.Substring($rootFull.Length).TrimStart("\")
  $h = (Get-FileHash -Algorithm SHA256 -Path $f.FullName).Hash
  [pscustomobject]@{
    Path = $rel
    Sha256 = $h
    Size = $f.Length
    LastWriteTimeUtc = $f.LastWriteTimeUtc.ToString("o")
  }
}

$manifest = [pscustomobject]@{
  Schema = "FirewallPayloadManifest.v1"
  Root   = $rootFull
  BuiltAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  Count  = $items.Count
  Items  = $items | Sort-Object Path
}

New-Item -ItemType Directory -Path (Split-Path $OutFile -Parent) -Force | Out-Null
$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding UTF8

OK "Manifest written: $OutFile"

# SIG # Begin signature block
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0dzPX9i+dEPzNsU5hsOXXkjp
# BaKgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU+KSnU51IvUOHx1elR3cydM6iAWQwCwYH
# KoZIzj0CAQUABEgwRgIhAKRIYopsg9z7lPtpLJk2jzcEhLdhbevLB8K4JSEQ6999
# AiEAkDmTzQvZ5NFcDC8VFi8+Wd8jSdnN9a4styati4uzjzY=
# SIG # End signature block
