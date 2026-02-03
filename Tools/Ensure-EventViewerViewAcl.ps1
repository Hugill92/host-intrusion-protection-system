[CmdletBinding()]
param(
  [string[]] $ViewDirs = @(
    (Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"),
    (Join-Path $env:ProgramData "FirewallCore\User\Views")
  ),
  [string] $Principal = "BUILTIN\Users",
  [string] $Pattern = "FirewallCore*.xml",
  [switch] $Strict
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$m){ Write-Host $m -ForegroundColor Cyan }
function Write-Warn([string]$m){ Write-Host $m -ForegroundColor Yellow }
function Write-Ok([string]$m){ Write-Host $m -ForegroundColor Green }
function Write-Fail([string]$m){ Write-Host $m -ForegroundColor Red }

$anyFail = $false

foreach ($dir in $ViewDirs) {
  Write-Info "=== Ensure ACL: $dir ==="

  if (!(Test-Path -LiteralPath $dir)) {
    Write-Warn "SKIP: missing dir: $dir"
    continue
  }

  $files = Get-ChildItem -LiteralPath $dir -File -Filter $Pattern -ErrorAction Stop
  if (!$files -or $files.Count -eq 0) {
    Write-Warn "No matches for $Pattern in $dir"
    continue
  }

  foreach ($f in $files) {
    try {
      & icacls $f.FullName /grant "${Principal}:(R)" | Out-Null
      Write-Ok ("OK  : {0}" -f $f.Name)
    }
    catch {
      $anyFail = $true
      Write-Fail ("FAIL: {0} :: {1}" -f $f.FullName, $_.Exception.Message)
      if ($Strict) { throw }
    }
  }
}

if ($anyFail -and $Strict) { throw "One or more ACL updates failed." }

if ($anyFail) { Write-Warn "DONE with failures (non-strict)." }
else { Write-Ok "DONE: all ACL updates succeeded." }

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUcIup7jiQ26wNYjsCHH1F+fYa
# EgWgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUX1UaB0VrwPqLraGNi3h6ipklPlowCwYH
# KoZIzj0CAQUABEYwRAIgdhn2S7XdTg4UDKQYXCvTG3fgi0H3+tiIbfYCOR4POuUC
# IDF4IXR/K6yv1Bfdj8PxsCkLBgZJkw54ETrTzhBeYImB
# SIG # End signature block
