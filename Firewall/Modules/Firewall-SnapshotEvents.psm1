# ------------------------------------------------------------
# Optional event writer shim (safe on clean machines)
# ------------------------------------------------------------
if (-not (Get-Command Write-FirewallEvent -ErrorAction SilentlyContinue)) {
    function Write-FirewallEvent {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [int]$EventId,

            [Parameter(Mandatory)]
            [ValidateSet('Information','Warning','Error')]
            [string]$Type,

            [Parameter(Mandatory)]
            [string]$Message
        )

        # DEV fallback: no event source yet
        Write-Verbose "[FIREWALL-EVENT:$EventId][$Type]"
        Write-Verbose $Message
    }
}


# Firewall-SnapshotEvents.psm1
# Snapshot → Event emission with severity escalation

Set-StrictMode -Version Latest

function Emit-FirewallSnapshotEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Snapshot,

        [Parameter(Mandatory)]
        $Diff,

        [ValidateSet("LIVE","DEV")]
        [string]$Mode = "LIVE",

        [string]$RunId = ([guid]::NewGuid().ToString())
    )

    # ======================================
    # Snapshot hash short-circuit
    # ======================================
    $historyFile = Join-Path $StateDir "snapshot.history.json"

    if (Test-Path $historyFile) {
        $history = Get-Content $historyFile -Raw | ConvertFrom-Json
        $last    = $history.Entries | Select-Object -Last 1

        if ($last.Hash -eq $Snapshot.Hash) {
            if ($Mode -eq "DEV") {
                Write-Host "[DEV] Snapshot hash unchanged — skipping event emission"
            }
            return
        }
    }

    if (-not $Snapshot -or -not $Diff) {
        return
    }

    # Normalize counts (defensive)
    $added = if ($Diff.PSObject.Properties['AddedCount'] -and $Diff.AddedCount -ne $null) {
    [int]$Diff.AddedCount
    } else { 0 }

    $removed = if ($Diff.PSObject.Properties['RemovedCount'] -and $Diff.RemovedCount -ne $null) {
        [int]$Diff.RemovedCount
    } else { 0 }

    $modified = if ($Diff.PSObject.Properties['ModifiedCount'] -and $Diff.ModifiedCount -ne $null) {
        [int]$Diff.ModifiedCount
    } else { 0 }


    # ======================================
    # Severity + Event ID selection  ✅
    # (YOUR BLOCK — correctly placed)
    # ======================================
    if ($added -gt 0 -or $removed -gt 0) {
        $eventId = 4102
        $level   = "Error"
    }
    elseif ($modified -gt 0) {
        $eventId = 4101
        $level   = "Warning"
    }
    else {
        $eventId = 4100
        $level   = "Information"
    }

    # ======================================
    # Forensic-grade message
    # ======================================
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
        -EventId $eventId `
        -Type    $level `
        -Message $message

    if ($Mode -eq "DEV") {
        Write-Host "[DEV] Snapshot events emitted (4100/4101/4102 as applicable)"
    }
}

Export-ModuleMember -Function Emit-FirewallSnapshotEvent

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUSCJynTVuSv7ehfna7Da15DUs
# k3KgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU0n1CeyIkgv1BXXrgDyc0vvbFpBAwCwYH
# KoZIzj0CAQUABEYwRAIgXCTFpHnDcK5DXSyra2dUL2+8s5Wy4H6xSoEGfT5fksUC
# IBRwV7ANrCJmndOTXZDEXyHXwykXLYPGzUhz1e2khv2P
# SIG # End signature block
