# Tag-BaselineRules.ps1
param(
  [Parameter(Mandatory)][string]$OwnerTag  # e.g. "HomeBaseline" or "CorpStandard"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$BaselinePath = "C:\Firewall\State\baseline.json"
$MetaPath     = "C:\Firewall\State\baseline.meta.json"

if (!(Test-Path $BaselinePath)) { throw "Missing baseline.json" }

$version = "Unknown"
if (Test-Path $MetaPath) {
  try { $version = (Get-Content $MetaPath -Raw | ConvertFrom-Json).Version } catch {}
}

$baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json

foreach ($b in $baseline) {
  if (-not $b.Name) { continue }

  $desc = "FWCORE|Owner=$OwnerTag|Baseline=$version|Name=$($b.Name)"
  try {
    Set-NetFirewallRule -Name $b.Name -Group "FirewallCore" -Description $desc -ErrorAction Stop
  } catch {
    Write-Warning "Failed tagging $($b.Name): $($_.Exception.Message)"
  }
}

Write-Host "[OK] Tagged baseline rules with Owner=$OwnerTag and Baseline=$version"

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC9xmIgE1Dv2Ln7
# Ef27EuBM1AQlRYdU81YyUnOTJM6Oj6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IJRjXb4bVj/JYox/Ylr8j8ydtr0GXPuOMkpdyDzlWP9JMAsGByqGSM49AgEFAARH
# MEUCIQDJeKcJbeyDdu/p5hU61DtkC/xF0/IQxPlWzOc6aTm96wIgOpSsj9EAN5NK
# w3N7fagBFIkxe+6ikOlU35SNZ9/J/64=
# SIG # End signature block
