[CmdletBinding()]
param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "DEV",
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log($m){ if(-not $Quiet){ Write-Host $m } }
function Result($s){
    $c = @{ PASS="Green"; FAIL="Red"; SKIPPED="Yellow" }[$s]
    Write-Host "[FORCED-RESULT] $s" -ForegroundColor $c
}

$FirewallRoot = "C:\FirewallInstaller\Firewall"
$BaselinePath = Join-Path $FirewallRoot "State\Baseline\baseline.sha256.json"

if ($Mode -ne "LIVE") {
    Log "[INFO] DEV mode  baseline drift test skipped"
    Result "SKIPPED"
    exit 0
}

if (-not (Test-Path $BaselinePath)) {
    throw "Baseline missing  cannot validate drift"
}

$baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
$algo = $baseline.Algorithm

$drift = @()

foreach ($item in $baseline.Items) {
    if (-not (Test-Path $item.Path)) {
        $drift += [pscustomobject]@{
            Type = "MissingFile"
            Path = $item.Path
        }
        continue
    }

    $h = (Get-FileHash -Algorithm $algo -Path $item.Path).Hash
    if ($h -ne $item.Sha256) {
        $drift += [pscustomobject]@{
            Type = "HashMismatch"
            Path = $item.Path
        }
    }
}

if ($drift.Count -eq 0) {
    Log "[OK] No baseline drift detected"
    Result "PASS"
    exit 0
}

Log "[WARN] Baseline drift detected  analyzing firewall state"

$rules = Get-NetFirewallRule | Select DisplayName, Enabled, Action, Direction, Profile
$malicious = @()

foreach ($r in $rules) {
    if (-not $r.Enabled -and $r.DisplayName -like "WFP-*") {
        $malicious += "Security rule disabled: $($r.DisplayName)"
    }
    if ($r.Action -eq "Allow" -and $r.DisplayName -like "WFP-*") {
        $malicious += "Allow rule present: $($r.DisplayName)"
    }
}

foreach ($p in Get-NetFirewallProfile) {
    if ($p.DefaultInboundAction -ne "Block") {
        $malicious += "Inbound default not BLOCK on profile $($p.Name)"
    }
}

$severity = if ($malicious.Count -gt 0) { "Critical" } else { "Warning" }

try {
    Import-Module "$FirewallRoot\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop
    $msg = if ($severity -eq "Critical") {
        "Baseline drift + firewall weakening detected:`n" + ($malicious -join "`n")
    } else {
        "Baseline drift detected with no live firewall weakening."
    }

    Send-FirewallNotification `
        -Severity $severity `
        -Title "Firewall baseline drift detected" `
        -Message $msg `
        -Notify @("Popup","Event") `
        -TestId "Forced-Baseline-Drift"
}
catch {}

if ($severity -eq "Critical") {
    Result "FAIL"
    exit 2
}

Result "PASS"
exit 0

# SIG # Begin signature block
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUurs/TKTZyIQ+YgKts16yOPQI
# hPOgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU0tZeDynJ6wJWA3EALzIMNNqs9DwwCwYH
# KoZIzj0CAQUABEgwRgIhAOeD/GtCY28Ut6pCAjf98Rq+M+YFCj4U4spSwt25rMCK
# AiEA1u33iGjHNYF0oSzv8vv0xv1imnEBT9gDEEzZwOx2xAo=
# SIG # End signature block
