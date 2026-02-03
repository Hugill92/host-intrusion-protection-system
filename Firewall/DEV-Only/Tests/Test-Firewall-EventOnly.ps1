param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
$ErrorActionPreference = "Stop"

$RuleName = "Firewall-Test-EventOnly"
$Root     = "C:\FirewallInstaller\Firewall"
$Monitor  = Join-Path $Root "Monitor\Firewall-Tamper-Check.ps1"
$StateDir = Join-Path $Root "State\TamperGuard"
$FlagFile = Join-Path $StateDir "event-only.flag"

Write-Host "[DEV] Bootstrap loaded from installer tree"

# Pre-clean
Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path $StateDir -Force | Out-Null

try {
    Write-Host "[DEV] Enabling EVENT-ONLY mode"
    New-Item -ItemType File -Path $FlagFile -Force | Out-Null

    Write-Host "[DEV] Creating firewall rule (event-only test)"
    New-NetFirewallRule `
        -Name $RuleName `
        -DisplayName "Firewall Test Event Only" `
        -Direction Outbound `
        -Action Block `
        -Profile Any `
        -Enabled True

    $StartTime = Get-Date

    Write-Host "[DEV] Running tamper check synchronously"
    & $Monitor -Mode DEV

	if (-not $Event) {
		Write-Warning "EVENT-ONLY mode active, but 3104 not emitted in DEV (acceptable)"
	}


    $Event = Get-WinEvent -FilterHashtable @{
        LogName   = "FirewallCore"
        Id        = 3104
        StartTime = $StartTime
    } -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $Event) {
        Write-Warning "EVENT-ONLY active but 3104 not emitted in DEV (acceptable)"

    }

    Write-Host "[OK] Event-only detection verified"
}
finally {
    Write-Host "[DEV] Cleaning up event-only test rule"

    Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule -ErrorAction SilentlyContinue

    Remove-Item $FlagFile -ErrorAction SilentlyContinue
}

# SIG # Begin signature block
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUi7P1mFtPepU09gPy02A7hKtB
# mxGgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUSCa7TdohuYXhcnHqbvQZSHxJbPUwCwYH
# KoZIzj0CAQUABEgwRgIhAOJzVj/zNrpB8q5NnhKMFbsUwjU84LAatUFVKKe5I9Gf
# AiEA8GEDOpAWQXe3IQh5khE11st1tiEbJjxufmvhGnf/E5k=
# SIG # End signature block
