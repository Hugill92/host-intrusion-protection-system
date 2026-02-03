Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$BaselineDir  = "C:\FirewallInstaller\Firewall\Live\Baseline"
$BaselineFile = Join-Path $BaselineDir "firewall-baseline.json"

if (-not (Test-Path $BaselineDir)) {
    New-Item -ItemType Directory -Path $BaselineDir -Force | Out-Null
}

function Snapshot-Rules {
    Get-NetFirewallRule |
        Select-Object `
            InstanceID,
            DisplayName,
            Enabled,
            Action,
            Profile,
            Direction,
            PolicyStoreSourceType,
            RuleGroup
}

# --- Create baseline if missing ---
if (-not (Test-Path $BaselineFile)) {
    Snapshot-Rules |
        ConvertTo-Json -Depth 6 |
        Out-File $BaselineFile -Encoding UTF8

    Write-Host "[LIVE] Baseline created - no comparison performed"
    return
}

$baseline = Get-Content $BaselineFile -Raw | ConvertFrom-Json
$current  = Snapshot-Rules

$diff = Compare-Object `
    $baseline `
    $current `
    -Property `
        InstanceID,
        Enabled,
        Action,
        Profile,
        Direction `
    -PassThru

if ($diff) {

    # Severity hook (event + future toast)
    . "C:\FirewallInstaller\Firewall\System\Write-FirewallSeverity.ps1" `
        -Severity "HIGH" `
        -Title "Firewall Rule Instance Modified" `
        -Details "One or more firewall rule instances changed from baseline." `
        -Context @{
            ChangedRules = $diff |
                Select-Object DisplayName, Profile, Enabled, Action, Direction
            Count     = $diff.Count
            User      = $env:USERNAME
            Host      = $env:COMPUTERNAME
            Timestamp = (Get-Date).ToString("o")
        }

    Write-Host "[LIVE] Firewall rule INSTANCE change detected - HIGH severity"
}
else {
    Write-Host "[LIVE] No firewall rule changes detected"
}

# --- Update baseline AFTER detection ---
$current |
    ConvertTo-Json -Depth 6 |
    Out-File $BaselineFile -Encoding UTF8

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUeVx6Mf2OnTNr9kjjCWXXxB45
# Q/6gggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUJnxf0a2ZB5ueLv2qnWF+L/2IxpYwCwYH
# KoZIzj0CAQUABEcwRQIgTdrmbtiYVMES/22IsjJmDTwEZn2s8vtOwz/6588R2UwC
# IQCviulUR2+kaeJd40GazqrTwUw2tbJ1PNVNa1gKE8/syA==
# SIG # End signature block
