# ================= EXECUTION POLICY SELF-BYPASS =================
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Error "Constrained language mode detected. Exiting."
    exit 1
}

if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass') {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSCommandPath" @args
    exit $LASTEXITCODE
}
# =================================================================



# ============================================================
# FIREWALL LOGON BOOTSTRAP
# Ensures firewall monitor environment is ready
# Silent / Logon-safe
# ============================================================

$BaseDir    = "C:\Firewall"
$MonitorDir = "$BaseDir\Monitor"
$LogDir     = "$BaseDir\Logs"

# --- Ensure directories exist ---
foreach ($Dir in @($BaseDir, $MonitorDir, $LogDir)) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }
}

# --- Ensure Firewall Monitor task exists ---
$TaskName = "Firewall Monitor (Inbound+Outbound)"

if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {

    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File "C:\Firewall\Monitor\Firewall-Monitor-All.ps1"'

    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)

	$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -RunLevel Highest `
        -Force | Out-Null
}

# --- Exit silently ---
exit 0


# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUu5pb+avOSrLCWn4/dROuDKPN
# 4p6gggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU62fAeYBiAK5tPqWd+F6z1/mpDL8wCwYH
# KoZIzj0CAQUABEcwRQIhAIftYdFfQKPs8OVKDVk06m++XoZHLG3YS+nPVABH9cS4
# AiAWTZhimKkRTktWZLue7Uszoy8a8R3hpIxO09nY1wIvww==
# SIG # End signature block
