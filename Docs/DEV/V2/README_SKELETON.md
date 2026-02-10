# FirewallCore V2 Skeleton Package (Optimizer + Telemetry + Maintenance)

This package is a **PS5.1-safe skeleton** that implements the **Action Registry** pattern and ships:
- Optimizer module scaffolding (2600–2699)
- Telemetry module scaffolding (2700–2799)
- Maintenance/Repair module scaffolding (2800–2899)
- Wrappers for the provided Admin Toolkit (System Repair + Registry Optimizations)

## Integration Notes (Repo)
Suggested drop-in locations:
- `Firewall\\Modules\\` for the `.psm1` modules
- `Tools\\V2\\` for invokers and shared helpers
- `ThirdParty\\AdminToolkit_v2\\` for the toolkit scripts (ViVeTool bundle intentionally excluded)

> **Signing:** editing any shipped PowerShell will invalidate Authenticode. Re-sign per your AllSigned workflow before running under AllSigned.

## Event Providers / Ranges
- `FirewallCore.Optimizer`: 2600–2699
- `FirewallCore.Telemetry`: 2700–2799
- `FirewallCore.Maintenance`: 2800–2899

## Run Folder Contract
- Elevated: `C:\\ProgramData\\FirewallCore\\<Module>\\Runs\\<PREFIX>_<RunId>\\...`
- Non-elevated Analyze-only fallback (where allowed): `%LOCALAPPDATA%\\FirewallCore\\<Module>\\Runs\\<PREFIX>_<RunId>\\...`

## Entry Points
- `Tools\\V2\\Optimizer\\Invoke-FirewallCoreOptimizer.ps1`
- `Tools\\V2\\Telemetry\\Invoke-FirewallCoreTelemetry.ps1`
- `Tools\\V2\\Maintenance\\Invoke-FirewallCoreMaintenance.ps1`

Each invoker supports `-Mode Analyze|Apply`, `-Profile Home|Gaming|Lab`, and `-SelectedActionIds`.
