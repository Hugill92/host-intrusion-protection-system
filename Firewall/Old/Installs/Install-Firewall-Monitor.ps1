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
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUEHMIpkf/BpMRZkMZA5d3fbMk
# +eagggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUUKPHHS1PZX4/4qkqL1QqPDF2SdowDQYJ
# KoZIhvcNAQEBBQAEggEA38Zv9jI387yTD36tQJMZqEqtMhWFCICv6xleUgjbV3O1
# RbygufIavoRF7iAhw4rgpGwB1TqOo3wi+vUtyn6GVNip8YAEOr9v/MBMWJWEPj0E
# mZcIeyo9hjVRKDbbH0rjJ4Fip2qcX8rFhKCbxFj7wJPfhf548g+EGJwTU/ZxMIqO
# myZnmJJensPoZnW9nh1Rd+45GiK7QXM3h05qlcZ9qn5YkAUR09J97AeAi6poHiY/
# K4elMZQVabfan3AQdeiSJKcZI/dOfodGNhGVQ5X5Up4T632To3pGoKVpYusyoqyY
# N6itRaPRnvaEnNp0MWwy+Ig94oi2Y8RzO3aGrdYJRw==
# SIG # End signature block
