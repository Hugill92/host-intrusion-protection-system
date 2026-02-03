function Invoke-FirewallBaselineDetection {
    param(
        [string]$FirewallRoot = "C:\FirewallInstaller\Firewall"
    )

    $BaselinePath = Join-Path $FirewallRoot "State\Baseline\baseline.sha256.json"
    if (-not (Test-Path $BaselinePath)) {
        throw "Baseline missing"
    }

    $baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
    $algo = $baseline.Algorithm

    $drift = @()
    foreach ($item in $baseline.Items) {
        if (-not (Test-Path $item.Path)) {
            $drift += @{ Type="MissingFile"; Path=$item.Path }
            continue
        }

        $h = (Get-FileHash -Algorithm $algo -Path $item.Path).Hash
        if ($h -ne $item.Sha256) {
            $drift += @{ Type="HashMismatch"; Path=$item.Path }
        }
    }

    $rules = Get-NetFirewallRule | Select DisplayName, Enabled, Action
    $profiles = Get-NetFirewallProfile
    $malicious = @()

    foreach ($r in $rules) {
        if ($r.DisplayName -like "WFP-*") {
            if (-not $r.Enabled) {
                $malicious += "Rule disabled: $($r.DisplayName)"
            }
            if ($r.Action -eq "Allow") {
                $malicious += "Allow rule present: $($r.DisplayName)"
            }
        }
    }

    foreach ($p in $profiles) {
        if ($p.DefaultInboundAction -ne "Block") {
            $malicious += "Inbound default not BLOCK: $($p.Name)"
        }
    }

    return [pscustomobject]@{
        DriftDetected     = ($drift.Count -gt 0)
        DriftItems        = $drift
        MaliciousDetected = ($malicious.Count -gt 0)
        MaliciousFindings = $malicious
    }
}

Export-ModuleMember -Function Invoke-FirewallBaselineDetection

# SIG # Begin signature block
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUNmeabPfFNvkrtW0nY8gaCYl5
# hs2gggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUZjnHFWEZDyiEJb65bCm20ZQBwokwCwYH
# KoZIzj0CAQUABEgwRgIhAN+X+0C5pSe64n5oUzX3oRM6X1AifSK30sNAvn9RBHqY
# AiEA2pmB8MnkfV/Vmsy1Aab4kks43m3131SFvCifQlL/98s=
# SIG # End signature block
