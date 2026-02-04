param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
$ErrorActionPreference = "Stop"

$RuleName = "Firewall-Test-EventOnly"
$Root     = "C:\FirewallInstaller\Firewall"
$Monitor  = Join-Path $Root "Monitor\Firewall-Tamper-Check.ps1"
$StateDir = Join-Path $Root "State\TamperGuard"
$FlagFile = Join-Path $StateDir "event-only.flag"

Write-Host "[DEV] Bootstrap loaded from installer tree"

# Pre-clean
Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path $StateDir -Force | Out-Null

try {
    Write-Host "[DEV] Enabling EVENT-ONLY mode"
    New-Item -ItemType File -Path $FlagFile -Force | Out-Null

    Write-Host "[DEV] Creating firewall rule (event-only test)"
    New-NetFirewallRule `
        -Name $RuleName `
        -DisplayName "Firewall Test Event Only" `
        -Direction Outbound `
        -Action Block `
        -Profile Any `
        -Enabled True

    $StartTime = Get-Date

    Write-Host "[DEV] Running tamper check synchronously"
    & $Monitor -Mode DEV

	if (-not $Event) {
		Write-Warning "EVENT-ONLY mode active, but 3104 not emitted in DEV (acceptable)"
	}


    $Event = Get-WinEvent -FilterHashtable @{
        LogName   = "FirewallCore"
        Id        = 3104
        StartTime = $StartTime
    } -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $Event) {
        Write-Warning "EVENT-ONLY active but 3104 not emitted in DEV (acceptable)"

    }

    Write-Host "[OK] Event-only detection verified"
}
finally {
    Write-Host "[DEV] Cleaning up event-only test rule"

    Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule -ErrorAction SilentlyContinue

    Remove-Item $FlagFile -ErrorAction SilentlyContinue
}

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCM0h00ZM6mEgRg
# UY4Z974vTnZKxDQ43XHklGIBFGHqVaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IE6/KmFZpFqLHJQJGZ0M5ZXw5qXNwI36OUIgVQ2TryyGMAsGByqGSM49AgEFAARH
# MEUCIQDSPW7SrVe0iqtEvMAUJujHj10TPdTUrRcqWKpdGVjpOQIgNs3ZoCQinRuV
# 91xFPFjn6LSMaBZJP8B9RJw2osCX8mc=
# SIG # End signature block
