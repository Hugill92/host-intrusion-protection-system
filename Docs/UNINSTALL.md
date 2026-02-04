# Uninstall FirewallCore (v1)

FirewallCore provides two uninstall paths:

## Default Uninstall (Recommended)
Removes runtime components while preserving evidence and logs under:
- `C:\ProgramData\FirewallCore\Logs`
- `C:\ProgramData\FirewallCore\Baselines`
- Event log: `FirewallCore` (events retained)

Use this when migrating versions or collecting diagnostics.

## Clean Uninstall (Destructive)
Removes runtime components and deletes FirewallCore data under `C:\ProgramData\FirewallCore`.

**Safety guard:** Clean uninstall requires an explicit confirmation flag (for example: `-ForceClean`) to avoid accidental data loss.

## Notes
- Administrator privileges are required.
- If your environment enforces signed scripts (ExecutionPolicy `AllSigned`), only run the officially signed uninstall script.
