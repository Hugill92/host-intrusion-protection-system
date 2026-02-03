# Register-FirewallCore-EventLog.ps1
# Ensures one dedicated log: FirewallCore
# Ensures all FirewallCore.* sources are bound to that log (repairable)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

$LogName = "FirewallCore"
$Sources = @(
  "FirewallCore-Core",
  "FirewallCore-Pentest",
  "FirewallCore-Notifier"
)

function Get-SourceBoundLog([string]$SourceName) {
  $root = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog"
  $logs = Get-ChildItem $root -ErrorAction SilentlyContinue
  foreach ($l in $logs) {
    $p = Join-Path $l.PSPath $SourceName
    if (Test-Path $p) { return $l.PSChildName }
  }
  return $null
}

# Ensure log exists
if (-not [System.Diagnostics.EventLog]::Exists($LogName)) {
  New-EventLog -LogName $LogName -Source $Sources[0]
}

# Ensure each source is bound to FirewallCore (repair if bound elsewhere)
foreach ($s in $Sources) {
  $bound = Get-SourceBoundLog $s
  if ($bound -and $bound -ne $LogName) {
    try { [System.Diagnostics.EventLog]::DeleteEventSource($s) } catch {}
  }
  if (-not [System.Diagnostics.EventLog]::SourceExists($s)) {
    New-EventLog -LogName $LogName -Source $s
  }
}

Write-Host "[OK] FirewallCore Event Log ready (sources bound)"

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1QF1YTE1q/8jaE2zXJ0Byv6G
# U3SgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUX45rChe64AQv19hvVDDkhhYV2lUwCwYH
# KoZIzj0CAQUABEYwRAIgPxiXxZ5Bat3OaTw0SfdpXV7tHBMvVDT+pmk1NhLzjUUC
# IATh8UVs5bPBtsAYudHvNJEE3omO10BwzYzbLCutIT+I
# SIG # End signature block
