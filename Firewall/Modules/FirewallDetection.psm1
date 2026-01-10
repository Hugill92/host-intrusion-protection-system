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
