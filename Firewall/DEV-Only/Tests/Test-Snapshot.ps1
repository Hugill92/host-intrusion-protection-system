param(
    [switch]$DevMode = $true
)



. "$PSScriptRoot\Test-Helpers.ps1"
# DEV bootstrap (must come AFTER param)
. "$PSScriptRoot\..\..\Installs\_DevBootstrap.ps1" -DevMode:$DevMode

Import-Module "$ModulesDir\FirewallSnapshot.psm1" -Force

$snap = Get-FirewallSnapshot -Fast

if (-not $snap -or -not $snap.Hash -or $snap.RuleCount -le 0) {
    throw "Snapshot invalid"
}

Write-Host "[OK] Snapshot test passed" -ForegroundColor Green
