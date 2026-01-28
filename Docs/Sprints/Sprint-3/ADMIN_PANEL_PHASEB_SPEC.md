## Admin Panel — Maintenance Mode + Exports (Sprint 3 Phase B)

### Implemented ✅
- Maintenance Mode header button is working (icon + ON/OFF text), admin-gated unlock validated under a standard user.
- Export buttons are Maintenance Mode gated: when OFF, user sees “Maintenance Mode must be ON to run exports.”
- Exports are now **non-bricking**: no BusyGate/async refresh engine is used for exports.
- Exports run via a **detached hidden worker** process (no UI lockups); worker is pinned to Windows PowerShell 5.1.

### Current export outputs 📦
- Diagnostics bundle:
  - Root: `C:\ProgramData\FirewallCore\Diagnostics`
  - Folder: `BUNDLE_yyyyMMdd_HHmmss\`
  - Includes: `Logs\`, `Reports\` (if present), `bundle.manifest.txt`, `SHA256SUMS.txt`
  - Zip is best-effort: `BUNDLE_yyyyMMdd_HHmmss.zip` (non-fatal if zip fails)
- Baseline export:
  - Root: `C:\ProgramData\FirewallCore\Baselines`
  - Folder: `BASELINE_yyyyMMdd_HHmmss\`
  - Includes: `Firewall-Policy.wfw` (netsh export), `SHA256SUMS.txt`

### Notes / guardrails 🔒
- Export operations must not brick the UI; exports must not touch the refresh engine.
- “Maintenance Mode” is required for exports and other privileged maintenance actions.


## Admin Panel — Maintenance Mode + Exports (Sprint 3 Phase B)

### Implemented ✅
- Maintenance Mode header button is working (icon + ON/OFF text), admin-gated unlock validated under a standard user.
- Export buttons are Maintenance Mode gated: when OFF, user sees “Maintenance Mode must be ON to run exports.”
- Export Diagnostics now runs without bricking the full Admin Panel UI and produces bundles deterministically.

### Current export outputs 📦
- Diagnostics bundle:
  - Root: `C:\ProgramData\FirewallCore\Diagnostics`
  - Folder: `BUNDLE_yyyyMMdd_HHmmss\`
  - Includes: `Logs\`, `Reports\` (if present), `bundle.manifest.txt`, `SHA256SUMS.txt`
- Baseline export:
  - Root: `C:\ProgramData\FirewallCore\Baselines`
  - Folder: `BASELINE_yyyyMMdd_HHmmss\`
  - Includes: `Firewall-Policy.wfw` (netsh export) + `SHA256SUMS.txt`

### Notes / guardrails 🔒
- Export operations must never brick the UI or stall refresh loops.
- Maintenance Mode is required for exports and other privileged maintenance actions.


