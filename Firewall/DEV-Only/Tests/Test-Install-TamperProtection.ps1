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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDUK7x/ha/v7BWt
# r51pa6tjX9rciMnXs7LmryQV15IEVaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggE0MIIBMAIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IMBGYNf5UbFHL14XPXoJlbr/rwfY8R6dnOu35slHID9SMAsGByqGSM49AgEFAARH
# MEUCIQCbfCtf1THQQpnHcvIw0Vlk5OTIliUXpmb6q6FKz6J49AIgZ2WL2AP9Rkw6
# KVSdypLQE254BphE7P/GZ0bfU6ZWVQA=
# SIG # End signature block
