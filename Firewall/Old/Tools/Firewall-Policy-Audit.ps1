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
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUn7tRBqaefzi2sgPfpzVg0bP4
# 2X+gggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIjCCAR4CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUD5wO+bBCcoCGq/q9EggX1+wuXYAwCwYH
# KoZIzj0CAQUABEYwRAIgaPJALZweMWf2AH+YP+Rm5BTP8v0c8ghOPHAZWVjSFmsC
# IHM2n7Iva3nbwTQRqOGpyDNfUMqDUu+ZyMo/N5Qnmgm3
# SIG # End signature block
