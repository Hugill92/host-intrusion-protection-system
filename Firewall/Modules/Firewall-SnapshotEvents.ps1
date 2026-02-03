# Firewall-SnapshotEvents.psm1
# Emits Event Viewer records for firewall snapshots + diffs
# DEV-safe, LIVE-safe, forensic-grade

Set-StrictMode -Version Latest

function Emit-FirewallSnapshotEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Snapshot,
        [Parameter(Mandatory)]$Diff,
        [string]$RunId = ([guid]::NewGuid().ToString()),
        [ValidateSet("DEV","LIVE")]
        [string]$Mode = "LIVE"
    )

    # Defensive validation
    if (-not $Snapshot.Path -or -not $Snapshot.Hash) {
        return
    }

    $added    = $Diff.AddedCount
    $removed  = $Diff.RemovedCount
    $modified = $Diff.ModifiedCount

    $message = @"
Firewall snapshot diff detected.
Mode=$Mode
SnapshotHash=$($Snapshot.Hash)
RuleCount=$($Snapshot.RuleCount)
Added=$added
Removed=$removed
Modified=$modified
SnapshotFile=$($Snapshot.Path)
DiffFile=$($Diff.DiffPath)
RunId=$RunId
"@

    Write-FirewallEvent `
        -EventId 4100 `
        -Type Information `
        -Message $message
}

Export-ModuleMember -Function Emit-FirewallSnapshotEvent

# SIG # Begin signature block
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWP8xgPih7gHB3U115WHpbY8Q
# nOegggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBJDCCASACAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUO5MZRZsAS0abrGez0pJmgIKklBkwCwYH
# KoZIzj0CAQUABEgwRgIhAN48f5iNcOlXoVA5+IYwprEW77h2TZg63J4kQbueAVOD
# AiEA4fMUuWTeC6z28uQ/VGJfxkfUVT6ePd7g9evogOPEsQ8=
# SIG # End signature block
