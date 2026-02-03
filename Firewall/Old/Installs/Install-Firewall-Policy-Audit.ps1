# Install-Firewall-Policy-Audit.ps1
# XML-based installer (universally compatible)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---- ENABLE AUDITING (SAFE TO RE-RUN) ----
auditpol /set /subcategory:"Filtering Platform Policy Change" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Filtering Platform Connection" /success:enable /failure:enable | Out-Null

# ---- PATHS ----
$TaskName = "Firewall Policy Audit Monitor"
$Script   = "C:\Firewall\Monitor\Firewall-Policy-Audit.ps1"
$XmlPath  = "$env:TEMP\Firewall-Policy-Audit.xml"

if (-not (Test-Path $Script)) {
    throw "Required script missing: $Script"
}

# ---- TASK XML ----
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Firewall policy audit monitor (user attribution)</Description>
  </RegistrationInfo>

  <Triggers>
    <TimeTrigger>
      <StartBoundary>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")</StartBoundary>
      <Repetition>
        <Interval>PT2M</Interval>
        <Duration>P3650D</Duration>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
    </TimeTrigger>
  </Triggers>

  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>

  <Settings>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>

  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File "$Script"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# ---- WRITE XML ----
$xml | Out-File -FilePath $XmlPath -Encoding Unicode -Force

# ---- REGISTER TASK ----
Register-ScheduledTask `
    -TaskName $TaskName `
    -Xml (Get-Content $XmlPath | Out-String) `
    -Force

Remove-Item $XmlPath -Force

Write-Host "[OK] Firewall Policy Audit Monitor installed successfully"

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJI8k4svby9lj6HKmHtQmmWab
# teygggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU3kPtmTi6KlFL5fikRR0+JZOFrEMwCwYH
# KoZIzj0CAQUABEcwRQIhAKntBw8xbFQlVSvOUrKdeFB8tGaTpUlbxxvKKLnaXNvB
# AiBge5SHNd7CNKrrvDIm5HcRy/kJmMXT1MyRZ03lr1GhGQ==
# SIG # End signature block
