param([switch]$DevMode = $true)


. "$PSScriptRoot\Test-Helpers.ps1"
# Test-Firewall-EventOnly.ps1
# Purpose: Validate Firewall Event Logging ONLY
# No self-heal dependency


. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Write-Host "[INFO] Simulate user firewall change (manual test)"



. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "C:\Firewall\Modules\Firewall-EventLog.ps1"

# Pick a stable rule
$rule = Get-NetFirewallRule |
    Where-Object { $_.Enabled -eq "True" -and $_.Action -eq "Allow" } |
    Select-Object -First 1 Name, Direction

if (-not $rule) {
    Write-FirewallEvent -EventId 9001 -Type Error -Message "No suitable firewall rule found for event-only test."
    exit 1
}

$ruleName  = $rule.Name
$direction = $rule.Direction

Write-FirewallEvent -EventId 9100 -Type Information `
    -Message "TEST START: Temporarily disabling firewall rule '$ruleName'. Direction: $direction."

Disable-NetFirewallRule -Name $ruleName

Write-FirewallEvent -EventId 9101 -Type Warning `
    -Message "TEST ACTION: Firewall rule '$ruleName' disabled for event test."

Start-Sleep -Seconds 10

Enable-NetFirewallRule -Name $ruleName

Write-FirewallEvent -EventId 9102 -Type Information `
    -Message "TEST COMPLETE: Firewall rule '$ruleName' re-enabled successfully."

exit 0

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUASycQldtyStRU0XRwPrLUUj0
# JBOgggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU/ODhg2ekA3MndwdVXaXHmGEEYGwwDQYJ
# KoZIhvcNAQEBBQAEggEAClxNIAm60ysZP1K8nv1skItCB81PBc9v9l78qHailCo7
# QfZrIrnud7fqsOlRKrFwyibZrVEVmwnB7+CWe649YdoQYLyjknmK54dNQx193dxl
# 1bVGZLaEOAjphv5XX3JsCrQzlTZ3mVq1fJs/QuLAh3BZ/GCn8shhrdIZz5LpAavQ
# RzP5yrI5pxsuFU0RRg+drm9t459ofNUc2zTTMePvvLVZAiRR+20sz7ssTRLPAczI
# jGPaUqwapL6q7gRvqp8DyNZe46+H6KSMZeQue2CXrSD8qSVHCJhYYkQ0XpkjYCBH
# UFzr2WwG5du/FnBx/ix7wBLE7WqUE3hIThyLmeiShQ==
# SIG # End signature block
