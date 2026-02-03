# ==========================================
# FIREWALL MONITOR - INBOUND + OUTBOUND
# Event ID 5157 (Blocked Connections)
# ==========================================

$LogName = "Security"
$EventID = 5157
$Since   = (Get-Date).AddMinutes(-30)

$Events = Get-WinEvent -FilterHashtable @{
    LogName   = $LogName
    Id        = $EventID
    StartTime = $Since
} -ErrorAction SilentlyContinue

if (-not $Events) {
    Write-Host "[OK] No blocked inbound or outbound connections in the last 30 minutes."
    return
}

foreach ($Event in $Events) {
    $Xml = [xml]$Event.ToXml()

    $Direction = ($Xml.Event.EventData.Data |
        Where-Object { $_.Name -eq "Direction" }).'#text'

    $Application = ($Xml.Event.EventData.Data |
        Where-Object { $_.Name -eq "Application" }).'#text'

    $DestIP = ($Xml.Event.EventData.Data |
        Where-Object { $_.Name -eq "DestAddress" }).'#text'

    $DestPort = ($Xml.Event.EventData.Data |
        Where-Object { $_.Name -eq "DestPort" }).'#text'

    Write-Host "=============================="
    Write-Host "BLOCKED CONNECTION DETECTED"
    Write-Host "Direction   : $Direction"
    Write-Host "Application : $Application"
    Write-Host "Destination : ${DestIP}:${DestPort}"
    Write-Host "Time        : $($Event.TimeCreated)"
}

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUE6MHuVfhNA+AWk7WEFyCjEf4
# VtCgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUjfpVXMDVEyE4zn6SXvmW9X75g+MwCwYH
# KoZIzj0CAQUABEcwRQIgfm21z5vUSMEXXHf4eaq+0qGL2adjP4jqDklBR44nq+8C
# IQC/dw2MPLSt/ipuf7rRwJ+LbhZNJJcwMbQqSomkI8yN6A==
# SIG # End signature block
