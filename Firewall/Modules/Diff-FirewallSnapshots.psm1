# Diff-FirewallSnapshots.psm1
# Forensic diff engine for firewall snapshots

Set-StrictMode -Version Latest

function Compare-FirewallSnapshots {
    [CmdletBinding()]
    param(
        [string]$SnapshotDir = "C:\Firewall\Snapshots",
        [string]$DiffDir     = "C:\Firewall\Diff"
    )

    if (!(Test-Path $SnapshotDir)) { return $null }
    if (!(Test-Path $DiffDir)) {
        New-Item -ItemType Directory -Path $DiffDir -Force | Out-Null
    }

    $snaps = Get-ChildItem $SnapshotDir -Filter "firewall_*.json" |
             Sort-Object LastWriteTime -Descending

    if ($snaps.Count -lt 2) { return $null }

    $newPath = $snaps[0].FullName
    $oldPath = $snaps[1].FullName

    $new = Get-Content $newPath -Raw | ConvertFrom-Json
    $old = Get-Content $oldPath -Raw | ConvertFrom-Json

    $newIdx = @{}; foreach ($r in $new) { if ($r.Name) { $newIdx[$r.Name] = $r } }
    $oldIdx = @{}; foreach ($r in $old) { if ($r.Name) { $oldIdx[$r.Name] = $r } }

    $added = @()
    $removed = @()
    $modified = @()

    foreach ($k in $newIdx.Keys) {
        if (-not $oldIdx.ContainsKey($k)) {
            $added += $newIdx[$k]
        }
        elseif ((ConvertTo-Json $newIdx[$k] -Depth 6) -ne (ConvertTo-Json $oldIdx[$k] -Depth 6)) {
            $modified += [pscustomobject]@{
                Name = $k
                Old  = $oldIdx[$k]
                New  = $newIdx[$k]
            }
        }
    }

    foreach ($k in $oldIdx.Keys) {
        if (-not $newIdx.ContainsKey($k)) {
            $removed += $oldIdx[$k]
        }
    }

    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $diffPath = Join-Path $DiffDir "firewall_diff_$ts.json"

    $diff = [pscustomobject]@{
        Timestamp     = (Get-Date).ToString("o")
        NewSnapshot   = $newPath
        OldSnapshot   = $oldPath
        DiffPath      = $diffPath
        AddedCount    = $added.Count
        RemovedCount  = $removed.Count
        ModifiedCount = $modified.Count
        Added         = $added
        Removed       = $removed
        Modified      = $modified
    }

    $diff | ConvertTo-Json -Depth 8 | Set-Content -Path $diffPath -Encoding UTF8
    return $diff
}

Export-ModuleMember -Function Compare-FirewallSnapshots

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU817H8PrM1XQlmOTT1KI8P6pF
# TXegggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUv9p8tjo2m9y4anVZuxhB+hWA1Y0wCwYH
# KoZIzj0CAQUABEcwRQIgR2mydw3sQ+JI4V3aTBy2ih4N4t5ezDqZeKZ5awWJOHQC
# IQCJXVO3nkMWBTTVrAL4CxhEkXvxE9PplQUY56bGrMc1XA==
# SIG # End signature block
