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
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDB/bP+UrxMDPof
# 8tdnvv5Ojt+Nljmb6kwdT1qy43tMlaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
# YA1JZL+WI1Yn9crpsTANBgkqhkiG9w0BAQsFADAnMSUwIwYDVQQDDBxGaXJld2Fs
# bENvcmUgT2ZmbGluZSBSb290IENBMB4XDTI2MDIwMzA3NTU1N1oXDTI5MDMwOTA3
# NTU1N1owWDELMAkGA1UEBhMCVVMxETAPBgNVBAsMCFNlY3VyaXR5MRUwEwYDVQQK
# DAxGaXJld2FsbENvcmUxHzAdBgNVBAMMFkZpcmV3YWxsQ29yZSBTaWduYXR1cmUw
# WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATEFkC5IO0Ns0zPmdtnHpeiy/QjGyR5
# XcfYjx8wjVhMYoyZ5gyGaXjRBAnBsRsbSL172kF3dMSv20JufNI5SmZMo28wbTAJ
# BgNVHRMEAjAAMAsGA1UdDwQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNV
# HQ4EFgQUqbvNi/eHRRZJy7n5n3zuXu/sSOwwHwYDVR0jBBgwFoAULCjMhE2sOk26
# qY28GVmu4DqwehMwDQYJKoZIhvcNAQELBQADggEBAJsvjHGxkxvAWGAH1xiR+SOb
# vLKaaqVwKme3hHAXmTathgWUjjDwHQgFohPy7Zig2Msu11zlReUCGdGu2easaECF
# dMyiKzfZIA4+MQHQWv+SMcm912OjDtwEtCjNC0/+Q1BDISPv7OA8w7TDrmLk00mS
# il/f6Z4ZNlfegdoDyeDYK8lf+9DO2ARrddRU+wYrgXcdRzhekkBs9IoJ4qfXokOv
# u2ZvVZrPE3f2IiFPbmuBgzdbJ/VdkeCoAOl+D33Qyddzk8J/z7WSDiWqISF1E7GZ
# KSjgQp8c9McTcW15Ym4MR+lbyn3+CigGOrl89lzhMymm6rj6vSbvSMml2AEQgH0x
# ggE1MIIBMQIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IKOHUybBCNAtDcx8i8qAlVi8efzAM7Z6sPw3/i4adn+ZMAsGByqGSM49AgEFAARI
# MEYCIQDBV5OatrvCO9q6U0gd4N8kcQFUJfS6BO0lmDdyCW8iZQIhAPOY7YMe6xLX
# U3/9sB3NRmaaiaYU0AyYp4PBTWxOQT9F
# SIG # End signature block
