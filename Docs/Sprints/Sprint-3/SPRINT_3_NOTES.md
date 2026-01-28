# Sprint 3 Notes


## 2026-01-26 — Admin Panel Phase B (stability + export actions)
- Added/updated Phase B notes (status + known issues):
  - ADMIN_PANEL_PHASEB_STATUS_2026-01-26.md
  - ADMIN_PANEL_PHASEB_KNOWN_ISSUES_2026-01-26.md
- Diagnostics Bundle: can succeed but may degrade UI until restart (see known issues).
- Export Baseline + SHA256: does not reliably create new baseline folders; artifacts may exist in diagnostics bundle.
- Frozen evidence log stored under Docs\_local (local-only).
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




## Admin Panel: Export Baseline + Export Diagnostics — DONE (Maintenance-gated)

**Timestamp:** 2026-01-27 19:36

### Outcome
- Export Baseline + SHA256: **WORKING**
- Export Diagnostics Bundle: **WORKING**
- UI remains responsive during export/zip (no freeze observed)
- **Maintenance Mode enforcement:** exports are blocked when Maintenance Mode is OFF (popup shown), and allowed when ON

### Security / Gating Behavior
- When Maintenance Mode is **OFF**:
  - Clicking either export shows a warning popup and **does not create artifacts**
- When Maintenance Mode is **ON**:
  - Clicking exports creates the expected folder(s) and zip(s)

### Output Paths (current)
- Baselines:
  - C:\ProgramData\FirewallCore\Baselines\BASELINE_YYYYMMDD_HHMMSS\
  - C:\ProgramData\FirewallCore\Baselines\BASELINE_YYYYMMDD_HHMMSS.zip
- Diagnostics:
  - C:\ProgramData\FirewallCore\Diagnostics\DIAG_YYYYMMDD_HHMMSS\
  - C:\ProgramData\FirewallCore\Diagnostics\DIAG_YYYYMMDD_HHMMSS.zip

### Artifact Inventory (minimum)
**Baseline folder includes:**
- Firewall-Policy.wfw
- Firewall-Policy.wfw.sha256.txt
- Firewall-Rules.csv
- README.txt
- Zip of the folder

**Diagnostics folder includes:**
- systeminfo.txt
- ipconfig-all.txt
- whoami-all.txt
- Logs\AdminPanel-Actions.log (copied if present)
- 
otifyqueue_counts.json
- Zip of the folder

### Acceptance Checklist
- [x] Maintenance OFF blocks exports with popup
- [x] Maintenance ON allows exports
- [x] Exports produce both folder + zip
- [x] Multiple runs produce unique timestamped bundles
- [x] UI remains usable while zipping

### Notes / Follow-ups
- The current “Diagnostics” export contains system/environment collection (systeminfo/ipconfig/whoami). This is conceptually a **Support Bundle**.
- Proposed next step: move large collection export to:
  - C:\ProgramData\FirewallCore\SupportBundles\BUNDLE_YYYYMMDD_HHMMSS\ + .zip
  - Keep Diagnostics\ for app/runtime-only diagnostics (logs, queue health, etc.)


<!-- FIREWALLCORE_ADMINPANEL_BUNDLE_EXPORTS_20260127 BEGIN -->
## Admin Panel — Bundle exports hardened (Diagnostics + Support) (2026-01-27 23:28:56)

### What shipped / locked in ✅
- **Exports moved into Actions dropdown** (Quick Actions now only: **Open Logs** + **Open Event Viewer**).
- **Maintenance Mode gate enforced**:
  - Maintenance **OFF** → shows blocking popup (no export runs)
  - Maintenance **ON** → export executes and writes evidence paths + logs
- **Two distinct export intents (keep both)**:
  - **Export Diagnostics Bundle**: app/runtime diagnostics (logs, queue health, policy snapshot, etc.) → C:\ProgramData\FirewallCore\Diagnostics\DIAG_YYYYMMDD_HHMMSS.zip (or DIAG/BUNDLE naming as implemented)
  - **Export Support Bundle (ZIP)**: “send to support” package (safe for sharing with intent/controls) → C:\ProgramData\FirewallCore\SupportBundles\BUNDLE_YYYYMMDD_HHMMSS.zip

### Integrity + chain-of-custody 🛡️
- For every bundle export:
  - Create **folder manifest hash list**: hashes.sha256.txt (SHA256 per file, relative paths)
  - Create **zip hash**: <zipname>.sha256
- Log Start/Ok/Fail and evidence paths to C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log

### Option A — Confidential transport (v1) 🔒
- Support Bundle ZIP is **password-protected** using the **same Admin/Dev unlock password** used to enable Maintenance/Dev actions.
- If encryption tooling is unavailable on a target host, export must still succeed but clearly log:
  - Encryption=Skipped and why (dependency missing), and continue with hashing + warning text.

### Later (v2/v3)
- Replace password-based bundle encryption with **signing key / secure unlock** integration (hardware-backed unlock).
<!-- FIREWALLCORE_ADMINPANEL_BUNDLE_EXPORTS_20260127 END -->

