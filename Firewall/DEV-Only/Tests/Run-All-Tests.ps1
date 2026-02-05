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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDJDhHvPPGE+JG8
# 5poge+3wgq92oLpzcv1HqUvYdcCkYKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
# YA1JZL+WI1Yn9crpsTANBgkqhkiG9w0BAQsFADAnMSUwIwYDVQQDDBxGaXJld2Fs
# bENvcmUgT2ZmbGluZSBSb290IENBMB4XDTI2MDIwMzA3NTU1N1oXDTI5MDMwOTA3
# NTU1N1owWDELMAkGA1UEBhMCVVMxETAPBgNVBAsMCFNlY3VyaXR5MRUwEwYDVQQK
# DAxGaXJld2FsbENvcmUxHzAdBgNVBAMMFkZpcmV3YWxsQ29yZSBTaWduYXR1cmUw
# WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATEFkC5IO0Ns0zPmdtnHpeiy/QjGyR5
# XcfYjx8wjVhMYoyZ5gyGaXjRBAnBsRsbSL172kF3dMSv20JufNI5SmZMo28wbTAJ
# BgNVHRMEAjAAMAsGA1UdDwQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNV
# HQ4EFgQUqbvNi/eHRRZJy7n5n3zuXu/sSOwwHwYDVR0jBBgwFoAULCjMhE2sOk26
# qY28GVmu4DqwehMwDQYJKoZIhvcNAQELBQADggEBAJsvjHGxkxvAWGAH1xiR+SOb
# vLKaaqVwKme3hHAXmTathgWUjjDwHQgFohPy7Zig2Msu11zlReUCGdGu2easaECF
# dMyiKzfZIA4+MQHQWv+SMcm912OjDtwEtCjNC0/+Q1BDISPv7OA8w7TDrmLk00mS
# il/f6Z4ZNlfegdoDyeDYK8lf+9DO2ARrddRU+wYrgXcdRzhekkBs9IoJ4qfXokOv
# u2ZvVZrPE3f2IiFPbmuBgzdbJ/VdkeCoAOl+D33Qyddzk8J/z7WSDiWqISF1E7GZ
# KSjgQp8c9McTcW15Ym4MR+lbyn3+CigGOrl89lzhMymm6rj6vSbvSMml2AEQgH0x
# ggE0MIIBMAIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IImDEh4XJyuJHTDaI/sJx5corNhpDkuGWbnv5TWuR51LMAsGByqGSM49AgEFAARH
# MEUCIQDbSuj7KXspv8X+za13KkXxEIWXF0ElJoy/ekFD3cl2YwIgKJ83QJ7YIZD4
# zrBYiRtESfw9kHGv1kHZUGko9FeFOT0=
# SIG # End signature block
