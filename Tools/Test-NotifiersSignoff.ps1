param(
  [ValidateSet("Info","Warn","Critical","All")]
  [string]$Severity = "All",
  [string]$TestId = ("SIGNOFF-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
)

$ErrorActionPreference = "Stop"

# Ensure notifier module is loaded (Send-FirewallNotification)
if (-not (Get-Command Send-FirewallNotification -ErrorAction SilentlyContinue)) {
    $repoRoot = (& git rev-parse --show-toplevel 2>$null)
    if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

    $modPath = Join-Path $repoRoot "Firewall\Modules\FirewallNotifications.psm1"
    if (-not (Test-Path $modPath)) {
        throw "Missing module: $modPath"
    }

    Import-Module $modPath -Force

    if (-not (Get-Command Send-FirewallNotification -ErrorAction SilentlyContinue)) {
        throw "Failed to load Send-FirewallNotification from $modPath"
    }
}


$LogRoot = Join-Path $env:ProgramData "FirewallCore\Logs"
New-Item -ItemType Directory -Force $LogRoot | Out-Null
$LogPath = Join-Path $LogRoot ("Notifiers-Signoff_{0}.log" -f $TestId)

function Log([string]$msg) {
  $line = ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $msg)
  $line | Tee-Object -FilePath $LogPath -Append | Out-Host
}

function Run-One([string]$sev, [string]$expectedSound, [string]$expectedAutoClose) {
  Log ""
  Log "=== SIGNOFF START: $sev ==="
  Log "Expected: Sound=$expectedSound | AutoClose=$expectedAutoClose | Click->EV Filtered View"
  if ($sev -eq "Critical") {
    Log "Expected Critical: NO autoclose | Close/X disabled | Manual Review required | Remind every 10s until acknowledged"
  }

  Log "Triggering notification..."
  try {
    # Adjust arguments here to match your actual function signature
    Send-FirewallNotification -Severity $sev -EventId 3000 -Title "$sev SIGNOFF" -Message "Signoff test ($TestId)" -TestId $TestId
    Log "[OK] Triggered $sev notification (TestId=$TestId)"
  } catch {
    Log "[FAIL] Trigger failed: $($_.Exception.Message)"
    throw
  }

  Log "Operator checks:"
  Log "  1) Confirm style for $sev"
  Log "  2) Confirm sound plays: $expectedSound"
  Log "  3) Confirm auto-close: $expectedAutoClose"
  Log "  4) Click notification -> must open Event Viewer filtered view (FirewallCore log + correct provider/event filter)"
  Log "  5) Confirm logs record: severity/eventid/context/click-handler result"
  if ($sev -eq "Critical") {
    Log "  6) Confirm Close/X does NOT dismiss"
    Log "  7) Confirm Manual Review acknowledges (reminders stop)"
    Log "  8) Confirm reminders repeat about every 10s until acknowledged"
  }

  Log "=== SIGNOFF END: $sev (manual verification required) ==="
}

$targets = @()
if ($Severity -eq "All") { $targets = @("Info","Warn","Critical") } else { $targets = @($Severity) }

foreach ($t in $targets) {
  switch ($t) {
    "Info"     { Run-One "Info"     "ding.wav"   "15s" }
    "Warn"     { Run-One "Warn"     "chimes.wav" "30s" }
    "Critical" { Run-One "Critical" "chord.wav"  "Never" }
  }
}

Log ""
Log "[DONE] Signoff run complete. Log: $LogPath"

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUAZY3wHYs3kPYaOscvrYUOVNF
# zQqgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUidt1WUGDdk0UeeOyNkKCUSPYGkcwCwYH
# KoZIzj0CAQUABEcwRQIhAMNWc3h62Ym/Q0WbI8hT7HjlcsQq7XwklZm2l1qpfALJ
# AiA9Dt5ogICsTgFRvn/lT2iL0qt2XD9KIgICEURj4ZMEyw==
# SIG # End signature block
