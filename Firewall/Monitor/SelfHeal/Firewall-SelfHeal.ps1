$FirewallRoot = "C:\FirewallInstaller\Firewall"

Import-Module "$FirewallRoot\Modules\FirewallDetection.psm1" -Force
Import-Module "$FirewallRoot\Modules\FirewallNotifications.psm1" -Force

$healStateDir = Join-Path $FirewallRoot "State\SelfHeal"
New-Item $healStateDir -ItemType Directory -Force | Out-Null
$stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$healOut = Join-Path $healStateDir ("selfheal_{0}.json" -f $stamp)

$result = Invoke-FirewallBaselineDetection -FirewallRoot $FirewallRoot

$healed = @()
$started = (Get-Date).ToString("o")

# Only heal if malicious weakening is detected
if (-not $result.MaliciousDetected) {
    $payload = @{
        Time=$started
        Status="NOOP"
        Reason="No malicious weakening detected"
        MaliciousFindings=$result.MaliciousFindings
    }
    $payload | ConvertTo-Json -Depth 8 | Set-Content -Path $healOut -Encoding UTF8
    exit 0
}

try {
    # ---- RULE-LEVEL SELF HEAL (package-owned only) ----
    $rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "WFP-*" }

    foreach ($r in $rules) {
        $before = Get-NetFirewallRule -Name $r.Name | Select DisplayName,Enabled,Action,Direction,Profile

        $did = $false

        if (-not $before.Enabled) {
            Set-NetFirewallRule -Name $r.Name -Enabled True
            $did = $true
        }

        # ensure Block
        $afterAction = (Get-NetFirewallRule -Name $r.Name).Action
        if ($afterAction -ne "Block") {
            Set-NetFirewallRule -Name $r.Name -Action Block
            $did = $true
        }

        if ($did) {
            $after = Get-NetFirewallRule -Name $r.Name | Select DisplayName,Enabled,Action,Direction,Profile
            $healed += @{
                Type="RuleRepair"
                Rule=$before.DisplayName
                Before=$before
                After=$after
            }
        }
    }

    # ---- PROFILE-LEVEL SELF HEAL (only if weakened) ----
    foreach ($p in Get-NetFirewallProfile) {
        if ($p.DefaultInboundAction -ne "Block") {
            $before = @{
                Profile=$p.Name
                DefaultInboundAction=$p.DefaultInboundAction
                DefaultOutboundAction=$p.DefaultOutboundAction
                Enabled=$p.Enabled
            }
            Set-NetFirewallProfile -Name $p.Name -DefaultInboundAction Block
            $p2 = Get-NetFirewallProfile -Name $p.Name
            $after = @{
                Profile=$p2.Name
                DefaultInboundAction=$p2.DefaultInboundAction
                DefaultOutboundAction=$p2.DefaultOutboundAction
                Enabled=$p2.Enabled
            }
            $healed += @{
                Type="ProfileRepair"
                Before=$before
                After=$after
            }
        }
    }

    $payload = @{
        Time=$started
        Status="HEALED"
        HealedCount=$healed.Count
        Healed=$healed
        MaliciousFindings=$result.MaliciousFindings
    }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $healOut -Encoding UTF8

    # Notify (live/forced/pentest will be tagged by TestId)
    Send-FirewallNotification `
        -Severity Critical `
        -Title "Firewall self-heal executed" `
        -Message ("Self-heal repaired package-owned state. Repairs={0}. Details: {1}" -f $healed.Count, $healOut) `
        -Notify @("Popup","Event") `
        -TestId "Live-SelfHeal"

    exit 0
}
catch {
    $payload = @{
        Time=$started
        Status="FAIL"
        Error=$_.Exception.Message
        Healed=$healed
    }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $healOut -Encoding UTF8

    Send-FirewallNotification `
        -Severity Critical `
        -Title "Firewall self-heal FAILED" `
        -Message ("{0} (details: {1})" -f $_.Exception.Message, $healOut) `
        -Notify @("Popup","Event") `
        -TestId "Live-SelfHeal"

    exit 2
}

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCoQOoGji68biuu
# fuRdGk3mhEKi8d2TmnbmmOousOVce6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IOCJNj6S5OSwFeP8EruA8h8rmeZuEe3mODRL1oGPqn2dMAsGByqGSM49AgEFAARH
# MEUCIHl4kBkNQpLq9MW83G2cR424BT9drv5ykFN+PkkDMxnaAiEAzPzZgpuf1X4Y
# 1YAaH39TyDokQJNQBvDScjlY0euLCns=
# SIG # End signature block
