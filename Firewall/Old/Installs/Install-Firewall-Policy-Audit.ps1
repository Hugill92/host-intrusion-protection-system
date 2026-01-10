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
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJI8k4svby9lj6HKmHtQmmWab
# teygggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU3kPtmTi6KlFL5fikRR0+JZOFrEMwDQYJ
# KoZIhvcNAQEBBQAEggEAntIczsIuJnhIuAHniKXLnJFVezmjwhayypnqSvI89jyW
# w31u3HYOZgZHQak+07K8dcJX+TZuSQGOJGuYGGtF5tSS9UGdBakPqnu2t7Li69ji
# tnmu6cw3vLePiCnQ3pQpa8ozBPgS9flfRh9pPwbAN13unePGH9j5QC7QsJlSPguZ
# jkVIxDka2vVTY9hfas7vEThmzmiKqK2kj/KdX9WKFXK9kkWdErVyBsB2JGWQwwck
# au3B+Pl0A7X9jpdAM1Nj7N41Hhq5LoCNHZA2IdRd8BV4TjPwOrFlt2RtmbUOzVxJ
# u7lDrMCnQ5x80ajmOmVznGkUCS3PrfxHwOVuayew2A==
# SIG # End signature block
