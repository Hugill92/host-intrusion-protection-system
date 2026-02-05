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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDFtvVQxUtsFO+p
# RAefpcGaYDCnzH/1QZ8PYAuvgv8NiaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggE0MIIBMAIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# ICbwaxkmPrATGDkAeEBKwpRh8ovXsXYxwAvngE0y9xKBMAsGByqGSM49AgEFAARH
# MEUCIQDHcAXREhg2pGPbujHysjOnzZhndl12w6D6doGw9yDPkAIgZw0Oikf2jTHK
# xBkHBUT94VniFLtvrJsMDbtwMPdc7MY=
# SIG # End signature block
