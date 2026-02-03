[CmdletBinding()]
param(
    [string]$FirewallRoot = "C:\FirewallInstaller\Firewall",
    [switch]$FailOnDrift = $true,
    [switch]$EmitEvents,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log($m){ if(-not $Quiet){ Write-Host $m } }

# Notification (best effort)
$NotifAvailable = $false
try {
    Import-Module (Join-Path $FirewallRoot "Modules\FirewallNotifications.psm1") -Force -ErrorAction Stop
    $NotifAvailable = $true
} catch { $NotifAvailable = $false }

function Safe-Notify {
    param(
        [string]$Severity,
        [string]$Title,
        [string]$Message,
        [string[]]$Notify,
        [string]$TestId
    )
    if (-not $NotifAvailable) { return }
    try {
        Send-FirewallNotification `
            -Severity $Severity `
            -Title $Title `
            -Message $Message `
            -Notify $Notify `
            -TestId $TestId
    } catch { }
}

$StateDir = Join-Path $FirewallRoot "State\Baseline"
$JsonPath = Join-Path $StateDir "baseline.sha256.json"

if (-not (Test-Path $JsonPath)) {
    throw "Baseline file missing: $JsonPath"
}

$baseline = Get-Content $JsonPath -Raw | ConvertFrom-Json
$algo     = $baseline.Algorithm
$testId  = "Baseline-Integrity"

$findings = New-Object System.Collections.Generic.List[object]

foreach ($item in $baseline.Items) {
    $p = [string]$item.Path

    if (-not (Test-Path $p)) {
        $findings.Add([pscustomobject]@{
            Severity = "Critical"
            Reason   = "Missing baseline file"
            Path     = $p
        })
        continue
    }

    $fi = Get-Item $p
    $h  = (Get-FileHash -Algorithm $algo -Path $p).Hash

    if ($h -ne [string]$item.Sha256) {
        $findings.Add([pscustomobject]@{
            Severity = "Critical"
            Reason   = "Hash mismatch"
            Path     = $p
            Expected = [string]$item.Sha256
            Actual   = $h
        })
    }
    elseif ([int64]$fi.Length -ne [int64]$item.Length) {
        $findings.Add([pscustomobject]@{
            Severity = "Warning"
            Reason   = "Length drift"
            Path     = $p
        })
    }
}

if ($findings.Count -eq 0) {
    Log "[OK] Baseline integrity verified (no drift)"
    exit 0
}

foreach ($f in $findings) {
    if ($EmitEvents) {
        Write-Host "[EVENT] $(($f | ConvertTo-Json -Compress))"
    }
}

$crit = ($findings | Where-Object Severity -eq "Critical").Count
$warn = ($findings | Where-Object Severity -eq "Warning").Count

$sev = if ($crit -gt 0) { "Critical" } else { "Warning" }
$msg = "Baseline drift detected. Critical=$crit Warning=$warn"

Safe-Notify `
    -Severity $sev `
    -Title "Firewall baseline drift detected" `
    -Message $msg `
    -Notify @("Popup","Event") `
    -TestId $testId

if ($FailOnDrift) { exit 2 } else { exit 0 }

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUoXg899BxcBB0MdVu8qPWNlkR
# oZagggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUg9NNWIjDU6kGeZL0Y167Bq4FV/EwCwYH
# KoZIzj0CAQUABEcwRQIhAPUI+qaLFzaPTgcRvpLFz9WWo3TYJHdloApDXVXtbNXl
# AiAeo5cJVI4NWAYZIrEid75wTahUfEjW4M4F6lCIla9dyw==
# SIG # End signature block
