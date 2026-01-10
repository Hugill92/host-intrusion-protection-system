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
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUV5dngUhmr16dW2Mwwl405ruo
# LvCgggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
# AQsFADAkMSIwIAYDVQQDDBlGaXJld2FsbENvcmUgQ29kZSBTaWduaW5nMB4XDTI2
# MDEwNTE4NTkwM1oXDTI3MDEwNTE5MTkwM1owJDEiMCAGA1UEAwwZRmlyZXdhbGxD
# b3JlIENvZGUgU2lnbmluZzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# AO9vgGkuxnRNQ6dCFa0TeSA8dI6C3aapCB6GSxZB+3OZNMqvmYxZGZ9g4vZVtjJ4
# 6Ffulr3b/KUcxQRiSj9JlFcUB39uWHCZYpGfPlpA9JXiNJuwPNAaWdG1S5DnjLXh
# QH0PAGJH/QSYfVzVLf6yrAW5ID30Dz14DynBbVAQuM7iuOdTu9vhdcoAi37T9O4B
# RjflfXjaDDWfZ9nyF3X6o5Z5pUmC2mUKuTXc9iiUGkWQoLe3wGDQBWZxgTONOr6s
# d1EfeQ2OI6PPoM54iqv4s2offPxl2jBd2aESkT+MK88e1iQGRLT8CC3IMKEvWb4q
# sY0jodjxx/EFW7YvmMmM+aUCAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBTz2KaYa/9Nh8LQ78T5DHApaEhuYzAN
# BgkqhkiG9w0BAQsFAAOCAQEAxu2SpjRshKTSAWeQGtiCWbEVP7OT02vnkSfX7kr0
# bSkyKXaizhA6egp6YWdof86uHLyXRny28sQSMzRqIW7zLFqouvoc83CF4GRexPqH
# cwt55G2YU8ZbeFJQPpfVx8uQ/JIsTyaXQIo6fhBdm4qAA20K+H214C8JL7oUiZzu
# L+CUHFsSbvjx4FyAHVmkRSlRbrqSgETbwcMMB1corkKY990uyOJ6KHBXTd/iZLZi
# Lg4e2mtfV7Jn60ZlzO/kdOkYZTxv2ctNVRnzP3bD8zTjagRvvp7OlNJ6MSUZuJPJ
# 1Cfikoa43Cqw6BN0tLRP80UKTFB484N3bgGU9UAqCKeckDGCAdkwggHVAgEBMDgw
# JDEiMCAGA1UEAwwZRmlyZXdhbGxDb3JlIENvZGUgU2lnbmluZwIQJzQwIFZoAq5J
# jY+vZKoYnzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUPd3O/nKNce7xDbFSveY6RlWWrjMwDQYJ
# KoZIhvcNAQEBBQAEggEA2gyG5NyfPr4dyiCtl6f5a2/8L9qMX93XUQ56ZRX9IVSa
# fDJRT4uBA5mTF/YGS2Sdwwq8+Kvum9lxwAE2Sx3euv05T/4feLbw645u/ovugUsJ
# fuA+PP7IKLlNmGCcsq0B+QcQcXLgIUz1hvm8lgw+/1jBMm4zDPjhFGTPRNzb73tq
# 6syC5GT8Ip++DUr6xOZDkDXMBOeqGgtFUF30nZ+px7F6wt673WLlMK/FRYgoMkqc
# 93hqb53wlOPWRV6tXu7b15ua1aRoc8ojBch1IAvE0sBGdQg2u3pGLMHuXZ8UHek1
# pzIMQhdlqm4Eg7UZ4UNpGwSJRsDS8E0+k3osJ2GxQA==
# SIG # End signature block
