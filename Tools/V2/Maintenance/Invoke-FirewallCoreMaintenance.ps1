#requires -Version 5.1
param([ValidateSet('Analyze','Apply')][string]$Mode='Analyze',[ValidateSet('Home','Gaming','Lab')][string]$Profile='Home',[string[]]$SelectedActionIds=@('MAINT.REGOPT.PREVIEW'))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Import-Module (Join-Path $repoRoot 'Tools\V2\_shared\FirewallCore-V2Shared.psm1') -Force
Import-Module (Join-Path $repoRoot 'Firewall\Modules\FirewallCore-ActionRegistry.psm1') -Force
Import-Module (Join-Path $repoRoot 'Firewall\Modules\FirewallCore-Maintenance.psm1') -Force

Invoke-FirewallCoreActionSet -Module Maintenance -Mode $Mode -Profile $Profile -SelectedActionIds $SelectedActionIds
