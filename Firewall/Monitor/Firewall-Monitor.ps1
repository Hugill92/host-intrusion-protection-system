. "C:\Firewall\Modules\Firewall-EventLog.ps1"


# ================= EXECUTION POLICY SELF-BYPASS =================
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Error "Constrained language mode detected. Exiting."
    exit 1
}

if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass') {
    powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "$PSCommandPath" @args
    exit $LASTEXITCODE
}
# =================================================================



# ==========================================
# FIREWALL MONITOR (INBOUND + OUTBOUND)
# Event ID 5157 - BLOCKED CONNECTIONS
# SYSTEM / SILENT / LOGGING ONLY
# ==========================================

$LogFile = "C:\Firewall\Logs\Firewall-Blocked.log"
$Since   = (Get-Date).AddMinutes(-5)

$Events = Get-WinEvent -FilterHashtable @{
    LogName   = "Security"
    Id        = 5157
    StartTime = $Since
} -ErrorAction SilentlyContinue

if (-not $Events) {
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

    $Line = "[{0}] {1} | {2} | {3}:{4}" -f `
        $Event.TimeCreated, $Direction, $Application, $DestIP, $DestPort

    Add-Content -Path $LogFile -Value $Line -Encoding UTF8
}


Write-FirewallEvent `
    -Message "Firewall monitor heartbeat OK." `
    -EventId 1001 `
    -Type Information
	
	& "C:\Firewall\Monitor\Firewall-WFP-Analyze.ps1"


# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5F/19ObCyesRtCBNl1tY085k
# 5q2gggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU+ZZ9Cf9qTgx7KPTsqFwRklu1QQkwDQYJ
# KoZIhvcNAQEBBQAEggEAdo7gF6Q9+m7WvZh6v1ezmw0B1kb42yvgpASO0f9S6m+R
# ODDMzCxw8qJfyoB1u3ln0qjALJE407+CQCs8W1q9khc6pQZvsxAXqUnrTPXU/XsJ
# xvxWSt0M/SirWNGjMgLxeuAvlXNE58lNsfev1qeXvkmxqhnhHuJkpAvfykaTlkZH
# fefypznZRLni9oczNJjZq2/PFDgGvbYsSn7/mMl4dzagYa4zK42YH2TriVIffpFW
# tlsuK07RRTbpn9bufIlTXQSid+kXxLeoOU8JdffkrhZC/P66fnBERxY9dJvKXDhE
# lfZz/IFUJMEh09gFnPuwLtRZDJWfMw3XbyBGXXOOQQ==
# SIG # End signature block
