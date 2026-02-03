# Test-Firewall-User-Audit.ps1
# Purpose: Normal USER firewall change -> self-heal -> audit attribution test
# Run as NON-ADMIN

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Pick a random enabled firewall rule
$rule = Get-NetFirewallRule |
    Where-Object { $_.Enabled -eq "True" } |
    Get-Random

if (-not $rule) {
    Write-Host "[FAIL] No enabled firewall rules found."
    exit 1
}

$ruleName = $rule.Name

Write-Host "Disabling firewall rule as USER:"
Write-Host "  Name: $ruleName"
Write-Host ""

# Disable rule
Disable-NetFirewallRule -Name $ruleName

Write-Host "Rule disabled."
Write-Host "Waiting for self-heal and audit attribution (about 2-3 minutes)..."
Write-Host ""

# Wait longer than audit interval
Start-Sleep -Seconds 160

# Verify rule restored
$restored = (Get-NetFirewallRule -Name $ruleName).Enabled

# Check Firewall log for audit event
$auditEvent = Get-WinEvent -LogName Firewall -MaxEvents 50 |
    Where-Object {
        $_.Id -eq 9300 -and $_.Message -match [regex]::Escape($ruleName)
    } |
    Select-Object -First 1

Write-Host "RESULTS:"
Write-Host "--------"

if ($restored -eq "True") {
    Write-Host "[OK] Rule was self-healed"
} else {
    Write-Host "[FAIL] Rule was NOT restored"
}

if ($auditEvent) {
    Write-Host "[OK] Audit event detected:"
    Write-Host "     $($auditEvent.Message)"
} else {
    Write-Host "[FAIL] No audit attribution event (9300) found"
}

exit 0

# SIG # Begin signature block
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPulctbE+4wT+l71j9c0NJV00
# ljagggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUpCpEPVCOwTNLJKdsvyZmHVluBpowCwYH
# KoZIzj0CAQUABEgwRgIhAPcu/zhN20lr2orCQFzxylGQJtA1uVFqZ02DUFRjXPMV
# AiEAuMW/j5tYP0VmrmThM6DfFw/aLSE8d8LlOrXDsVHxtVg=
# SIG # End signature block
