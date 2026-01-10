# ==========================================
# FIREWALL MONITOR - INBOUND + OUTBOUND
# Event ID 5157 (Blocked Connections)
# ==========================================

$LogName = "Security"
$EventID = 5157
$Since   = (Get-Date).AddMinutes(-30)

$Events = Get-WinEvent -FilterHashtable @{
    LogName   = $LogName
    Id        = $EventID
    StartTime = $Since
} -ErrorAction SilentlyContinue

if (-not $Events) {
    Write-Host "[OK] No blocked inbound or outbound connections in the last 30 minutes."
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

    Write-Host "=============================="
    Write-Host "BLOCKED CONNECTION DETECTED"
    Write-Host "Direction   : $Direction"
    Write-Host "Application : $Application"
    Write-Host "Destination : ${DestIP}:${DestPort}"
    Write-Host "Time        : $($Event.TimeCreated)"
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUE6MHuVfhNA+AWk7WEFyCjEf4
# VtCgggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUjfpVXMDVEyE4zn6SXvmW9X75g+MwDQYJ
# KoZIhvcNAQEBBQAEggEAhclliecTCrd//hEgp9q4IwcbBPtK81H5HIc473E5kuAS
# fJOMqmF8RtDwvPf2MMziMMGuLaThEwqxgZ4V5pdSY1pDu2Gw4fARt2JJKegNFe7V
# f2bxgWdACRnylEaaYYjA0xwyq6cL5B6+ORiwZzXA7pt4OFqSbELpueaHQfBeCVxJ
# n/0nWTgOQwTK9xii6xMWMnXu3F8ewNrkiI3R7AoZ8U+oe3T63dZr8pC3YXW5Kftb
# t7eBh9QIcoCXxOoi7VZt4OH61Gznk1YnN3AZxj6ztufk37ZTDkafr5tCr26xHzkJ
# w3tcTzY0ME/EfZe6iL9kvdsW9k4hHdHr/SX3dMCVKA==
# SIG # End signature block
