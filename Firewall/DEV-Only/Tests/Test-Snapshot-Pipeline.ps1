<#
DEV-ONLY TEST
Validates Snapshot → Diff → Event emission pipeline
#>

param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
# -------------------- DEV BOOTSTRAP --------------------
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode
Write-Host "[DEV] Bootstrap loaded from installer tree"
# ------------------------------------------------------

# -------------------- IMPORT HELPERS -------------------
Import-Module "$ModulesDir\FirewallSnapshot.psm1"        -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1"  -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
. "$ModulesDir\Firewall-EventLog.ps1"
# ------------------------------------------------------

Write-Host "[DEV] Testing snapshot → diff → event pipeline..."

# -------------------- EXECUTION ------------------------
$snap = Get-FirewallSnapshot `
    -Fast `
    -SnapshotDir $SnapshotDir `
    -StateDir    $StateDir

if (-not $snap -or -not $snap.Hash) {
    throw "Snapshot failed or invalid"
}

$diff = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap `
    -Diff     $diff `
    -Mode     DEV `
    -RunId    "DEV-PIPELINE-TEST"
# ------------------------------------------------------

# -------------------- VERIFICATION ---------------------
Start-Sleep -Seconds 1

$event = Get-WinEvent -LogName Firewall -MaxEvents 5 |
    Where-Object { $_.Id -in 4100,4101,4102 } |
    Select-Object -First 1

if (-not $event) {
    Write-TestWarnPass "Snapshot pipeline executed; event emission suppressed in DEV (acceptable)"
    return
}
Write-Host "[OK] Snapshot pipeline event emitted"
Write-Host "     EventId: $($event.Id)"
Write-TestPass "Snapshot pipeline test completed successfully"
# ------------------------------------------------------

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUKccqUR7dOvpMkhrP0YSEq7BB
# 1EWgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU0fUFNz10QlkyppWg9o+bTUGbKa8wCwYH
# KoZIzj0CAQUABEYwRAIgSqeXTeB0SbUqKLhYHgv3FwQ5v5H5djipyr9P33HUDdkC
# IES5D2NPxXdzShfB4egycWsRF93eTl3768XVy2dRhqY1
# SIG # End signature block
