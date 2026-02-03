# Forced-Test
# Category: LiveDetection
# Requires: Firewall
# Fatal: false

param(
    [ValidateSet("LIVE")]
    [string]$Mode = "LIVE",

    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log($m) { if (-not $Quiet) { Write-Host $m } }
function Result($s) {
    $c = @{ PASS="Green"; FAIL="Red"; SKIPPED="Yellow" }[$s]
    Write-Host "[FORCED-RESULT] $s" -ForegroundColor $c
}

# --- Notifications (best-effort, never break the test) ---
$TestId = "Forced-LiveDetection-FW"
$NotifAvailable = $false
try {
    Import-Module "C:\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop
    $NotifAvailable = $true
} catch {
    $NotifAvailable = $false
}

function Safe-Notify {
    param(
        [ValidateSet("Info","Warning","Critical")]
        [string]$Severity,
        [string]$Title,
        [string]$Message,
        [string[]]$Notify
    )
    if (-not $NotifAvailable) { return }
    try {
        Send-FirewallNotification `
            -Severity $Severity `
            -Title $Title `
            -Message $Message `
            -Notify $Notify `
            -TestId $TestId | Out-Null
    } catch {
        # Never fail the test because of notifications
    }
}
# ---------------------------------------------------------

$PolicyPath = "C:\Firewall\Policy\Firewall-Policy.json"
$Policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
$Profile = $Policy.Profiles.$($Policy.ActiveProfile)

$findings = @()

try {
    $rules = Get-NetFirewallRule |
        Select Name, DisplayName, Enabled, Action, Group, Direction, Profile

    foreach ($r in $rules) {
        if ($r.Group -match "File and Printer Sharing") {

            if (-not $r.Enabled) {
                $findings += @{
                    Severity = "WARN"
                    Reason   = "Predefined rule disabled"
                    Rule     = $r.DisplayName
                }
            }
            elseif ($r.Action -ne "Block") {
                $findings += @{
                    Severity = "WARN"
                    Reason   = "Predefined rule action drift"
                    Rule     = $r.DisplayName
                }
            }
        }
    }

    if ($findings.Count -eq 0) {
        Log "[INFO] Firewall state aligned with policy"
        Result "PASS"
        exit 0
    }

    foreach ($f in $findings) {
        Write-Host "[EVENT] $(ConvertTo-Json $f -Compress)"
    }

    # Info toast + event (click → Event Viewer) for drift findings
    Safe-Notify `
        -Severity "Info" `
        -Title "Firewall drift detected" `
        -Message ("{0} finding(s) detected in predefined rules. See Event Log for details." -f $findings.Count) `
        -Notify @("Toast","Event")

    Result "PASS"
    exit 0
}
catch {
    Write-Error $_

    # Warning toast + event for unexpected test failure
    Safe-Notify `
        -Severity "Warning" `
        -Title "Firewall live detection test failed" `
        -Message $_.Exception.Message `
        -Notify @("Toast","Event")

    Result "FAIL"
    exit 1
}

# SIG # Begin signature block
# MIIEbQYJKoZIhvcNAQcCoIIEXjCCBFoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUx5JiyoqAucydrHoV+MRKoT/p
# OrSgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUqt4EWiZ7H01PGuVeElShXLfdLpUwCwYH
# KoZIzj0CAQUABEYwRAIgb6cFXpVTUM5aiSgC30275PEjmu+0cZ3QqDZycdqN79kC
# IEoKTughSYrm4RZZUo18Vop9IGR4MjqUQT55A37ttnHZ
# SIG # End signature block
