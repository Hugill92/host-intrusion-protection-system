$ErrorActionPreference = "Stop"

# --- Run metadata ---
$StartTime = Get-Date
$Results   = @()

# --- Output directory (DEV state sync) ---
$OutDir = "C:\FirewallInstaller\Firewall\DEV-Only\State"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$JsonOut = Join-Path $OutDir ("test-results_{0}.json" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))

Write-Host "=== Firewall Core DEV Test Suite ==="

# --- Discover tests ---
$Tests = Get-ChildItem -Path $PSScriptRoot -Filter "Test-*.ps1" |
    Where-Object { $_.Name -ne "Run-All-Tests.ps1" } |
    Sort-Object Name

$Failures = @()

foreach ($Test in $Tests) {

    Write-Host ""
    Write-Host ">>> RUNNING $($Test.Name)"

    $TestStart = Get-Date
    $Status = "PASS"
    $Message = ""

    try {
        & $Test.FullName
        Write-Host "[PASS] $($Test.Name)" -ForegroundColor Green
    }
    catch {
        $Status  = "FAIL"
        $Message = $_.Exception.Message
        Write-Host "[FAIL] $($Test.Name)" -ForegroundColor Red
        Write-Host $Message
        $Failures += $Test.Name
    }

    $Results += [pscustomobject]@{
        TestName   = $Test.Name
        Status     = $Status
        Message    = $Message
        StartTime  = $TestStart.ToString("o")
        EndTime    = (Get-Date).ToString("o")
        DurationMs = [int]((Get-Date) - $TestStart).TotalMilliseconds
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=== TEST SUMMARY ==="

$Summary = [pscustomobject]@{
    RunStarted = $StartTime.ToString("o")
    RunEnded   = (Get-Date).ToString("o")
    TotalTests = $Tests.Count
    Passed     = ($Results | Where-Object Status -eq "PASS").Count
    Failed     = ($Results | Where-Object Status -eq "FAIL").Count
}

if ($Failures.Count -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    $ExitCode = 0
}
else {
    Write-Host "FAILED TESTS:" -ForegroundColor Red
    foreach ($F in $Failures) {
        Write-Host " - $F" -ForegroundColor Red
    }
    $ExitCode = 1
}

# --- Write JSON artifact (FINAL) ---
[pscustomobject]@{
    Summary = $Summary
    Results = $Results
} | ConvertTo-Json -Depth 5 |
    Out-File -Encoding UTF8 -FilePath $JsonOut

Write-Host ""
Write-Host "[INFO] JSON results written to:" -ForegroundColor Cyan
Write-Host "       $JsonOut" -ForegroundColor Cyan

exit $ExitCode

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUIvxTF2UznZvYuyeTXKTYH/mg
# KfOgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUVo+iq5w20v0n7xb8Y03afvYngoYwCwYH
# KoZIzj0CAQUABEYwRAIgS1lbWAElj5/8yoZztZ6AeDCwMJI++UZnBGc6aFKQnpEC
# IGHpakScfXQtmOHCF/9R0/DbZwFDRg73+kzSebKL6Mlr
# SIG # End signature block
