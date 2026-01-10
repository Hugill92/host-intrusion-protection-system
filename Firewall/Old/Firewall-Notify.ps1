# ==========================================
# FIREWALL BLOCK NOTIFIER (USER CONTEXT)
# ==========================================

$LogFile   = "C:\Firewall\Logs\Firewall-Blocked.log"
$StateFile = "$env:LOCALAPPDATA\FirewallNotify.last"

if (-not (Test-Path $LogFile)) {
    return
}

$LastRead = if (Test-Path $StateFile) {
    Get-Content $StateFile | Get-Date
} else {
    Get-Date "2000-01-01"
}

$NewEvents = Get-Content $LogFile |
    Where-Object {
        ($_ -match '^\d{4}-\d{2}-\d{2}') -and
        ((Get-Date ($_ -split '\|')[0]) -gt $LastRead)
    }

if (-not $NewEvents) {
    return
}

# Update state
(Get-Date).ToString("o") | Set-Content $StateFile

# Load toast support
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null

$Template = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>Firewall Blocked Connection</text>
      <text>$($NewEvents[-1])</text>
    </binding>
  </visual>
</toast>
"@

$Xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$Xml.LoadXml($Template)

$Toast = [Windows.UI.Notifications.ToastNotification]::new($Xml)
$Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Firewall Monitor")
$Notifier.Show($Toast)

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUoPfb22UKCdYbw0SI0nWZI9o+
# wnmgggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUPWWXqONrly8cfdiLG6hFO4VmaEowDQYJ
# KoZIhvcNAQEBBQAEggEARAiLblvC6f1lClcaJ6BvAkAITCOUA1CnyXdIq88dJJ8d
# sUjtbLEo7Dz4KcJNSsUcfyvSAEcl79QJVbpp9Xsvv06NcFq0L7/L9mYHvg+9v/6P
# WTYGKZHnhC0A0BrPLl5Ael254lgfhzA8nV1fYh2RSUzn1Vhgb7xrVd8y8Y7NbzQe
# HjmmxBzdbtDgatv7TrOI8UqSFNEk7E5aa8XZThBxYksu93TbjttQkdtjxwj2x/07
# SQ2XPyCxWjmvV1JRytwWKt+gLN+O369luU+CdaAnEo84DS6PEm4Gmcw8cjGSg2MW
# 7ISnGQvWp+TK1z7QgwNrGUbDdpi/hIps815qqfuQiw==
# SIG # End signature block
