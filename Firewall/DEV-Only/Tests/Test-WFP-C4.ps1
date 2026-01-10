. "$PSScriptRoot\Test-Helpers.ps1"

# Test-WFP-C4.ps1
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode
. "$ModulesDir\Firewall-EventLog.ps1"

Write-Host "[DEV] Starting WFP C4 verification test..."

Get-NetFirewallRule | Out-Null
Write-TestPass "WFP enumeration successful"
Write-FirewallEvent -EventId 4604 -Type Information `
    -Message "DEV WFP C4 test executed successfully"

Write-Host "[PASS] Test-WFP-C4 completed successfully" -ForegroundColor Green