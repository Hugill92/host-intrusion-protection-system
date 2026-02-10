# FirewallCore V2: Optimizer + Telemetry + Maintenance/Repair Spec

## Goals
- Add a Cortex-style **Optimize mode** to the Admin Panel without clutter:
  - Mode toggle (radio): **Security | Optimize**
  - Cortex-like tiles (System Junk, App Junk, Browser Junk, Recycle Bin, etc.)
  - Tile click opens a **non-blocking** window (`Show()`), not `ShowDialog()`
- Implement a governed **Action Registry** backend:
  - Preview-first (**Analyze**) then optional (**Apply**)
  - Explicit allowlists, skip in-use, age thresholds
  - Gate enforcement: Admin / Maintenance Mode / Dev-Lab
  - Evidence-first: JSON run report + EVTX summary events
- Add V2 defensive **Telemetry** (ETW/WFP visibility) as a sibling module
- Add V2 **Maintenance/Repair** actions (SFC/DISM/REGOPT) under Optimize mode (gated)

## UI Model (Admin Panel)
### Top Controls (Always Visible)
- Maintenance Mode toggle (master gate)
- Mode radio: `Security | Optimize`
- Profile selector: `Home | Gaming | Lab`
- Last Run indicator (per module)

### Optimize Mode Layout
- Tile strip (Cortex-inspired)
- DataGrid shows:
  - Selected actions
  - Last scan results (BytesFound)
  - Risk + required gates (Admin/Maint/DevLab)
  - EvidencePath (open report folder)
- Tile click opens non-blocking window:
  - Checkbox sub-actions
  - Analyze / Apply / Export Report
  - Risk banner + gate requirements

## Module Boundaries
### Optimizer (Cleanup)
- Purpose: reclaim disk space safely (allowlist-only)
- Provider: `FirewallCore.Optimizer`
- Event IDs: 2600–2699
- Run root:
  - Elevated: `C:\ProgramData\FirewallCore\Optimizer\Runs\OPT_<RunId>\...`
  - Non-elevated Analyze-only fallback: `%LOCALAPPDATA%\FirewallCore\Optimizer\Runs\OPT_<RunId>\...`

### Telemetry (Defensive Visibility)
- Purpose: visibility and time-boxed capture (no active scanning in V2)
- Provider: `FirewallCore.Telemetry`
- Event IDs: 2700–2799
- Run root:
  - Elevated: `C:\ProgramData\FirewallCore\Telemetry\Runs\TEL_<RunId>\...`
  - Non-elevated fallback (snapshot-only): `%LOCALAPPDATA%\FirewallCore\Telemetry\Runs\TEL_<RunId>\...`

### Maintenance/Repair (System Health)
- Purpose: system repair and governed optimizations (SFC/DISM/REGOPT)
- Provider: `FirewallCore.Maintenance`
- Event IDs: 2800–2899
- Run root:
  - Elevated: `C:\ProgramData\FirewallCore\Maintenance\Runs\MAINT_<RunId>\...`

## Event ID Strategy
- Numeric ID does NOT imply severity. Use EVTX Level for severity.
- EVTX is **summary-only** (low noise). Per-item details live in JSON reports.

### FirewallCore.Optimizer (2600–2699)
| EventId | Name | Level | Notes |
|---:|---|---|---|
| 2600 | OptimizeAnalyzeStart | Information | RunId, Profile, SelectedActionIds |
| 2601 | OptimizeAnalyzeComplete | Information | Totals + per-action bytes found |
| 2610 | OptimizeApplyStart | Information | RunId, SelectedActionIds, gates |
| 2611 | OptimizeApplyComplete | Information | Totals + per-action bytes freed |
| 2612 | OptimizeApplyFailed | Error | ActionId + error summary |
| 2630 | OptimizeReportWritten | Information | ReportPath + ArchivePath |

### FirewallCore.Telemetry (2700–2799)
| EventId | Name | Level | Notes |
|---:|---|---|---|
| 2700 | TelemetrySnapshotStart | Information | RunId + snapshot scope |
| 2701 | TelemetrySnapshotComplete | Information | Output paths + summary |
| 2710 | WfpCaptureStart | Information | Time-boxed capture start |
| 2711 | WfpCaptureStop | Information | Capture stopped + output |
| 2712 | WfpCaptureFailed | Error | Failure summary |
| 2730 | TelemetryReportWritten | Information | ReportPath |

### FirewallCore.Maintenance (2800–2899)
| EventId | Name | Level | Notes |
|---:|---|---|---|
| 2800 | MaintenanceActionStart | Information | RunId + ActionId |
| 2801 | MaintenanceActionComplete | Information | Success + summary |
| 2802 | MaintenanceActionFailed | Error | ActionId + error summary |
| 2830 | MaintenanceReportWritten | Information | ReportPath |

## Action Registry Contract (Backend Source of Truth)
Each action definition includes:
- ActionId (stable)
- DisplayName
- Module (`Optimizer|Telemetry|Maintenance`)
- TileGroup (for UI tiles)
- Risk (`Low|Medium|High`)
- Mode (`AnalyzeOnly|AnalyzeApply`)
- RequiresAdmin (bool)
- RequiresMaintenanceMode (bool)
- RequiresDevLab (bool)
- ProfileVisibility (`Home|Gaming|Lab` list)
- AnalyzeScript (scriptblock)
- ApplyScript (optional scriptblock)
- Notes (tooltip)

