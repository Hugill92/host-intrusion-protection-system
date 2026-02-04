# Firewall Core – DEV Test Manifest (v1)

This folder contains the complete DEV-mode test suite for Firewall Core / HIPS.

All tests MUST be:
- Idempotent
- Re-runnable
- Self-cleaning

All tests in this folder MUST pass before:
- Script signing
- Uninstaller validation
- Packaging
- LIVE mode enablement

## Test Classes

### Install Tests
- Validate installation correctness only
- Verify scheduled tasks, principals, paths, and mode flags
- MUST NOT assert runtime or self-heal events

### Snapshot Tests
- Validate firewall state capture
- Normalize and hash rule sets
- Support deterministic diffing
- Emit snapshot telemetry

### Diff Tests
- Detect rule additions, removals, and modifications
- Produce structured, order-independent output

### Actor Attribution Tests
- Distinguish User vs Admin changes
- Assign correct severity and audit classification

### Runtime Enforcement Tests
- Detect unauthorized changes
- Emit telemetry
- Perform self-heal when enabled

### Platform Tests
- Validate optional WFP (C4) components
- Non-blocking for v1 release

## Contract Rules

- Tests must clean up all firewall rules they create
- Tests must be safe to re-run
- `param()` must be the first executable statement
- LIVE mode disables destructive tests
- This manifest is frozen for v1
