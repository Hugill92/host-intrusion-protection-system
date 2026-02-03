[CmdletBinding()]
param(
    [string]$FirewallRoot = "C:\FirewallInstaller\Firewall",

    # Files you want to lock for v1 baseline:
    [string[]]$Targets = @(
        "C:\FirewallInstaller\Firewall\Policy\Default-Inbound.txt",
        "C:\FirewallInstaller\Firewall\Policy\Default-Outbound.txt",
        "C:\FirewallInstaller\Firewall\Policy\Default-Policy.wfw"
    ),

    [ValidateSet("SHA256","SHA512")]
    [string]$Algorithm = "SHA256",

    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log($m){ if(-not $Quiet){ Write-Host $m } }

$StateDir    = Join-Path $FirewallRoot "State\Baseline"
$JsonOutPath = Join-Path $StateDir "baseline.sha256.json"
$TxtOutPath  = Join-Path $StateDir "baseline.sha256.txt"
New-Item $StateDir -ItemType Directory -Force | Out-Null

$items = @()

foreach ($p in $Targets) {
    if (-not (Test-Path $p)) {
        throw "Baseline target missing: $p"
    }

    $fi = Get-Item $p
    $hash = (Get-FileHash -Algorithm $Algorithm -Path $p).Hash

    $items += [pscustomobject]@{
        Path          = $fi.FullName
        Sha256        = $hash   # keep field name stable for v1 schema
        Length        = [int64]$fi.Length
        LastWriteTime = $fi.LastWriteTimeUtc.ToString("o")
    }
}

$baseline = [pscustomobject]@{
    SchemaVersion = 1
    Algorithm     = $Algorithm
    CreatedUtc    = (Get-Date).ToUniversalTime().ToString("o")
    FirewallRoot  = $FirewallRoot
    Items         = $items
}

$baseline | ConvertTo-Json -Depth 6 | Set-Content -Path $JsonOutPath -Encoding UTF8

# Also emit a simple checksums txt (handy for humans / CI)
$txt = $items | ForEach-Object { "{0}  {1}" -f $_.Sha256, $_.Path }
$txt | Set-Content -Path $TxtOutPath -Encoding ASCII

Log "[OK] Baseline written:"
Log "     $JsonOutPath"
Log "     $TxtOutPath"

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUzXXJvPzIu32L+OukYB0Lv2Tn
# 0nagggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUsO7BOBI+fx1Eg4XxYgDRAKN03ucwCwYH
# KoZIzj0CAQUABEYwRAIgbtqayCWvI0zkkoyKxk/Qla3x/3LEx8QS//N+ZcEDiiwC
# IClJYwVFDgP3glBj4VukLEzlJmX8N65CTY5P8/u41uJx
# SIG # End signature block
