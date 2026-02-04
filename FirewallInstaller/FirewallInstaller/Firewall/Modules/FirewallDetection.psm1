function Invoke-FirewallBaselineDetection {
    param(
        [string]$FirewallRoot = "C:\FirewallInstaller\Firewall"
    )

    $BaselinePath = Join-Path $FirewallRoot "State\Baseline\baseline.sha256.json"
    if (-not (Test-Path $BaselinePath)) {
        throw "Baseline missing"
    }

    $baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
    $algo = $baseline.Algorithm

    $drift = @()
    foreach ($item in $baseline.Items) {
        if (-not (Test-Path $item.Path)) {
            $drift += @{ Type="MissingFile"; Path=$item.Path }
            continue
        }

        $h = (Get-FileHash -Algorithm $algo -Path $item.Path).Hash
        if ($h -ne $item.Sha256) {
            $drift += @{ Type="HashMismatch"; Path=$item.Path }
        }
    }

    $rules = Get-NetFirewallRule | Select DisplayName, Enabled, Action
    $profiles = Get-NetFirewallProfile
    $malicious = @()

    foreach ($r in $rules) {
        if ($r.DisplayName -like "WFP-*") {
            if (-not $r.Enabled) {
                $malicious += "Rule disabled: $($r.DisplayName)"
            }
            if ($r.Action -eq "Allow") {
                $malicious += "Allow rule present: $($r.DisplayName)"
            }
        }
    }

    foreach ($p in $profiles) {
        if ($p.DefaultInboundAction -ne "Block") {
            $malicious += "Inbound default not BLOCK: $($p.Name)"
        }
    }

    return [pscustomobject]@{
        DriftDetected     = ($drift.Count -gt 0)
        DriftItems        = $drift
        MaliciousDetected = ($malicious.Count -gt 0)
        MaliciousFindings = $malicious
    }
}

Export-ModuleMember -Function Invoke-FirewallBaselineDetection

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDPe2a5hkOzEcYc
# 8W7hq/cg7uC6G7dyPXWhxKrZBZMHhqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IJ0r4PZ+lpTAxmAtcDRb1leIqBxYWOPR+EWv7wrpQFSrMAsGByqGSM49AgEFAARH
# MEUCIQC459nBjP6ZfIF3fSVlVo0cRIMF92UvU06PmH9299W99QIgUD7XKI6Mw5V/
# DMvZ2OxWzYFz8sJQpXC3peOWHptHPY4=
# SIG # End signature block
