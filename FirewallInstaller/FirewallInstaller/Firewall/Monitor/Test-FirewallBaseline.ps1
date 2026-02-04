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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBO5gWXS1R7sXKz
# pzmyojT4+vO9Hs9SopsJ06oLiSTW2qCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IMocZdW/g2En1sl5r45lg0VnrJhtLKmvDNgdGZ4TGNdQMAsGByqGSM49AgEFAARH
# MEUCICWbnP3eJ8/fNjA9eH0e5NIPXBWBqovcjDzqeA/NvVfyAiEA98P17A4fmv50
# yKmbWAVhljcbC71rdhjXBHzzD9RQkDo=
# SIG # End signature block
