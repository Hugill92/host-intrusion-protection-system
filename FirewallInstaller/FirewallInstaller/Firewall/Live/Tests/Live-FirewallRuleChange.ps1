Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$BaselineDir  = "C:\FirewallInstaller\Firewall\Live\Baseline"
$BaselineFile = Join-Path $BaselineDir "firewall-baseline.json"

if (-not (Test-Path $BaselineDir)) {
    New-Item -ItemType Directory -Path $BaselineDir -Force | Out-Null
}

function Snapshot-Rules {
    Get-NetFirewallRule |
        Select-Object `
            InstanceID,
            DisplayName,
            Enabled,
            Action,
            Profile,
            Direction,
            PolicyStoreSourceType,
            RuleGroup
}

# --- Create baseline if missing ---
if (-not (Test-Path $BaselineFile)) {
    Snapshot-Rules |
        ConvertTo-Json -Depth 6 |
        Out-File $BaselineFile -Encoding UTF8

    Write-Host "[LIVE] Baseline created - no comparison performed"
    return
}

$baseline = Get-Content $BaselineFile -Raw | ConvertFrom-Json
$current  = Snapshot-Rules

$diff = Compare-Object `
    $baseline `
    $current `
    -Property `
        InstanceID,
        Enabled,
        Action,
        Profile,
        Direction `
    -PassThru

if ($diff) {

    # Severity hook (event + future toast)
    . "C:\FirewallInstaller\Firewall\System\Write-FirewallSeverity.ps1" `
        -Severity "HIGH" `
        -Title "Firewall Rule Instance Modified" `
        -Details "One or more firewall rule instances changed from baseline." `
        -Context @{
            ChangedRules = $diff |
                Select-Object DisplayName, Profile, Enabled, Action, Direction
            Count     = $diff.Count
            User      = $env:USERNAME
            Host      = $env:COMPUTERNAME
            Timestamp = (Get-Date).ToString("o")
        }

    Write-Host "[LIVE] Firewall rule INSTANCE change detected - HIGH severity"
}
else {
    Write-Host "[LIVE] No firewall rule changes detected"
}

# --- Update baseline AFTER detection ---
$current |
    ConvertTo-Json -Depth 6 |
    Out-File $BaselineFile -Encoding UTF8

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDPNFaQhhSXgRpR
# tfK8+kIesI7tF+CjXi6WV2ZnG7zAWqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IF/cL2j8fLhIIcYdMO+G28wDm5wKenuGmmBVFsgdEr9vMAsGByqGSM49AgEFAARI
# MEYCIQC9oi0/1p8NRmFj13GrwAKvEw1QiqqIxrE3wjHXp1I/RAIhANzqiU68uEke
# EWBIefPhT+4PhLFQBhptXnmNsFxEV/Br
# SIG # End signature block
