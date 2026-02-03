# New-BaselineVersion.ps1
# Creates a versioned baseline snapshot + activates it
# Run elevated

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$StateDir   = "C:\Firewall\State"
$GoldenDir  = "C:\Firewall\Golden\Baselines"
$Baseline   = Join-Path $StateDir "baseline.json"
$HashFile   = Join-Path $StateDir "baseline.hash"
$MetaFile   = Join-Path $StateDir "baseline.meta.json"

New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
New-Item -ItemType Directory -Path $GoldenDir -Force | Out-Null

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")

# Capture baseline (stable fields; include DisplayName for better logs)
$rules = Get-NetFirewallRule |
  Select-Object Name, DisplayName, Enabled, Direction, Action, Profile, Group, Description |
  Sort-Object Name

$rulesJson = $rules | ConvertTo-Json -Depth 4
$rulesJson | Set-Content $Baseline -Encoding utf8

$hash = (Get-FileHash $Baseline -Algorithm SHA256).Hash
$hash | Set-Content $HashFile -Encoding ascii

$meta = [pscustomobject]@{
  Version     = $stamp
  CreatedUtc  = (Get-Date).ToUniversalTime().ToString("o")
  CreatedBy   = "$env:COMPUTERNAME\$env:USERNAME"
  RuleCount   = ($rules | Measure-Object).Count
  BaselineSha256 = $hash
}
($meta | ConvertTo-Json -Depth 3) | Set-Content $MetaFile -Encoding utf8

# Persist a versioned copy
$verBase = Join-Path $GoldenDir "baseline.v$stamp"
Copy-Item $Baseline "$verBase.json" -Force
Copy-Item $HashFile "$verBase.hash" -Force
Copy-Item $MetaFile "$verBase.meta.json" -Force

Write-Host "[OK] Baseline version created and activated: v$stamp"
Write-Host "     RuleCount=$($meta.RuleCount) SHA256=$hash"

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUFgOUEeubQtBtumUP3tW2sBQq
# V/agggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUZ70K4/U5RV5P9APdGsO7rl59YzgwCwYH
# KoZIzj0CAQUABEYwRAIgSRriwGao8IwWiImdZCtNbvNd+nkXrpNUnvDI0i78sE4C
# IFB/xcIyi820bqOiAS6oLU6zAwKzYyAc1bSaDLLMwWyv
# SIG # End signature block
