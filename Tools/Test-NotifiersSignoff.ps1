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
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCVwLX/P2UofRoo
# xRn/a+v/eZt6Y8iJ+59xQjavjzmn8aCCArUwggKxMIIBmaADAgECAhQD4857cPuq
# YA1JZL+WI1Yn9crpsTANBgkqhkiG9w0BAQsFADAnMSUwIwYDVQQDDBxGaXJld2Fs
# bENvcmUgT2ZmbGluZSBSb290IENBMB4XDTI2MDIwMzA3NTU1N1oXDTI5MDMwOTA3
# NTU1N1owWDELMAkGA1UEBhMCVVMxETAPBgNVBAsMCFNlY3VyaXR5MRUwEwYDVQQK
# DAxGaXJld2FsbENvcmUxHzAdBgNVBAMMFkZpcmV3YWxsQ29yZSBTaWduYXR1cmUw
# WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATEFkC5IO0Ns0zPmdtnHpeiy/QjGyR5
# XcfYjx8wjVhMYoyZ5gyGaXjRBAnBsRsbSL172kF3dMSv20JufNI5SmZMo28wbTAJ
# BgNVHRMEAjAAMAsGA1UdDwQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNV
# HQ4EFgQUqbvNi/eHRRZJy7n5n3zuXu/sSOwwHwYDVR0jBBgwFoAULCjMhE2sOk26
# qY28GVmu4DqwehMwDQYJKoZIhvcNAQELBQADggEBAJsvjHGxkxvAWGAH1xiR+SOb
# vLKaaqVwKme3hHAXmTathgWUjjDwHQgFohPy7Zig2Msu11zlReUCGdGu2easaECF
# dMyiKzfZIA4+MQHQWv+SMcm912OjDtwEtCjNC0/+Q1BDISPv7OA8w7TDrmLk00mS
# il/f6Z4ZNlfegdoDyeDYK8lf+9DO2ARrddRU+wYrgXcdRzhekkBs9IoJ4qfXokOv
# u2ZvVZrPE3f2IiFPbmuBgzdbJ/VdkeCoAOl+D33Qyddzk8J/z7WSDiWqISF1E7GZ
# KSjgQp8c9McTcW15Ym4MR+lbyn3+CigGOrl89lzhMymm6rj6vSbvSMml2AEQgH0x
# ggEzMIIBLwIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IKrO939x3ikCh89+fJ351CS0zi0wJlMX540siAAZugGfMAsGByqGSM49AgEFAARG
# MEQCIG3hmZ4tYwN6bVCz0sSh9o2a4Q/VMyyFqThzGKsjGkpZAiAjLmtcSE6g3LvE
# ZYdyrtvrDIKuF4a00srMOFf3KCMx3Q==
# SIG # End signature block
