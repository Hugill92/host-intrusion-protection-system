# v2 Optimizations and Experimental Feature Flags

## Overview
v2 adds an optional “Optimizations” system in the Admin Panel that supports:
- Preview (read-only)
- Apply (Maintenance Mode gated)
- Verify (evidence)
- Rollback (uses pre-change exports)

All evidence is written to ProgramData for auditing and support workflows.

## Experimental Feature Flags
Feature flags are supported via an optional drop-in tool placed under ProgramData.
The Admin Panel logs hashes, arguments, outputs, and exit codes for every run.
