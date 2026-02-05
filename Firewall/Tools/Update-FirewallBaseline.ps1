# Update-FirewallBaseline.ps1
# Writes a new baseline.json + baseline.hash from the CURRENT firewall rules.
# Guarded by admin-override.token OR local admin membership.
#
# Usage:
#   1) Run Approve-BaselineUpdate.ps1 (short window), OR run as local admin
#   2) powershell -ExecutionPolicy Bypass -File .\Update-FirewallBaseline.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. "C:\Firewall\Modules\Firewall-EventLog.ps1"

$stateDir = "C:\Firewall\State"
if (!(Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

$tokenPath = Join-Path $stateDir "admin-override.token"
$baseline  = Join-Path $stateDir "baseline.json"
$hashPath  = Join-Path $stateDir "baseline.hash"

function Is-LocalAdmin {
  try {
    $me = [Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = New-Object Security.Principal.WindowsPrincipal($me)
    return $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function TokenValid {
  if (!(Test-Path $tokenPath)) { return $false }
  try {
    $until = (Get-Content $tokenPath -Raw -Encoding utf8).Trim() | Get-Date
    return ((Get-Date) -lt $until)
  } catch { return $false }
}

if (-not (Is-LocalAdmin) -and -not (TokenValid)) {
  Write-FirewallEvent -EventId 3222 -Type Error -Message "Baseline update denied: not admin and no valid admin-override.token."
  throw "Denied: not admin and no valid admin-override.token"
}

$rules = Get-NetFirewallRule | Select Name, DisplayName, Enabled, Direction, Action, Profile
($rules | ConvertTo-Json -Depth 4) | Set-Content -Path $baseline -Encoding utf8

$hash = (Get-FileHash $baseline -Algorithm SHA256).Hash
$hash | Set-Content -Path $hashPath -Encoding ascii

Write-FirewallEvent -EventId 3221 -Type Information -Message "Firewall baseline updated and locked. Rules=$($rules.Count)."
Write-Host "[OK] Baseline updated and locked. Rules=$($rules.Count)"

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCkEK4tv+rl623/
# KyLUCOCORSIqShYIm2j+/XLXY1sCIKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IIjx2R0SZKXZ2XjORHY6Dm+nZWyYtvjIfafSOYfMNFmGMAsGByqGSM49AgEFAARG
# MEQCIG7WtkSDYDH/PWnWx8EGPYOM2V5cFq/kw3j4LkS9mCnlAiBuXQXvSwWW5hox
# 4nVprGi/70lnPtMNeioxgHy+2+e6/Q==
# SIG # End signature block
