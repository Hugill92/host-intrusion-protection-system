Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "C:\Firewall\Modules\Firewall-EventLog.ps1"

# Look back 10 minutes for policy changes
$start = (Get-Date).AddMinutes(-10)

# These event IDs commonly record firewall policy/rule changes.
# We'll pull a set and log what we find.
$ids = @(4946,4947,4948,4950,4951,4952,4953,4954,4956,4957,4958)

$events = Get-WinEvent -FilterHashtable @{
    LogName   = "Security"
    Id        = $ids
    StartTime = $start
} -ErrorAction SilentlyContinue

if (-not $events) { exit 0 }

foreach ($e in $events) {
    $msg = $e.Message

    # Best-effort parse: account + rule name usually appears in the message text.
    $account = ""
    $rule    = ""

    if ($msg -match "Account Name:\s+([^\r\n]+)") { $account = $Matches[1].Trim() }
    if ($msg -match "Rule Name:\s+([^\r\n]+)")    { $rule    = $Matches[1].Trim() }

    $safe = "Firewall policy change detected. EventId=$($e.Id). Account='$account'. Rule='$rule'."
    Write-FirewallEvent -EventId 9300 -Type Information -Message $safe
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUn7tRBqaefzi2sgPfpzVg0bP4
# 2X+gggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUD5wO+bBCcoCGq/q9EggX1+wuXYAwDQYJ
# KoZIhvcNAQEBBQAEggEAjMSnT23/II26MpFOra5VhltfK7vfephkzv8jTMTZafkR
# 3LlnDnNd5EmxgR9fvMGvCCrG7g7aNTwUEw02dQOth0ISKzuJevzvuEJgda9u4QgJ
# WrnuslUsKOTlSiKbUD2LlixRBggLiuh20UE/2NC9TFTj4uSp6hUMYHp0ynBRZOxb
# A5Q0IOMW2EqsSsUj6+oGDYxDo9gEXbbj7ToHFI3L6NSzLkk18oif8FyJUy9K/llu
# EWztNUsN7m4yh6aVnnUlDE7HusFmJzjic/kNld57yy9AlVYs0Em/yQq63RnNkxxy
# 4l82637nvNtbTiRKwLiYbksf7HGm6jazAWHIB1zH6Q==
# SIG # End signature block
