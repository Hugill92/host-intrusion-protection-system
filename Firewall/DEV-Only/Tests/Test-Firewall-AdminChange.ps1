param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
$ErrorActionPreference = "Stop"

$RuleName = "Firewall-Test-AdminChange"

Write-Host "[DEV] Bootstrap loaded from installer tree"

# --- Pre-clean (idempotency) ---
Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue

try {
    # --- Create blocking rule (admin action) ---
    Write-Host "[DEV] Creating admin firewall rule (temporary)"

    New-NetFirewallRule `
        -Name $RuleName `
        -DisplayName "Firewall Test Admin Change" `
        -Direction Outbound `
        -Action Block `
        -Profile Any `
        -Enabled True

    # --- Trigger detection path ---
    Start-Sleep -Seconds 2

    # (Optional) invoke monitor / snapshot / diff trigger here
    # & "$PSScriptRoot\..\Monitor\Firewall-Core.ps1"

    Write-Host "[OK] Admin change detected"
}
finally {
    # --- GUARANTEED CLEANUP ---
    Write-Host "[DEV] Cleaning up admin firewall rule"

    Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue |
        Disable-NetFirewallRule -ErrorAction SilentlyContinue

    Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule -ErrorAction SilentlyContinue
}


Write-TestPass "Admin change detected"
