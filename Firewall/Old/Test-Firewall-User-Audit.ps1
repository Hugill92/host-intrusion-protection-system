# Test-Firewall-User-Audit.ps1
# Purpose: Normal USER firewall change -> self-heal -> audit attribution test
# Run as NON-ADMIN

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Pick a random enabled firewall rule
$rule = Get-NetFirewallRule |
    Where-Object { $_.Enabled -eq "True" } |
    Get-Random

if (-not $rule) {
    Write-Host "[FAIL] No enabled firewall rules found."
    exit 1
}

$ruleName = $rule.Name

Write-Host "Disabling firewall rule as USER:"
Write-Host "  Name: $ruleName"
Write-Host ""

# Disable rule
Disable-NetFirewallRule -Name $ruleName

Write-Host "Rule disabled."
Write-Host "Waiting for self-heal and audit attribution (about 2-3 minutes)..."
Write-Host ""

# Wait longer than audit interval
Start-Sleep -Seconds 160

# Verify rule restored
$restored = (Get-NetFirewallRule -Name $ruleName).Enabled

# Check Firewall log for audit event
$auditEvent = Get-WinEvent -LogName Firewall -MaxEvents 50 |
    Where-Object {
        $_.Id -eq 9300 -and $_.Message -match [regex]::Escape($ruleName)
    } |
    Select-Object -First 1

Write-Host "RESULTS:"
Write-Host "--------"

if ($restored -eq "True") {
    Write-Host "[OK] Rule was self-healed"
} else {
    Write-Host "[FAIL] Rule was NOT restored"
}

if ($auditEvent) {
    Write-Host "[OK] Audit event detected:"
    Write-Host "     $($auditEvent.Message)"
} else {
    Write-Host "[FAIL] No audit attribution event (9300) found"
}

exit 0
