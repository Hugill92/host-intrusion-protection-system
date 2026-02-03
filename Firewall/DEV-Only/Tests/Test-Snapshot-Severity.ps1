param([switch]$DevMode = $true)



. "$PSScriptRoot\Test-Helpers.ps1"
# =========================================
# DEV Bootstrap (installer-safe)
# =========================================
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Write-Host "[DEV] Testing snapshot severity escalation..."

# =========================================
# Imports
# =========================================
Import-Module "$ModulesDir\FirewallSnapshot.psm1" -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1" -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
. "$ModulesDir\Firewall-EventLog.ps1"

# =========================================
# Baseline snapshot (no change expected)
# =========================================
$snap1 = Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir
Start-Sleep -Seconds 2
$snap2 = Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir
$diff  = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap2 `
    -Diff $diff `
    -Mode DEV `
    -RunId "DEV-SEVERITY-NOCHANGE"

# =========================================
# Verify 4100
# =========================================
$info = Get-WinEvent -LogName Firewall -MaxEvents 5 |
    Where-Object { $_.Id -eq 4100 -and $_.Message -like "*DEV-SEVERITY-NOCHANGE*" }

if (-not $info) {
    Write-TestFail "Expected Information (4100) event not found"
}

Write-Host "[OK] Information severity verified (4100)"

# =========================================
# Create TEMP rule (Added → Error)
# =========================================
$ruleName = "DEV-SEVERITY-ADD-TEST"

New-NetFirewallRule `
    -Name $ruleName `
    -DisplayName "DEV Severity Add Test" `
    -Direction Outbound `
    -Action Allow `
    -Program "$env:SystemRoot\System32\notepad.exe" | Out-Null

Start-Sleep -Seconds 2

$snap3 = Get-FirewallSnapshot -Fast -SnapshotDir $SnapshotDir -StateDir $StateDir
$diff2 = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap3 `
    -Diff $diff2 `
    -Mode DEV `
    -RunId "DEV-SEVERITY-ADD"

$err = Get-WinEvent -LogName Firewall -MaxEvents 5 |
    Where-Object { $_.Id -eq 4102 -and $_.Message -like "*DEV-SEVERITY-ADD*" }

if (-not $err) {
    Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
    Write-TestFail "Expected Error (4102) event not found"
}

Write-Host "[OK] Error severity verified (4102)"

# =========================================
# Cleanup
# =========================================
Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue

Write-TestPass "Snapshot severity escalation test completed successfully"

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUAEx4cVTs9SvYuCj5Oqx2Qt0f
# ruOgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUbtF/ufwf1Nm+bLoCFM9FJtrdfOgwCwYH
# KoZIzj0CAQUABEYwRAIgZL37T41xxWNyDFzpkvlbtFKcJ2NA3GHbqbgqTx3IMvQC
# IG9Vu18ZBD0fyshSb0TrzVVnufEPC5H1UATnzNwTgtPS
# SIG # End signature block
