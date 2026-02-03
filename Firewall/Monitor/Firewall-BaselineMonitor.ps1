$FirewallRoot = "C:\FirewallInstaller\Firewall"

Import-Module "$FirewallRoot\Modules\FirewallDetection.psm1" -Force
Import-Module "$FirewallRoot\Modules\FirewallNotifications.psm1" -Force

$SelfHealScript   = Join-Path $FirewallRoot "Monitor\Firewall-SelfHeal.ps1"
$AutoUpdateScript = Join-Path $FirewallRoot "Monitor\AutoUpdate-FirewallBaseline.ps1"
$AllowFlag        = Join-Path $FirewallRoot "State\Baseline\allow_update.flag"

function Notify($Severity,$Title,$Message,$TestId) {
    try {
        Send-FirewallNotification `
            -Severity $Severity `
            -Title $Title `
            -Message $Message `
            -Notify @("Popup","Event") `
            -TestId $TestId
    } catch {}
}

function TrustedUpdateWindow {
    if (-not (Test-Path $AllowFlag)) { return $false }
    $age = ((Get-Date).ToUniversalTime() - (Get-Item $AllowFlag).LastWriteTimeUtc).TotalMinutes
    return ($age -le 10)
}

while ($true) {
    try {
        $r = Invoke-FirewallBaselineDetection -FirewallRoot $FirewallRoot -BaselineMaxAgeDays 3

        if ($r.DriftDetected) {

            # ---- MALICIOUS WEAKENING ----
            if ($r.MaliciousDetected) {
                Notify "Critical" "Firewall compromise detected" `
                    ("Baseline drift with firewall weakening:`n" + ($r.MaliciousFindings -join "`n")) `
                    "Live-Baseline-Monitor"

                if (Test-Path $SelfHealScript) {
                    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SelfHealScript | Out-Null
                }

            # ---- BENIGN DRIFT (LEARNABLE) ----
            } else {
                if (TrustedUpdateWindow -and (Test-Path $AutoUpdateScript)) {
                    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AutoUpdateScript | Out-Null
                    Notify "Info" "Baseline updated" `
                        "Trusted update window detected. Baseline was refreshed." `
                        "Live-Baseline-Monitor"
                } else {
                    Notify "Warning" "Baseline drift detected" `
                        "No firewall weakening detected. Learning requires trusted update window." `
                        "Live-Baseline-Monitor"
                }
            }
        }
    } catch {}

    Start-Sleep -Seconds 60
}

# SIG # Begin signature block
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUGc6M/w0BKKFZ5b50QoOZUWGm
# J+egggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU748p2ZSoID0H7yYa+Yr68hIyvBAwCwYH
# KoZIzj0CAQUABEgwRgIhAM5AfHU7dUwZ7mCnjhbgBCWqZL1UAQBJiDgC2CmAoSeF
# AiEAoy7Foapx7FyNsuRIih/GZxzk4hyBH+9YkGpAQ3yesAA=
# SIG # End signature block
