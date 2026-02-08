# Uninstall Sequence (Operator Notes)

## Goal
Document the expected uninstall flow at a high level and where evidence is written.

## Sequence (high-level)
1. Preflight checks
2. Stop/disable runtime components (tasks/services as applicable)
3. Export evidence bundle (if enabled)
4. Remove runtime folders (respect mode/keep-logs option)
5. Verify post-state (tasks removed, policy state as expected)

## Evidence paths
- C:\ProgramData\FirewallCore\Logs\...
- C:\ProgramData\FirewallCore\Diagnostics\BUNDLE_*
- Docs/Sprints/... (process notes only, not runtime evidence)