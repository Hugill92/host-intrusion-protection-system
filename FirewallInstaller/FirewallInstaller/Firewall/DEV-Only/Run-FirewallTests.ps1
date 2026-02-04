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
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC05SlPRdIQDOP8
# ElHFtpI5+fkpig5m+FWJcKbnOglUB6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggE1MIIBMQIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IBDs26SUKq83e9gKe9RENnxHA5SdPuAha0ShDVI69GOJMAsGByqGSM49AgEFAARI
# MEYCIQDcOoJ3i5dZds3j1Zpu00pkh4PTzFhSSNAsoYCHP1G3BwIhAM+aZq2BJT7j
# DqMNAnpWbhztG5yjBZUkp9Xru+wjOr6T
# SIG # End signature block
