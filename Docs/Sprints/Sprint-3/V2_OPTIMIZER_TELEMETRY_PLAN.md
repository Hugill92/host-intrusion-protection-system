# Sprint Note: V2 Optimizer + Telemetry + Maintenance/Repair Planning

## Summary
- Added V2 planning spec for Optimize mode (Cortex-inspired tiles) with governed Action Registry backend.
- Locked EVTX provider + ranges:
  - FirewallCore.Optimizer (2600–2699)
  - FirewallCore.Telemetry (2700–2799)
  - FirewallCore.Maintenance (2800–2899)
- Locked run-folder contracts (ProgramData elevated; LocalAppData Analyze-only fallback).

## Key UX Decisions
- Admin Panel stays single-window.
- Mode toggle radio: Security | Optimize.
- Optimize mode shows tiles + DataGrid results; tile click opens non-blocking window.

## Next Implementation Steps (Skeleton Work)
1) Implement Action Registry loader + in-memory catalog (PS5.1-safe).
2) Add Optimize mode UI surface (radio switch + tile strip + DataGrid swap).
3) Wire Analyze/Apply pipeline with JSON report writing + EVTX summary events.
4) Add Telemetry snapshot + time-boxed WFP ETW capture actions (gated).
5) Add Maintenance/Repair actions: SFC/DISM/REGOPT (gated + report).

## Canonical Spec
- Docs\DEV\V2\OPTIMIZER_TELEMETRY_MAINTENANCE_V2_SPEC.md
