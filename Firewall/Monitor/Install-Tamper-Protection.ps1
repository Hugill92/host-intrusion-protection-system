# Install-Tamper-Protection.ps1
# Installs/updates the scheduled task that runs Firewall-Tamper-Check.ps1 as SYSTEM.

param(
  [ValidateSet("DEV","LIVE")]
  [string]$Mode = "LIVE",

  [string]$FirewallRoot = "C:\FirewallInstaller\Firewall",

  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$TaskName   = "Firewall Tamper Guard"
$ScriptPath = Join-Path $FirewallRoot "Monitor\Firewall-Tamper-Check.ps1"

if (-not (Test-Path $ScriptPath)) {
  throw "Tamper check script missing: $ScriptPath"
}

$argString = @(
  "-NoProfile",
  "-ExecutionPolicy","Bypass",
  "-File","`"$ScriptPath`"",
  "-Mode",$Mode
) -join " "

$Action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argString
$Trigger   = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew

if ($Force) {
  try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}
}

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null

Write-Host "[OK] Installed scheduled task: $TaskName"
Write-Host "     Mode:  + $Mode"
Write-Host "     Script: $ScriptPath"

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUGr4eg2hXxpq8mDVQzFq71jKf
# 6XugggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUQYqdNQc1EcKeh4tUhjmB68JnA5cwCwYH
# KoZIzj0CAQUABEcwRQIgdGuT2eDTklpLB8kht/Diefm5W6GALD0jjGst6G1+ZUgC
# IQCoyNhUvQRzD8Ys2zLP9xfJJnXb6UgLOymJksyi4CO2jQ==
# SIG # End signature block
