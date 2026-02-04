# Enable-DefenderIntegration.ps1
# Run elevated

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "[*] Enabling audit policy for process attribution..."
auditpol /set /subcategory:"Process Creation" /success:enable | Out-Null

# Include command line in 4688
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
  /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[OK] 4688 process attribution enabled (best-effort)."

# Firewall logging (pfirewall.log)
Write-Host "[*] Enabling Windows Firewall logging (pfirewall.log)..."
Set-NetFirewallProfile -Profile Domain,Private,Public `
  -LogAllowed $false -LogBlocked $true `
  -LogFileName "%systemroot%\system32\LogFiles\Firewall\pfirewall.log" `
  -LogMaxSizeKilobytes 16384

Write-Host "[OK] Firewall blocked logging enabled."

# Defender exclusions - only do if you actually see blocks in Defender/CFA.
# Keeping these minimal:
Write-Host "[*] Adding minimal Defender exclusions for Firewall Core working set..."
try {
  Add-MpPreference -ExclusionPath "C:\Firewall\State"
  Add-MpPreference -ExclusionPath "C:\Firewall\Logs"
  Add-MpPreference -ExclusionProcess "powershell.exe"
  Write-Host "[OK] Defender exclusions applied."
} catch {
  Write-Warning "Could not set Defender exclusions: $($_.Exception.Message)"
}

Write-Host "[DONE] Defender integration configured."

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCcDBv4mSFxLThl
# BesW4H0kj1Siypsg4AInsMLEkITIcqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IJd7RayBzkK3e6LKysQs0Eb2B5Km44X8PzPDbbc88L2iMAsGByqGSM49AgEFAARH
# MEUCICDKrNkcP19Qqa3OAM6aESWjtUZslWfF4TIsH7sJSA69AiEAnaQllDPcoTo4
# fXKiE/ZnNG/ygnGD1e6bbpthhyHPawM=
# SIG # End signature block
