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



# ==========================================
# FIREWALL MONITOR INSTALLER (ONE-TIME)
# ==========================================
& "C:\Firewall\Firewall-Bootstrap.ps1"


Write-Host "[*] Installing Firewall Monitor..."

$Base = "C:\Firewall"
$Mon  = "$Base\Monitor"
$Logs = "$Base\Logs"

New-Item -ItemType Directory -Path $Mon  -Force | Out-Null
New-Item -ItemType Directory -Path $Logs -Force | Out-Null

# ---------------- BOOTSTRAP TASK ----------------
$BootstrapTask = "Firewall Bootstrap"

$BootstrapAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$Mon\Firewall-Bootstrap.ps1`""

$BootstrapTriggers = @(
    (New-ScheduledTaskTrigger -AtStartup)
    (New-ScheduledTaskTrigger -AtLogOn)
)

$BootstrapPrincipal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$BootstrapSettings = New-ScheduledTaskSettingsSet `
    -Hidden `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask `
    -TaskName $BootstrapTask `
    -Action $BootstrapAction `
    -Trigger $BootstrapTriggers `
    -Principal $BootstrapPrincipal `
    -Settings $BootstrapSettings `
    -Force

# ---------------- RUN BOOTSTRAP ONCE ----------------
powershell.exe `
  -NoProfile `
  -ExecutionPolicy Bypass `
  -NonInteractive `
  -WindowStyle Hidden `
  -File "$Mon\Firewall-Bootstrap.ps1"

if (-not [System.Diagnostics.EventLog]::SourceExists("Firewall-Tamper")) {
    New-EventLog -LogName "Firewall" -Source "Firewall-Tamper"
}


Write-Host "[OK] Firewall Monitor installed (SYSTEM / silent)"

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUEHMIpkf/BpMRZkMZA5d3fbMk
# +eagggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUUKPHHS1PZX4/4qkqL1QqPDF2SdowCwYH
# KoZIzj0CAQUABEYwRAIgWXcvmxO+OaGM17S8w0YwPFkpEaCWfdXLTNpLD5DAQxIC
# IAjnxMpTmmEBOsoS9aAAU9yWUbzSuJrk46zLhMeY/Tm0
# SIG # End signature block
