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
