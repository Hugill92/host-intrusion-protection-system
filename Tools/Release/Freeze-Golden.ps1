<#
One-command “release freeze”.
1) Signs all scripts
2) Builds payload manifest
3) Verifies signatures + manifest sanity
#>

[CmdletBinding()]
param(
  [string]$Root = "C:\Firewall",
  [string]$Thumbprint = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function STEP($m){ Write-Host "[*] $m" }
function OK($m){ Write-Host "[OK] $m" }

# -----------------------------
# Resolve Release tools CORRECTLY
# -----------------------------
$ReleaseRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$sign = Join-Path $ReleaseRoot "Sign-FirewallCoreScripts.ps1"
$man  = Join-Path $ReleaseRoot "Build-FileManifest.ps1"

if (-not (Test-Path $sign)) { throw "Missing: $sign" }
if (-not (Test-Path $man))  { throw "Missing: $man"  }

# -----------------------------
# 1/3 Sign payload
# -----------------------------
STEP "1/3 Signing Firewall payload..."
& $sign -Root $Root -Thumbprint $Thumbprint

# -----------------------------
# 2/3 Build manifest
# -----------------------------
STEP "2/3 Building manifest..."
$out = Join-Path $Root "Golden\payload.manifest.sha256.json"
& $man -Root $Root -OutFile $out

# -----------------------------
# 3/3 Verify signatures
# -----------------------------
STEP "3/3 Verifying signatures..."

$bad = Get-ChildItem $Root -Recurse -File -Force |
  Where-Object { $_.Extension -in ".ps1",".psm1",".psd1" } |
  ForEach-Object {
    $s = Get-AuthenticodeSignature -FilePath $_.FullName
    if ($s.Status -ne "Valid") { $_.FullName }
  }

if ($bad) {
  throw ("Some scripts are not Valid-signed:`n" + ($bad -join "`n"))
}

OK "Golden freeze complete."
OK "Manifest written to:"
OK "  $out"

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDXEdpggDSa2yfU
# fQwFcGPcWdLY0BREb/RvbeRI0BKy2aCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IKpMvhUzSG4O92LomsYz+6LhQ+zpDNHPdbqJXYN107X1MAsGByqGSM49AgEFAARH
# MEUCIQDpZzn4z55xDVr33xFsd8G6ukIlqG5wSLJDAa0pyi/QtgIgLk8Y9aB+8N/z
# 1LYKtQc2h/p30fulYZ6iMuOLob8AhSw=
# SIG # End signature block
