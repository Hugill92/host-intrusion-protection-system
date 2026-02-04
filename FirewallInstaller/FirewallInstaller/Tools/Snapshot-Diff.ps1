[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Old,
  [Parameter(Mandatory)][string]$New,
  [string]$OutFile = "C:\FirewallInstaller\Tools\Snapshot-Diff.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Lines($p) { Get-Content -LiteralPath $p -ErrorAction Stop }

$oldLines = Get-Lines $Old
$newLines = Get-Lines $New

# Line diff (simple + reliable)
$diff = Compare-Object -ReferenceObject $oldLines -DifferenceObject $newLines -IncludeEqual:$false -PassThru |
  ForEach-Object { $_ }

New-Item -ItemType Directory -Path (Split-Path -Parent $OutFile) -Force | Out-Null

"Snapshot Diff" | Set-Content $OutFile
"OLD: $Old" | Add-Content $OutFile
"NEW: $New" | Add-Content $OutFile
"Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $OutFile
"" | Add-Content $OutFile

"==============================" | Add-Content $OutFile
"RAW LINE DIFF" | Add-Content $OutFile
"==============================" | Add-Content $OutFile
$diff | Add-Content $OutFile

"" | Add-Content $OutFile
"==============================" | Add-Content $OutFile
"NOTE" | Add-Content $OutFile
"==============================" | Add-Content $OutFile
"RAW LINE DIFF is blunt by design. Use it to verify tasks, rules, profile defaults, golden files, and signature changes." | Add-Content $OutFile

Write-Host "[OK] Wrote diff: $OutFile"

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB6mxxgVy+HnOg4
# 3U4Ipmvv+Av/wdIA55YDJHGY5gn54KCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IOrwM36eb2f/tvjImApyYc12G3MvWCLslbfCpfbLvaksMAsGByqGSM49AgEFAARG
# MEQCIGbOemG4LuA3qW2LOqHg+ORcVsdVoXrIjXsJlXqmLtRdAiBCIdEa/N6EzIwa
# JtC78EeVPAL7/NXJlw+94SIiVbF7Dg==
# SIG # End signature block
