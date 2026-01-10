# Test-Firewall-EventOnly.ps1
# Purpose: Validate Firewall Event Logging ONLY
# No self-heal dependency

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "C:\Firewall\Modules\Firewall-EventLog.ps1"

# Pick one enabled rule
$rule = Get-NetFirewallRule |
    Where-Object Enabled -eq True |
    Select-Object -First 1 Name, Direction

if (-not $rule) {
    Write-FirewallEvent -EventId 9001 -Type Error -Message "No enabled firewall rule found for test."
    exit 1
}

$ruleName = $rule.Name
$direction = $rule.Direction

# Log start
Write-FirewallEvent `
    -EventId 9100 `
    -Type Information `
    -Message "TEST START: Temporarily disabling firewall rule '$ruleName'. Direction: $direction."

# Disable rule
Disable-NetFirewallRule -Name $ruleName

Write-FirewallEvent `
    -EventId 9101 `
    -Type Warning `
    -Message "TEST ACTION: Firewall rule '$ruleName' disabled for event test."

# Wait briefly
Start-Sleep -Seconds 10

# Re-enable rule
Enable-NetFirewallRule -Name $ruleName

Write-FirewallEvent `
    -EventId 9102 `
    -Type Information `
    -Message "TEST COMPLETE: Firewall rule '$ruleName' re-enabled successfully."

exit 0
