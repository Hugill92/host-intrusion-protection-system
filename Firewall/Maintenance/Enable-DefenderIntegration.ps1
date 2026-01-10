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
# MIIFhQYJKoZIhvcNAQcCoIIFdjCCBXICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnyMuFC5Y9YybaiIQiPvElm3V
# XSqgggMYMIIDFDCCAfygAwIBAgIQdCqyfY2FxKFD6sp8IkBmbDANBgkqhkiG9w0B
# AQsFADAiMSAwHgYDVQQDDBdGaXJld2FsbCBTY3JpcHQgU2lnbmluZzAeFw0yNjAx
# MDUxOTE2NDdaFw0yNzAxMDUxOTM2NDdaMCIxIDAeBgNVBAMMF0ZpcmV3YWxsIFNj
# cmlwdCBTaWduaW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtTap
# EfALjizca4iaPTk9Pi9A4+PY0uOmVW+MbMFDikq1MuCo+n8kcZU+ATMZgkKDC48G
# Riw1fiIXwIqZvmhPiNlCF3cm7qNo/94D++b1VEsOhUodaEhLfbZPB3P9Qa3Dst2B
# qr0bTGfnMsWwKfBtLFcN9OwyR9rWTmMZj0bz5jzKtrHimzNFbBZLHVmLrvGKU2L6
# bzD/tKYf0Pytw8qm+hNLua0KbuXqZgAdpQiDm3+X4gyffdjyqKDYrSOKFjnNju97
# AiQVWedu2W+p79QIIDbXqaj7XEn48qnSXcwKHy2hRCrVpu+M+CIbQUHgRE4xNSq5
# wefzeYngr3zArrlY3QIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAww
# CgYIKwYBBQUHAwMwHQYDVR0OBBYEFNu3dtpR3b2Mv57dUxZhaRgbdSuVMA0GCSqG
# SIb3DQEBCwUAA4IBAQBfzReARyL/y3Uzjm4z5VE3Zl+w1aVRAyU/WQDPaD8Ys+ZU
# aiNSgA70izcR71f1/brJcvGW0wEsxjzfjoFUqL1VoPzop8+L3Lx9wClQJ3BHF8iN
# KtBTbyz7SF5pyml6LGDeu3s0oOPWIJLlzlW5N+d3enAY4nTjoiooCnMzB6SEu1sW
# exfnSHUlrfyZgrDMXXwLK8zk2Q0OECa1VNL5rgHjhrLsbA63ioBn90C8SEPKE/pD
# 7ema986A4acvVidzWl83jEFAGhJUybLBRh15hlziFFMBCiBMBsP16sz0ZankcHY8
# z4e9hSVR8rJbtqBpsKSd8BvailSrU5Ka5IIW6CyrMYIB1zCCAdMCAQEwNjAiMSAw
# HgYDVQQDDBdGaXJld2FsbCBTY3JpcHQgU2lnbmluZwIQdCqyfY2FxKFD6sp8IkBm
# bDAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG
# 9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIB
# FTAjBgkqhkiG9w0BCQQxFgQUiS7RWBHu2gmc9XlAeuLP4xEKpu0wDQYJKoZIhvcN
# AQEBBQAEggEAWgtnM/TLT1JlyqnxdoEga6PnhELH6mGZs5T6CYiI48la/G0niQDO
# Kp+vInko1wHvEYrYeii54/Pj05dSsibfwGzcd6PftHp5I6A7OIEt15zCYgZg2OvT
# R8sxPyXOqx2Q3GW+vT/wbrD82ywET8zKcV4tkizkdjg2o6mtCnAFiXumsnk5Mdes
# 1u+qdHi+zH+ALdqTwmSrR7nNFA2CCZ9BhwbqbL9qf8KjxFHERW61aPrRMn7t2CAU
# O1wn6XUXi99+YFMkye5/uhF0XIkfMQqIR3rC4dOTKRWmLr2V7Mw0zdukWZ9qWRAM
# h78Bp6Nb2Z9e8iKg9AZx9+VXxaJdRrlbYA==
# SIG # End signature block
