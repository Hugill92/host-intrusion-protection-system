# Firewall-EventLog.ps1
# Helper module – defines Write-FirewallEvent ONLY
# NO side effects on import

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

$Global:FirewallEventLogName = "Firewall"
$Global:FirewallEventSource  = "Firewall-Core"

function Write-FirewallEvent {
    param (
        [Parameter(Mandatory)]
        [int]$EventId,

        [Parameter(Mandatory)]
        [ValidateSet("Information","Warning","Error")]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Message
    )

    try {
        # Assume log + source already exist (created at install time)
        Write-EventLog `
            -LogName  $Global:FirewallEventLogName `
            -Source   $Global:FirewallEventSource `
            -EventId  $EventId `
            -EntryType $Type `
            -Message  $Message
    }
    catch {
        # Logging must NEVER break enforcement
        try {
            $fallback = "[$(Get-Date -Format o)] EVENTLOG FAILURE: $EventId | $Type | $Message"
            Add-Content -Path "C:\Firewall\Logs\EventLog-Fallback.log" -Value $fallback
        } catch { }
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU2gBhYVvuP6YE/9Q2D1yq9KYD
# YeOgggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUEygOyGdadVx6QJ3G6h98vRTUxCUwDQYJ
# KoZIhvcNAQEBBQAEggEAlcSUSQJ3oQb5EROo9HzAih7wOTHsE7mZB6X4Ggl0PVrD
# h0saeDuMK8Bl0nGfBA/y3ooa0lZj6NlsNoTJEi6HouqYaE1w/k++71VlD4EFNrnr
# wodLPlMCBId+NUBdleX/xn/0CfjS18jT8F3D5T0QD1Cb0btj1F5hNk1A69UoB2US
# rOrrZ/u2B0JVhtkevLHXpCY/Fb/muVUIxrBwwfiO/RJFxs9t+h8TewIdkztDy97P
# T9yJNRbFRhwHQh2TCONIdq6y2pZX9tkRT/AlHakFG9jXlHonpBEyNa3lPT8rt6iW
# iZnNVY+mfZgk30iqk7ln7ygzUEerUnCGtOu5UVFkKA==
# SIG # End signature block
