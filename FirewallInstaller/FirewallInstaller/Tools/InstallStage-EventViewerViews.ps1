[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Strict
)

$ErrorActionPreference = 'Stop'

$src = Join-Path $RepoRoot 'Firewall\Monitor\EventViews'
if (!(Test-Path -LiteralPath $src)) {
  throw "Source views folder missing: $src"
}

$evViews   = Join-Path $env:ProgramData 'Microsoft\Event Viewer\Views'
$coreViews = Join-Path $env:ProgramData 'FirewallCore\User\Views'

New-Item -ItemType Directory -Path $evViews   -Force | Out-Null
New-Item -ItemType Directory -Path $coreViews -Force | Out-Null

$files = Get-ChildItem -LiteralPath $src -Filter '*.xml' -File -ErrorAction Stop
if ($files.Count -eq 0) { throw "No *.xml files found in: $src" }

foreach ($f in $files) {
  Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $evViews   $f.Name) -Force
  Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $coreViews $f.Name) -Force
}

# ACL pass (Users read) — avoids “Access denied” when a toast action tries to open a view
$aclTool = Join-Path $RepoRoot 'Tools\Ensure-EventViewerViewAcl.ps1'
& $aclTool -Path $evViews, $coreViews -Filter 'FirewallCore*.xml' -Strict:$Strict

Write-Host "Install-stage complete: Event Viewer views staged + ACL ensured." -ForegroundColor Green

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDdpcuo2a/Zz+Dc
# fEY1ZHkDLf1akpu6Wi1xkwGHAfSYRKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IN1C5ip5U8Jhf1t5m8VopToC7sRh7M0GIXHb1bwZZYyuMAsGByqGSM49AgEFAARH
# MEUCIHE/fGyWijnGzd2FgA2ewi1iT2zCh4bRdV0OJF8La5/7AiEAqEDAfX1fkvFZ
# YQRHhJ7nihwSoUhZ69eQEeVb/w0eKDA=
# SIG # End signature block
