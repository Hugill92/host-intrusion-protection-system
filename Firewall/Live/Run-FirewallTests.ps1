param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "DEV",

    [switch]$FailFast,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent

if ($Mode -eq "DEV") {
    $TestRoot = Join-Path $Root "DEV-Only\Tests"
} else {
    $TestRoot = Join-Path $Root "Live\Tests"
}

Write-Host "[RUN] Mode=$Mode"
Write-Host "[RUN] TestRoot=$TestRoot"

$tests = Get-ChildItem $TestRoot -Filter "*.ps1" | Sort-Object Name
if (-not $tests) {
    Write-Host "[SKIP] No tests found"
    exit 0
}

$results = @()

foreach ($test in $tests) {
    Write-Host "`n[TEST] $($test.Name)" -ForegroundColor Cyan

    $sw = [Diagnostics.Stopwatch]::StartNew()
    & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File $test.FullName `
        -Mode $Mode
    $code = $LASTEXITCODE
    $sw.Stop()

    $status = if ($code -eq 0) { "PASS" } else { "FAIL" }

    Write-Host ("[{0}] {1} ({2}s)" -f $status,$test.Name,[math]::Round($sw.Elapsed.TotalSeconds,2)) `
        -ForegroundColor (if ($status -eq "PASS") {"Green"} else {"Red"})

    $results += [pscustomobject]@{
        Test   = $test.Name
        Status = $status
        Time   = $sw.Elapsed.TotalSeconds
    }

    if ($FailFast -and $status -eq "FAIL") { break }
}

Write-Host "`n[INFO] Review FirewallCore event log for authoritative results."

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDHrxnIOVspY3KbITwt8+kHoR
# zfWgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUVSNKEWyc7JsSGM1wkqp8+eCeM70wCwYH
# KoZIzj0CAQUABEcwRQIhAOihjBulerPof5gKj1xblvooyxX5FTxbYkjnCKX0UGTz
# AiAeXoaaJ8oDqxP7EzguDNJBa0SbyWUug0r+J/AXoecoPQ==
# SIG # End signature block
