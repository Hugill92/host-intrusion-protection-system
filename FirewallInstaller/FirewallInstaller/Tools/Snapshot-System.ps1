[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

"=== SNAPSHOT START === $(Get-Date -Format o)" | Out-File $OutFile

"`n--- FIREWALL RULES ---" | Out-File $OutFile -Append
Get-NetFirewallRule |
Sort DisplayName |
Select DisplayName, Direction, Action, Enabled, Profile, Program |
Format-Table -Auto | Out-String | Out-File $OutFile -Append

"`n--- SCHEDULED TASKS (Firewall) ---" | Out-File $OutFile -Append
schtasks /Query /FO LIST | Select-String "Firewall" | Out-File $OutFile -Append

"`n--- EXECUTION POLICY ---" | Out-File $OutFile -Append
Get-ExecutionPolicy -List | Format-Table | Out-String | Out-File $OutFile -Append

"`n--- EVENT LOGS ---" | Out-File $OutFile -Append
Get-WinEvent -ListLog Firewall | Format-List | Out-String | Out-File $OutFile -Append

"`n--- CERTIFICATES (Firewall related) ---" | Out-File $OutFile -Append
Get-ChildItem Cert:\LocalMachine\Root |
Where Subject -like "*Firewall*" |
Format-List | Out-String | Out-File $OutFile -Append

"`n--- GOLDEN MANIFEST ---" | Out-File $OutFile -Append
if (Test-Path "C:\Firewall\Golden\payload.manifest.sha256.json") {
    Get-Item "C:\Firewall\Golden\payload.manifest.sha256.json" |
    Format-List | Out-String | Out-File $OutFile -Append
} else {
    "Missing payload.manifest.sha256.json" | Out-File $OutFile -Append
}

"=== SNAPSHOT END ===" | Out-File $OutFile -Append

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAhlBXPub2JXiqS
# kyGx66PZnyAYmbfgDTdhqfcqOfgADqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IDIFdZqHQecnOofsmVePj7KFF0zqzJOhvLW/r9zls3NkMAsGByqGSM49AgEFAARG
# MEQCICf2FiMzBV7h6Tb+ALG/cxDabB17HTqoUuSbGz3A8h30AiAVdjxKm6WG/8H9
# RGT0rg+hd18A9LHaonUDsHgBnpgGXg==
# SIG # End signature block
