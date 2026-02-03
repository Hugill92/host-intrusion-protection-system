param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "DEV"
)

Write-Host "Starting Forced-WFP-C4 test"

if ($Mode -ne "LIVE") {
    Write-Host "[FORCED-RESULT] SKIPPED"
    exit 0
}

# ---- Notification hook (v1, before exit) ----
try {
    Import-Module "C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop
    Send-FirewallNotification -Severity Critical -Title "WFP enforcement not active" -Message "LIVE WFP C4 validation failed - enforcement not wired." -Notify @("Popup","Event") -TestId "Forced-WFP-C4"
}
catch {
    # best-effort only
}

Write-Error "WFP C4 LIVE enforcement is not yet implemented."
Write-Host "[FORCED-RESULT] FAIL"
exit 1

# ---- v1 Notification Hook (import + call) ----
try {
    Import-Module "C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop

    Send-FirewallNotification `
        -Severity Critical `
        -Title "WFP enforcement not active" `
        -Message "LIVE WFP C4 validation failed ??? enforcement not wired." `
        -Notify @("Popup","Event") `
        -TestId "Forced-WFP-C4"
}
catch {
    # Notifications are best-effort only
}

# ---- v1 Notification Hook (import + call) ----
try {
    Import-Module "C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop

    Send-FirewallNotification `
        -Severity Critical `
        -Title "WFP enforcement not active" `
        -Message "LIVE WFP C4 validation failed ??? enforcement not wired." `
        -Notify @("Popup","Event") `
        -TestId "Forced-WFP-C4"
}
catch {
    # Notifications are best-effort only
}

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU91BoAXZwE1gss2Ngk86CfMp8
# blqgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUYAhi/SMmFL9sC7AcT1X9YrwUrBswCwYH
# KoZIzj0CAQUABEcwRQIhALgIPShzSfn7rvJfyA9doxIVQP1Rkb6EaNYsqi2LKO3Y
# AiA6SY0kN41iwJUkgIM8nxZqz5cTgzX/Elggjl0LtjdVtA==
# SIG # End signature block
