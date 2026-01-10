# Test-SelfHeal-Event.ps1
# Triggers firewall drift and verifies restore event (3001)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$rule = Get-NetFirewallRule |
    Where-Object { $_.Enabled -eq 'True' } |
    Select-Object -First 1

if (-not $rule) {
    Write-Host "[FAIL] No enabled firewall rules found."
    exit 1
}

Write-Host "[TEST] Disabling firewall rule:"
Write-Host "       Name: $($rule.Name)"
Write-Host "       Direction: $($rule.Direction)"

Disable-NetFirewallRule -Name $rule.Name

Write-Host "[OK] Rule disabled."
Write-Host "[WAIT] Waiting for self-heal (6 minutes)..."
Write-Host "       Expect exactly ONE Event ID 3001."

Start-Sleep -Seconds 360

$event = Get-WinEvent -LogName Firewall |
    Where-Object {
        $_.Id -eq 3001 -and
        $_.Message -like "*$($rule.Name)*"
    } |
    Select-Object -First 1

if ($event) {
    Write-Host "[PASS] Restore event detected:"
    $event | Format-List TimeCreated, Id, Message
}
else {
    Write-Host "[FAIL] No restore event found for rule $($rule.Name)."
}
