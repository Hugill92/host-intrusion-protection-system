<#
Builds a SHA256 manifest for all payload files.
Outputs JSON with paths relative to root.
Recommended output path:
  C:\Firewall\Golden\payload.manifest.sha256.json
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$Root = "C:\Firewall",

  [string]$OutFile = "C:\Firewall\Golden\payload.manifest.sha256.json",

  # What to include
  [string[]]$IncludeExtensions = @(".ps1",".psm1",".psd1",".cmd",".bat",".json",".md",".txt",".cer",".count",".hash"),

  # Optional: exclude transient logs/state
  [string[]]$ExcludePathContains = @("\Logs\", "\State\wfp.bookmark.json", "\State\wfp.strikes.json", "\State\wfp.blocked.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function STEP($m){ Write-Host "[*] $m" }
function OK($m){ Write-Host "[OK] $m" }

$rootFull = (Resolve-Path $Root).Path
STEP "Building manifest for: $rootFull"

$files = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force |
  Where-Object { $IncludeExtensions -contains $_.Extension.ToLowerInvariant() }

# Exclusions (by substring match)
if ($ExcludePathContains.Count -gt 0) {
  $files = $files | Where-Object {
    $p = $_.FullName
    -not ($ExcludePathContains | Where-Object { $p -like "*$_*" })
  }
}

STEP ("Hashing {0} files..." -f $files.Count)

$items = foreach ($f in $files) {
  $rel = $f.FullName.Substring($rootFull.Length).TrimStart("\")
  $h = (Get-FileHash -Algorithm SHA256 -Path $f.FullName).Hash
  [pscustomobject]@{
    Path = $rel
    Sha256 = $h
    Size = $f.Length
    LastWriteTimeUtc = $f.LastWriteTimeUtc.ToString("o")
  }
}

$manifest = [pscustomobject]@{
  Schema = "FirewallPayloadManifest.v1"
  Root   = $rootFull
  BuiltAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  Count  = $items.Count
  Items  = $items | Sort-Object Path
}

New-Item -ItemType Directory -Path (Split-Path $OutFile -Parent) -Force | Out-Null
$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding UTF8

OK "Manifest written: $OutFile"

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDndoKPSJfpIiP0
# pSp4nQvQd/g4ejBdVq4vTsefeAjCsaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggE1MIIBMQIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IJHI/eEVlh7u5RUtS/9wd2THTRKQSRdDpa6mGx0y0dYUMAsGByqGSM49AgEFAARI
# MEYCIQDIOuPjaR1/fCTRrSvXQmBhvwUVMN02e+P6uwICembPygIhAPUKHRQDVg5T
# ojB77Rnsu8fEieaMYZt2IRdD/nHExSmA
# SIG # End signature block
