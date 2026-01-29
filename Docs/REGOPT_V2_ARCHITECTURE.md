# REGOPT V2 – Registry Optimization Engine

## Status
READY – V2 ARCHITECTURE LOCKED

## Design Principles
- Single entry point
- Deterministic execution
- Explicit Preview vs Apply
- Full audit trail
- Admin Panel first integration

## Entry Point Contract

### Authoritative Entry Point
RegOpt-Runner.ps1

This script owns:
- Execution order
- Mode selection
- Logging
- State recording
- Exit codes

### Internal Workers
- Apply-RegistryOptimizations.ps1
- Verify-RegistryOptimizations.ps1

Workers do not orchestrate flow and must not be called directly.

### CMD Launcher (Transitional)
- Optional convenience only
- Calls RegOpt-Runner.ps1
- No orchestration logic
- May be removed in later versions

## Execution Modes

Mode | Behavior
---- | --------
PREVIEW | Verify only, no registry mutation
APPLY | Apply then verify then log

## Standard Layout

C:\ProgramData\FirewallCore\REGOPT\
- RegOpt-Runner.ps1
- Apply-RegistryOptimizations.ps1
- Verify-RegistryOptimizations.ps1
- Logs\
- State\

## Audit and Compliance
- Execution logs per run
- Last run state recorded
- Supports ISO, NIST, COBIT change control
