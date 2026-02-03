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
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU4LZjdK1SvjAnQq3QI3gDXsZn
# Mt2gggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU8wk+Emz3BGSUByAN3OcWklDdWpAwCwYH
# KoZIzj0CAQUABEcwRQIgBuCLoHZic7+KyjS8W4N/mwnAO/m9XD0F2z62jqKxa68C
# IQCemDb65HHSp3Aqy+WYevKFYJ3mnVEJN3KfsmF61S7omg==
# SIG # End signature block
