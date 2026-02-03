# ==========================================
# FIREWALL BOOTSTRAP (SELF-HEAL)
# ==========================================

$TaskName   = "Firewall Core Monitor"
$ScriptPath = "C:\Firewall\Monitor\Firewall-Core.ps1"

$Exists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

# --- FIX WMI FIREWALL PERMISSIONS ---
$ns = "root\standardcimv2"
$sd = Get-CimInstance -Namespace root\cimv2 -ClassName __SystemSecurity

$admins = "BUILTIN\Administrators"
$users  = "BUILTIN\Users"

# Reset to safe baseline
Invoke-CimMethod -InputObject $sd -MethodName SetSecurityDescriptor `
    -Arguments @{ Descriptor = (Get-CimInstance -Namespace root\cimv2 -ClassName Win32_SecurityDescriptor) }

# Admins = Full
$null = cmd /c "wmic /namespace:\\root\standardcimv2 path __systemsecurity call SetSecurityDescriptor `"D:(A;;CCDCLCSWRPWPRCWD;;;BA)(A;;CCLCSWLO;;;BU)`""


if (-not $Exists) {

    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$ScriptPath`""

    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
    $Trigger.RepetitionInterval = (New-TimeSpan -Minutes 5)
    $Trigger.RepetitionDuration = (New-TimeSpan -Days 1)

    $Principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    $Settings = New-ScheduledTaskSettingsSet `
        -Hidden `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Settings $Settings `
        -Force
}

# SIG # Begin signature block
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUcJs0TD5lRwhQHf0OYLH/ND/J
# RregggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBJDCCASACAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUSYYdnzkFyKQPR5X9chSb5Z0tDk8wCwYH
# KoZIzj0CAQUABEgwRgIhAJQoWfp2PuLX2nSF1+WAceQvWXm90N2M3FjodB2Hz0zd
# AiEAiGJIE5EiT8MBtO9xIqMgafIDyYvARfsyaWYUeG7mo8E=
# SIG # End signature block
