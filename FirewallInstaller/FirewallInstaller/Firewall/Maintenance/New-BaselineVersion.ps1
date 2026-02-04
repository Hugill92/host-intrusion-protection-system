# New-BaselineVersion.ps1
# Creates a versioned baseline snapshot + activates it
# Run elevated

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$StateDir   = "C:\Firewall\State"
$GoldenDir  = "C:\Firewall\Golden\Baselines"
$Baseline   = Join-Path $StateDir "baseline.json"
$HashFile   = Join-Path $StateDir "baseline.hash"
$MetaFile   = Join-Path $StateDir "baseline.meta.json"

New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
New-Item -ItemType Directory -Path $GoldenDir -Force | Out-Null

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")

# Capture baseline (stable fields; include DisplayName for better logs)
$rules = Get-NetFirewallRule |
  Select-Object Name, DisplayName, Enabled, Direction, Action, Profile, Group, Description |
  Sort-Object Name

$rulesJson = $rules | ConvertTo-Json -Depth 4
$rulesJson | Set-Content $Baseline -Encoding utf8

$hash = (Get-FileHash $Baseline -Algorithm SHA256).Hash
$hash | Set-Content $HashFile -Encoding ascii

$meta = [pscustomobject]@{
  Version     = $stamp
  CreatedUtc  = (Get-Date).ToUniversalTime().ToString("o")
  CreatedBy   = "$env:COMPUTERNAME\$env:USERNAME"
  RuleCount   = ($rules | Measure-Object).Count
  BaselineSha256 = $hash
}
($meta | ConvertTo-Json -Depth 3) | Set-Content $MetaFile -Encoding utf8

# Persist a versioned copy
$verBase = Join-Path $GoldenDir "baseline.v$stamp"
Copy-Item $Baseline "$verBase.json" -Force
Copy-Item $HashFile "$verBase.hash" -Force
Copy-Item $MetaFile "$verBase.meta.json" -Force

Write-Host "[OK] Baseline version created and activated: v$stamp"
Write-Host "     RuleCount=$($meta.RuleCount) SHA256=$hash"

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDxxL+/3AfX36zd
# 4zjA+ZiGJmP5pcd0ycd08ACELy1oG6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IMewQrRUTw4nrYNrbmT4vedo3vMdof3rlQ3cz/eS87LiMAsGByqGSM49AgEFAARH
# MEUCIEjgAAnsXtu2S4fWwuPFkKwcW8UgISZty6s7wPxW5NPYAiEAvP80PF/gfLqU
# 5yebTzT5pibiPBai3voHiZ5jz6HOVO8=
# SIG # End signature block
