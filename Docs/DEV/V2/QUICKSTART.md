# Quick Start (Local Sandbox)

## Optimizer (Analyze user temp)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Tools\V2\Optimizer\Invoke-FirewallCoreOptimizer.ps1 -Mode Analyze -Profile Home -SelectedActionIds OPT.STORAGE.TEMP.USER

## Telemetry (Snapshot)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Tools\V2\Telemetry\Invoke-FirewallCoreTelemetry.ps1 -Mode Analyze -Profile Home -SelectedActionIds TEL.NET.SNAPSHOT

## Maintenance (REGOPT Preview)  (requires Admin + MaintenanceMode flag file)
# Create Maintenance Mode flag file for this skeleton:
#   New-Item -ItemType File -Path C:\ProgramData\FirewallCore\Config\MaintenanceMode.enabled -Force
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Tools\V2\Maintenance\Invoke-FirewallCoreMaintenance.ps1 -Mode Analyze -Profile Home -SelectedActionIds MAINT.REGOPT.PREVIEW
