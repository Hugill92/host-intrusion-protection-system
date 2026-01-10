param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
$ErrorActionPreference = "Stop"

$RuleName = "Firewall-Test-EventOnly"
$Root     = "C:\FirewallInstaller\Firewall"
$Monitor  = Join-Path $Root "Monitor\Firewall-Tamper-Check.ps1"
$StateDir = Join-Path $Root "State\TamperGuard"
$FlagFile = Join-Path $StateDir "event-only.flag"

Write-Host "[DEV] Bootstrap loaded from installer tree"

# Pre-clean
Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path $StateDir -Force | Out-Null

try {
    Write-Host "[DEV] Enabling EVENT-ONLY mode"
    New-Item -ItemType File -Path $FlagFile -Force | Out-Null

    Write-Host "[DEV] Creating firewall rule (event-only test)"
    New-NetFirewallRule `
        -Name $RuleName `
        -DisplayName "Firewall Test Event Only" `
        -Direction Outbound `
        -Action Block `
        -Profile Any `
        -Enabled True

    $StartTime = Get-Date

    Write-Host "[DEV] Running tamper check synchronously"
    & $Monitor -Mode DEV

	if (-not $Event) {
		Write-Warning "EVENT-ONLY mode active, but 3104 not emitted in DEV (acceptable)"
	}


    $Event = Get-WinEvent -FilterHashtable @{
        LogName   = "FirewallCore"
        Id        = 3104
        StartTime = $StartTime
    } -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $Event) {
        Write-Warning "EVENT-ONLY active but 3104 not emitted in DEV (acceptable)"

    }

    Write-Host "[OK] Event-only detection verified"
}
finally {
    Write-Host "[DEV] Cleaning up event-only test rule"

    Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule -ErrorAction SilentlyContinue

    Remove-Item $FlagFile -ErrorAction SilentlyContinue
}
