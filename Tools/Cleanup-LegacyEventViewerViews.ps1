[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$NameRegex = '^View_\d+$',

  [string[]]$Roots = @(
    (Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Event Viewer\Views")
  ),

  [string]$ArchiveRoot = (Join-Path $env:ProgramData ("FirewallCore\Logs\ViewArchive\{0:yyyyMMdd_HHmmss}" -f (Get-Date)))
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Path $ArchiveRoot -Force | Out-Null
Write-Host "Archive: $ArchiveRoot" -ForegroundColor DarkGray

$deleted = 0
$kept    = 0

foreach ($root in $Roots) {
  if (!(Test-Path -LiteralPath $root)) { continue }

  Write-Host "`nSCAN: $root" -ForegroundColor Cyan
  $xmls = Get-ChildItem -LiteralPath $root -File -Filter *.xml -ErrorAction SilentlyContinue
  foreach ($f in $xmls) {
    $raw = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (!$raw) { $kept++; continue }

    # Match either Name or DisplayName
    $m1 = [regex]::Match($raw, '<Name>\s*([^<]+)\s*</Name>', 'IgnoreCase')
    $m2 = [regex]::Match($raw, '<DisplayName>\s*([^<]+)\s*</DisplayName>', 'IgnoreCase')

    $name = $null
    if ($m2.Success) { $name = $m2.Groups[1].Value.Trim() }
    elseif ($m1.Success) { $name = $m1.Groups[1].Value.Trim() }

    if ($name -and ($name -match $NameRegex)) {
      $dest = Join-Path $ArchiveRoot $f.Name
      Copy-Item -LiteralPath $f.FullName -Destination $dest -Force

      if ($PSCmdlet.ShouldProcess($f.FullName, "Delete custom view '$name'")) {
        Remove-Item -LiteralPath $f.FullName -Force
        Write-Host "DELETE: $name  ($($f.Name))" -ForegroundColor Yellow
        $deleted++
      }
    } else {
      $kept++
    }
  }
}

Write-Host "`nDONE. Deleted: $deleted  Kept: $kept" -ForegroundColor Green

# SIG # Begin signature block
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUYS/w85/JpbJXZNyIWbp/zKV4
# TAygggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUgWhNZwApMDO3LB9RReXT8qNp4bcwCwYH
# KoZIzj0CAQUABEgwRgIhAIA0aYC4vCUnx7oCCGH90VhgV5OH6PSuc88/tbuZpdQ1
# AiEAmI/xX+D6jz7pUk4FT1/04GVnQyD+QbRp9zA4toH4Jx4=
# SIG # End signature block
