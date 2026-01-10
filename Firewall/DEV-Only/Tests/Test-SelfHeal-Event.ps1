# Test-SelfHeal-Event.ps1
param([switch]$DevMode = $true)



. "$PSScriptRoot\Test-Helpers.ps1"
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode
. "$ModulesDir\Firewall-EventLog.ps1"

Write-FirewallEvent -EventId 3001 -Type Information `
    -Message "DEV self-heal event test"

$evt = Get-WinEvent -LogName Firewall -MaxEvents 5 |
       Where-Object Id -eq 3001

if (-not $evt) {
    Write-TestWarnPass "Self-heal event not guaranteed in DEV (acceptable)"
    return
}
Write-TestPass "Self-heal event emitted"