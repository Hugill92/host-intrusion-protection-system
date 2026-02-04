[CmdletBinding()]
param(
    [string]$FirewallRoot = "C:\FirewallInstaller\Firewall",

    # Files you want to lock for v1 baseline:
    [string[]]$Targets = @(
        "C:\FirewallInstaller\Firewall\Policy\Default-Inbound.txt",
        "C:\FirewallInstaller\Firewall\Policy\Default-Outbound.txt",
        "C:\FirewallInstaller\Firewall\Policy\Default-Policy.wfw"
    ),

    [ValidateSet("SHA256","SHA512")]
    [string]$Algorithm = "SHA256",

    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log($m){ if(-not $Quiet){ Write-Host $m } }

$StateDir    = Join-Path $FirewallRoot "State\Baseline"
$JsonOutPath = Join-Path $StateDir "baseline.sha256.json"
$TxtOutPath  = Join-Path $StateDir "baseline.sha256.txt"
New-Item $StateDir -ItemType Directory -Force | Out-Null

$items = @()

foreach ($p in $Targets) {
    if (-not (Test-Path $p)) {
        throw "Baseline target missing: $p"
    }

    $fi = Get-Item $p
    $hash = (Get-FileHash -Algorithm $Algorithm -Path $p).Hash

    $items += [pscustomobject]@{
        Path          = $fi.FullName
        Sha256        = $hash   # keep field name stable for v1 schema
        Length        = [int64]$fi.Length
        LastWriteTime = $fi.LastWriteTimeUtc.ToString("o")
    }
}

$baseline = [pscustomobject]@{
    SchemaVersion = 1
    Algorithm     = $Algorithm
    CreatedUtc    = (Get-Date).ToUniversalTime().ToString("o")
    FirewallRoot  = $FirewallRoot
    Items         = $items
}

$baseline | ConvertTo-Json -Depth 6 | Set-Content -Path $JsonOutPath -Encoding UTF8

# Also emit a simple checksums txt (handy for humans / CI)
$txt = $items | ForEach-Object { "{0}  {1}" -f $_.Sha256, $_.Path }
$txt | Set-Content -Path $TxtOutPath -Encoding ASCII

Log "[OK] Baseline written:"
Log "     $JsonOutPath"
Log "     $TxtOutPath"

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA6j0eiBf0UmaCq
# y9z2D74NSFK8ji/tCVcY0816wK77yKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IPCB9fZ89fFmrKFvUOxQmaS572NN4sulWwmxkKFEILpcMAsGByqGSM49AgEFAARH
# MEUCIQDFCof3Vf/Vij7EXkJkO0WLsUi25zNMCPzBX1h5zoki2gIgJCOJYtqfoY7o
# Wcvvi0IWtxp4n4EDz18rjhWite5PAFs=
# SIG # End signature block
