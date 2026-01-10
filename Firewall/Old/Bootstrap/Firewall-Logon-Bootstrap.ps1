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
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUu5pb+avOSrLCWn4/dROuDKPN
# 4p6gggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU62fAeYBiAK5tPqWd+F6z1/mpDL8wDQYJ
# KoZIhvcNAQEBBQAEggEAwyesWgdM1C9L8Ula0id4IDT6WT0Hpnf6WXqZ7Xa/I8or
# Xr+VsARPNFinA9tyt+ZbU9BzjC2gXPYswfplMlLTJQb8/MIoo02GswWZ8kHAq50/
# hxLGqMnqN54hpuSsddtsxSO9QiW+Qi7etCoBpayEYMboDMkRzulKJasJ51iRBj55
# asN0cKhBVi+iyHP76p6PSGJvFSf1AVdiUT0HOIb62MMbUIVBskMJ+clZ8HD2imkU
# ws1YhIQOtB/h5/Q9h2oQ6N7UllfNZ5wICffSoq2K4BqozIrDplrwM7yqkLI+KSt7
# KqinjZDzYvA8YnUieHFFYu3Ocn+ZoWPcGxmW3ZqADg==
# SIG # End signature block