### Standard Analyze Result Object
- BytesFound (Int64)
- ItemCount (Int32)
- Sample (string[]; optional top N paths)
- Warnings (string[]; optional)

### Standard Apply Result Object
- BytesFreed (Int64)
- DeletedCount (Int32)
- SkippedInUse (Int32)
- SkippedDenied (Int32)
- Archived (bool)
- Errors (string[])

## V2 Action IDs (Canonical)

### Optimizer: Cortex-style Tiles (Composite Groups)
**System Junk Files (tile composite)**
- OPT.STORAGE.TEMP.USER
- OPT.STORAGE.TEMP.SYSTEM
- OPT.STORAGE.WER.QUEUES
- OPT.STORAGE.CRASHDUMPS.USER
- OPT.STORAGE.SHADERCACHE.DX (Gaming)

**Application Junk Files (allowlist-only)**
- OPT.STORAGE.CRASHDUMPS.USER
- OPT.STORAGE.PACKAGES.TEMPSTATE (Analyze default)

**Browser Junk Files (opt-in)**
- OPT.STORAGE.BROWSER.EDGE.CACHE
- OPT.STORAGE.BROWSER.CHROME.CACHE

**Recycle Bin**
- OPT.STORAGE.RECYCLEBIN

**Downloaded Files (V2 Analyze-only by default; Apply gated/V3)**
- OPT.STORAGE.DOWNLOADS.ANALYZE
- OPT.STORAGE.DOWNLOADS.APPLY (V3 or Maint+explicit preview)

**Backup Files (V2 Analyze-only)**
- OPT.STORAGE.BACKUPS.FINDER.ANALYZE

**Registry (V2 Analyze-only; no destructive cleaning in V2)**
- OPT.REGISTRY.HEALTH.ANALYZE
- OPT.REGISTRY.CLEAN.APPLY (V3 Lab-only if ever)

**Browser Privacy (V2 opens built-in UI, does not wipe silently)**
- OPT.PRIVACY.EDGE.OPEN_CLEAR_UI
- OPT.PRIVACY.CHROME.OPEN_CLEAR_UI

### Optimizer: Enterprise Cleanup Categories (Risk-labeled)
**Low risk**
- OPT.STORAGE.TEMP.USER
- OPT.STORAGE.RECYCLEBIN
- OPT.STORAGE.WER.QUEUES
- OPT.STORAGE.FIREWALLCORE.LOGS.RETENTION
- OPT.STORAGE.FIREWALLCORE.NOTIFYQUEUE.ARCHIVE

**Medium risk (gated/opt-in)**
- OPT.STORAGE.BROWSER.EDGE.CACHE
- OPT.STORAGE.BROWSER.CHROME.CACHE
- OPT.STORAGE.DELIVERYOPT.CACHE (Admin + Maintenance)
- OPT.MAINT.DISM.COMPONENT_CLEANUP (Admin + Maintenance)

**High risk (V3 / extra confirm)**
- OPT.MAINT.DISM.RESETBASE (irreversible)
- OPT.STORAGE.WU.SOFTWAREDISTRIBUTION.CLEAN (servicing-safe methods only)

## Memory (V2 + V3 Plan)
### V2 Safe Dashboard (always on)
- OPT.MEM.SNAPSHOT
- OPT.MEM.TOP_PROCESSES

### V2 Advanced (Gaming/Lab; gated)
- OPT.MEM.TRIM_WORKINGSET.TOPN
- OPT.MEM.TRIM_WORKINGSET.PID

### V3 Lab-only (requires signed helper)
- OPT.MEM.PURGE_STANDBY.LAB

## Telemetry Actions (V2)
- TEL.NET.SNAPSHOT
- TEL.FW.LOG.STATUS
- TEL.WFP.AUDIT.STATUS
- TEL.WFP.CAPTURE.START (Admin + Maintenance; time-boxed)
- TEL.WFP.CAPTURE.STOP  (Admin + Maintenance)
- TEL.EXPORT.BUNDLE

## Maintenance/Repair Actions (V2)
System repair and governed optimizations exposed under Optimize mode (gated):
- MAINT.SFC.SCANNOW (Admin + Maintenance)
- MAINT.DISM.CHECKHEALTH (Admin + Maintenance)
- MAINT.DISM.SCANHEALTH (Admin + Maintenance)
- MAINT.DISM.RESTOREHEALTH (Admin + Maintenance)
- MAINT.REGOPT.PREVIEW (Admin + Maintenance)
- MAINT.REGOPT.APPLY   (Admin + Maintenance + explicit confirm)
- MAINT.EXPORT.REPORT

## Run Report Schema (JSON)
All modules output a `report.json` with:
- RunId, EngineVersion, Profile, UiMode, Mode
- StartedUtc, CompletedUtc
- IsElevated
- Gates (IsAdmin, MaintenanceMode, DevLab)
- Host (ComputerName, OSVersion, Build)
- SelectedActionIds
- Results[] (per action: Analyze + Apply blocks)
- Totals
- Evidence (ReportPath, ArchivePath, LogPath, optional EtlPath)

## V2 Non-Goals
- Destructive registry cleaning
- Backup file deletion
- Silent browser privacy wiping
- Standby list purge helper (V3 Lab-only)
- Active network scanning (V3)

## V3 Direction (Preview)
- Network intelligence + controlled scanning (highly gated)
- Deeper WFP/ETW correlation and attribution
- Optional enforcement hardening based on telemetry
