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
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUShm6gQzRJ5hAqjOCrZyZKR3y
# OiSgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU2FBcMU2WV+T2sjn8KpWBlzOFn/cwCwYH
# KoZIzj0CAQUABEcwRQIhAJWH6TaHg/Wf7tE5a9ArOjarHYjlcdONb4kwyA7cpBby
# AiB32lDW3FaVdLt9nxMBXVC8whAaIl3BMCsx1lBPDvYD+g==
# SIG # End signature block
