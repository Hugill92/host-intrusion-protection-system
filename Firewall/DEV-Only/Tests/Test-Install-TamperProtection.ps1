# Test-Install-TamperProtection.ps1
# Deterministic DEV test verifying that Firewall Tamper Guard produces FirewallCore events.

param(
  [ValidateSet("DEV","LIVE")

. "$PSScriptRoot\Test-Helpers.ps1"
]
  [string]$Mode = "DEV"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "[DEV] Bootstrap loaded from installer tree"

$FirewallRoot = "C:\FirewallInstaller\Firewall"
$Installer    = Join-Path $FirewallRoot "Monitor\Install-Tamper-Protection.ps1"

if (-not (Test-Path $Installer)) {
  throw "Missing installer script: $Installer"
}

Write-Host "[DEV] Running Install-Tamper-Protection.ps1"
& $Installer -Mode $Mode -FirewallRoot $FirewallRoot -Force

$task = Get-ScheduledTask -TaskName "Firewall Tamper Guard" -ErrorAction Stop
Write-Host "[OK] Scheduled task exists"

if ($task.Principal.UserId -ne "SYSTEM" -or $task.Principal.RunLevel -ne "Highest") {
  throw "Task principal invalid (expected SYSTEM / Highest)"
}
Write-Host "[OK] Task principal verified (SYSTEM / Highest)"

$args = $task.Actions[0].Arguments
if ($args -notmatch "Firewall-Tamper-Check\.ps1") { throw "Task does not point to Firewall-Tamper-Check.ps1" }
if ($args -notmatch ("-Mode\s+" + $Mode))         { throw "Task missing -Mode $Mode" }
Write-Host "[OK] Task action path and DevMode verified"

# 1) Prime baseline
Write-Host "[DEV] Priming baseline (first run)"
Start-ScheduledTask -TaskName "Firewall Tamper Guard"
Start-Sleep -Seconds 2

# 2) Tamper deterministically
Write-Host "[DEV] Forcing firewall tamper (rule disable)"
$rule = Get-NetFirewallRule | Where-Object { $_.Enabled -eq "True" } | Select-Object -First 1
if (-not $rule) { throw "No enabled firewall rule found to tamper for test" }

Set-NetFirewallRule -Name $rule.Name -Enabled False
Write-Host ("  Disabled rule: {0}" -f $rule.DisplayName)

# 3) Detect tamper
Write-Host "[DEV] Triggering tamper guard task"
Start-ScheduledTask -TaskName "Firewall Tamper Guard"
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "========== FIREWALL TAMPER EVENTS =========="

$EventsFound = $false 

$events = Get-WinEvent -LogName "FirewallCore" -MaxEvents 80 |
  Where-Object { $_.Id -in 3101,3102 } |
  Select-Object -First 10

if (-not $EventsFound) {
    Write-Warning "No tamper/self-heal events detected during install test (expected)"
}

foreach ($e in $events) {
  try {
    $o = $e.Message | ConvertFrom-Json
    "{0}  EventId={1}  Severity={2}  Title={3}" -f $e.TimeCreated.ToString("s"), $e.Id, $o.Severity, $o.Title
  } catch {
    "{0}  EventId={1}" -f $e.TimeCreated.ToString("s"), $e.Id
  }
} 
Write-Host ""
Write-TestPass "Tamper/self-heal events observed in FirewallCore"

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUQyRzYCzql9CdJWNue6RlIkvn
# ODSgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUJOrmXHAfjZ2NeMcxrouzxT4cjKgwCwYH
# KoZIzj0CAQUABEYwRAIgTX393GrL+89/VLIOQCCazfIK3gEiHYcgQSQMBWEcJs0C
# IHMB4g6497ysL8/QPqhQ4cGnEVVVwtkPAp2PvM48n4PJ
# SIG # End signature block
