# Firewall-SnapshotHistory.psm1
# Append-only snapshot hash history for forensic timelines

Set-StrictMode -Version Latest

$HistoryPath = "C:\Firewall\State\snapshot.history.jsonl"

function Write-SnapshotHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Snapshot,
        [Parameter(Mandatory)]$Diff,
        [string]$RunId = "Unknown"
    )

    if (-not (Test-Path (Split-Path $HistoryPath))) {
        New-Item -ItemType Directory -Path (Split-Path $HistoryPath) -Force | Out-Null
    }

    $entry = [pscustomobject]@{
        ts            = (Get-Date).ToString("o")
        runId         = $RunId
        snapshotHash  = $Snapshot.Hash
        ruleCount     = $Snapshot.RuleCount
        snapshotPath  = $Snapshot.Path
        diffPath      = $Diff.DiffPath
        added         = $Diff.AddedCount
        removed       = $Diff.RemovedCount
        modified      = $Diff.ModifiedCount
        mode          = $Snapshot.Mode
        computer      = $env:COMPUTERNAME
    }

    # JSONL = append-only forensic log
    ($entry | ConvertTo-Json -Depth 5 -Compress) |
        Add-Content -Path $HistoryPath -Encoding UTF8
}

Export-ModuleMember -Function Write-SnapshotHistory

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUoq+6Yl7ZA1yoWsZgAc+IVP/P
# Pz+gggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUcKN4JAuoZB7SAAgVCtO9g9ZciuEwCwYH
# KoZIzj0CAQUABEcwRQIgBiG5E9ikAzXXOpJokv5V91fkEkz5buafi4KY3XFbKpwC
# IQDkdAVYM4Hj2xiyVrR/3rT7bYJ+3WAr4ySGyy73LPtCVA==
# SIG # End signature block
