<#
DEV TEST: Snapshot hash short-circuit
Validates that identical snapshots do NOT emit duplicate snapshot events
#>

param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
$ErrorActionPreference = "Stop"

# --- Bootstrap DEV paths ---
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Write-Host "[DEV] Testing snapshot hash short-circuit logic..."

# --- Import required modules ---
Import-Module "$ModulesDir\FirewallSnapshot.psm1" -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1" -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
. "$ModulesDir\Firewall-EventLog.ps1"

# --- Clear recent snapshot events ---
$startTime = Get-Date

# --- First snapshot (should emit event) ---
$snap1 = Get-FirewallSnapshot -Fast
$diff1 = Compare-FirewallSnapshots

Emit-FirewallSnapshotEvent `
    -Snapshot $snap1 `
    -Diff $diff1 `
    -Mode DEV `
    -RunId "DEV-HASH-TEST-1"

Start-Sleep -Seconds 2

# --- Second snapshot (no changes expected) ---
$snap2 = Get-FirewallSnapshot -Fast
$diff2 = Compare-FirewallSnapshots

try {
    Emit-FirewallSnapshotEvent `
        -Snapshot $snap2 `
        -Diff $diff2 `
        -Mode DEV `
        -RunId "DEV-HASH-TEST-2"
}
catch {
    # If the event layer rejects duplicate emits, that is acceptable as long as we do not log duplicates.
    Write-Warning ("Second snapshot emit threw (acceptable for short-circuit): " + $_)
}
Start-Sleep -Seconds 2

# --- Collect emitted snapshot events ---
$events = Get-WinEvent -FilterHashtable @{ LogName="Firewall"; StartTime=$startTime } -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -in 4100,4101,4102 -and $_.Message -like "*DEV-HASH-TEST-*" }

$eventCount = ($events | Measure-Object).Count

# --- Assert behavior ---
if ($eventCount -eq 1) {
    Write-TestPass "Snapshot hash short-circuit working (1 event emitted)"
}
else {
    Write-TestFail ("Expected 1 snapshot event, found " + $eventCount)
}

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUm0jMZ6Wc5UTRQa09mpXa2251
# KuagggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU2g/7cSho3wLyq/3sCf0aoAqweyAwCwYH
# KoZIzj0CAQUABEcwRQIhAM+2Uyb48o1Tiqkkf3MLIXmpiQC1Rv6A37VAAZ7B+uJ6
# AiBahV3Z9v13+mErKUuU7ATjpyeC3X1RWDxaVYXQJB/dVQ==
# SIG # End signature block
