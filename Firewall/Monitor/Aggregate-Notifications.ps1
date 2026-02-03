Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

$FirewallRoot = "C:\FirewallInstaller\Firewall"
$Pending = Join-Path $FirewallRoot "State\NotifyQueue\Pending"

$windowSeconds = 10
$now = Get-Date

$files = Get-ChildItem $Pending -Filter *.json -ErrorAction SilentlyContinue
if ($files.Count -le 1) { return }

$items = foreach ($f in $files) {
    $d = Get-Content $f.FullName -Raw | ConvertFrom-Json
    [pscustomobject]@{
        File = $f
        Time = [datetime]$d.Time
        Severity = $d.Severity
        Title = $d.Title
        TestId = $d.TestId
    }
}

$recent = $items | Where-Object {
    ($now - $_.Time).TotalSeconds -le $windowSeconds
}

if ($recent.Count -gt 1) {
    $summary = @{
        Count     = $recent.Count
        Severity  = ($recent | Sort-Object Severity -Descending | Select-Object -First 1).Severity
        TestIds   = ($recent.TestId | Sort-Object -Unique)
        Titles    = ($recent.Title | Sort-Object -Unique)
    }

    $out = @{
        Time     = (Get-Date).ToString("o")
        Severity = $summary.Severity
        Title    = "[AGGREGATED ALERT] $($summary.Count) events detected"
        Message  = "Multiple related alerts detected within $windowSeconds seconds.`n`nTestIds:`n$($summary.TestIds -join "`n")"
        Notify   = @("Popup","Event")
        TestId   = "AGGREGATED"
    } | ConvertTo-Json -Depth 6

    $file = Join-Path $Pending ("notify_aggregate_{0}.json" -f ([guid]::NewGuid()))
    Set-Content -Path $file -Value $out -Encoding UTF8
}

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUb4dhXD6GghGf3J7H7A4UhsT5
# +OWgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU3JQgDNS6zYJaVTppaSmnNfOxWwcwCwYH
# KoZIzj0CAQUABEcwRQIhAJts4mxR0sGYsNkY9C0lo9dWg2kCNVRz9sAx6d3NbL09
# AiAtOEPrEU1wFCwyQT0nu+FGuy12hBfzjVlNnTfXL5eYsw==
# SIG # End signature block
