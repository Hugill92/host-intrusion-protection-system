# Enable-AllSigned.ps1
# Run elevated

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$cert = New-SelfSignedCertificate `
  -Type CodeSigningCert `
  -Subject "CN=FirewallCore Code Signing" `
  -CertStoreLocation "Cert:\LocalMachine\My"

# Trust it
$pub = "Cert:\LocalMachine\TrustedPublisher"
$root = "Cert:\LocalMachine\Root"
$null = Export-Certificate -Cert $cert -FilePath "$env:TEMP\fwcore.cer"
Import-Certificate -FilePath "$env:TEMP\fwcore.cer" -CertStoreLocation $pub | Out-Null
Import-Certificate -FilePath "$env:TEMP\fwcore.cer" -CertStoreLocation $root | Out-Null

# Sign scripts
$files = Get-ChildItem C:\Firewall -Recurse -Filter *.ps1 -File
foreach ($f in $files) {
  Set-AuthenticodeSignature -FilePath $f.FullName -Certificate $cert | Out-Null
}

# Enforce AllSigned
Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy AllSigned -Force

Write-Host "[OK] AllSigned enabled. Scripts signed: $($files.Count)"
Write-Host "     Certificate thumbprint: $($cert.Thumbprint)"

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCb3Y/Vj6ZF2pa1
# C2HqSekZIUqo5yq1j1QQ7yQZzN5c8qCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ID82OltlmkRfhRPbXrgGFeLFn+BJvLm2WAUF6xBBpKh1MAsGByqGSM49AgEFAARH
# MEUCIEnewCP+rHNDAr7s3tl31qdydhLGxVC8w4eFvs2ztBtiAiEAzrFz2Ico5lAF
# k8dlBJdwFYNWk99XfDxdkjpGpYISWOg=
# SIG # End signature block
