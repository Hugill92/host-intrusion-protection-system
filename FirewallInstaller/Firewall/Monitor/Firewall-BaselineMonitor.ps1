$FirewallRoot = "C:\FirewallInstaller\Firewall"

Import-Module "$FirewallRoot\Modules\FirewallDetection.psm1" -Force
Import-Module "$FirewallRoot\Modules\FirewallNotifications.psm1" -Force

$SelfHealScript   = Join-Path $FirewallRoot "Monitor\Firewall-SelfHeal.ps1"
$AutoUpdateScript = Join-Path $FirewallRoot "Monitor\AutoUpdate-FirewallBaseline.ps1"
$AllowFlag        = Join-Path $FirewallRoot "State\Baseline\allow_update.flag"

function Notify($Severity,$Title,$Message,$TestId) {
    try {
        Send-FirewallNotification `
            -Severity $Severity `
            -Title $Title `
            -Message $Message `
            -Notify @("Popup","Event") `
            -TestId $TestId
    } catch {}
}

function TrustedUpdateWindow {
    if (-not (Test-Path $AllowFlag)) { return $false }
    $age = ((Get-Date).ToUniversalTime() - (Get-Item $AllowFlag).LastWriteTimeUtc).TotalMinutes
    return ($age -le 10)
}

while ($true) {
    try {
        $r = Invoke-FirewallBaselineDetection -FirewallRoot $FirewallRoot -BaselineMaxAgeDays 3

        if ($r.DriftDetected) {

            # ---- MALICIOUS WEAKENING ----
            if ($r.MaliciousDetected) {
                Notify "Critical" "Firewall compromise detected" `
                    ("Baseline drift with firewall weakening:`n" + ($r.MaliciousFindings -join "`n")) `
                    "Live-Baseline-Monitor"

                if (Test-Path $SelfHealScript) {
                    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SelfHealScript | Out-Null
                }

            # ---- BENIGN DRIFT (LEARNABLE) ----
            } else {
                if (TrustedUpdateWindow -and (Test-Path $AutoUpdateScript)) {
                    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AutoUpdateScript | Out-Null
                    Notify "Info" "Baseline updated" `
                        "Trusted update window detected. Baseline was refreshed." `
                        "Live-Baseline-Monitor"
                } else {
                    Notify "Warning" "Baseline drift detected" `
                        "No firewall weakening detected. Learning requires trusted update window." `
                        "Live-Baseline-Monitor"
                }
            }
        }
    } catch {}

    Start-Sleep -Seconds 60
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAmo7qBun+aIQqU
# VgGGFii4sdCSY1CTj8stKq0GgGPJCaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IJegUnDV0vaQCFrsFdEYwgBaq+A7ASEj8Z5r3jXjTy28MAsGByqGSM49AgEFAARI
# MEYCIQCFPQsFVTiLMKl4n7uX3BfqldDpHuQKiHE1sySRt+LfxwIhAISBmUQrGmzm
# rjn5KUl0o7h/kvSCKcH752k+6UwbmoNR
# SIG # End signature block
