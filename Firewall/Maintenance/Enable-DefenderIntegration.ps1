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
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnyMuFC5Y9YybaiIQiPvElm3V
# XSqgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
# hvcNAQELBQAwJzElMCMGA1UEAwwcRmlyZXdhbGxDb3JlIE9mZmxpbmUgUm9vdCBD
# QTAeFw0yNjAyMDMwNzU1NTdaFw0yOTAzMDkwNzU1NTdaMFgxCzAJBgNVBAYTAlVT
# MREwDwYDVQQLDAhTZWN1cml0eTEVMBMGA1UECgwMRmlyZXdhbGxDb3JlMR8wHQYD
# VQQDDBZGaXJld2FsbENvcmUgU2lnbmF0dXJlMFkwEwYHKoZIzj0CAQYIKoZIzj0D
# AQcDQgAExBZAuSDtDbNMz5nbZx6Xosv0IxskeV3H2I8fMI1YTGKMmeYMhml40QQJ
# wbEbG0i9e9pBd3TEr9tCbnzSOUpmTKNvMG0wCQYDVR0TBAIwADALBgNVHQ8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFKm7zYv3h0UWScu5+Z98
# 7l7v7EjsMB8GA1UdIwQYMBaAFCwozIRNrDpNuqmNvBlZruA6sHoTMA0GCSqGSIb3
# DQEBCwUAA4IBAQCbL4xxsZMbwFhgB9cYkfkjm7yymmqlcCpnt4RwF5k2rYYFlI4w
# 8B0IBaIT8u2YoNjLLtdc5UXlAhnRrtnmrGhAhXTMois32SAOPjEB0Fr/kjHJvddj
# ow7cBLQozQtP/kNQQyEj7+zgPMO0w65i5NNJkopf3+meGTZX3oHaA8ng2CvJX/vQ
# ztgEa3XUVPsGK4F3HUc4XpJAbPSKCeKn16JDr7tmb1WazxN39iIhT25rgYM3Wyf1
# XZHgqADpfg990MnXc5PCf8+1kg4lqiEhdROxmSko4EKfHPTHE3FteWJuDEfpW8p9
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIjCCAR4CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUiS7RWBHu2gmc9XlAeuLP4xEKpu0wCwYH
# KoZIzj0CAQUABEYwRAIgc0IWIA56k7uwSKueYHHTVrBBCSkdz5iwffqYZO94PaIC
# ID4MtC9JGGy/Si31TbIoCAi9//X5Y+RN1xtvHHzTAddx
# SIG # End signature block
