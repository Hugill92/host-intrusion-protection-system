# Test-Firewall-AdminChange.ps1
# Purpose: Validate admin rule change + event logging
# Does NOT rely on self-heal

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---- REQUIRE ADMIN ----
$principal = New-Object Security.Principal.WindowsPrincipal `
    ([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    Write-Error "This test must be run as Administrator."
    exit 1
}

# ---- LOAD EVENT LOG HELPER ----
. "C:\Firewall\Modules\Firewall-EventLog.ps1"

# ---- PICK A STABLE RULE ----
$rule = Get-NetFirewallRule |
    Where-Object { $_.Enabled -eq "True" -and $_.Action -eq "Allow" } |
    Select-Object -First 1 Name, Direction

if (-not $rule) {
    Write-FirewallEvent `
        -EventId 9002 `
        -Type Error `
        -Message "No suitable firewall rule found for admin test."
    exit 1
}

$ruleName  = $rule.Name
$direction = $rule.Direction

# ---- TEST SEQUENCE ----
Write-FirewallEvent `
    -EventId 9200 `
    -Type Information `
    -Message "ADMIN TEST START: Disabling firewall rule '$ruleName'. Direction: $direction."

Disable-NetFirewallRule -Name $ruleName

Write-FirewallEvent `
    -EventId 9201 `
    -Type Warning `
    -Message "ADMIN TEST ACTION: Firewall rule '$ruleName' disabled by Administrator."

Start-Sleep -Seconds 10

Enable-NetFirewallRule -Name $ruleName

Write-FirewallEvent `
    -EventId 9202 `
    -Type Information `
    -Message "ADMIN TEST COMPLETE: Firewall rule '$ruleName' re-enabled by Administrator."

exit 0
