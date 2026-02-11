# Contract: V2 ThreatSurface — Watchlist Manifest + Receipt + EVTX

This defines the deterministic contract for:
- Watchlist (ports/services) driven rule generation
- AuditOnly exposure reporting
- Enforce application of rules under `FirewallCorev2`
- Telemetry tiers (baseline vs support-mode)

---

## 1) Watchlist Manifest (ThreatSurfaceWatchlist.json)

### Required fields
- **WatchlistId**: string (e.g., `ThreatSurface`)
- **Version**: string
- **Defaults**
  - DefaultMode: `AuditOnly`
  - Profiles: `Domain,Private,Public`
  - PublicSafe: true
- **Items[]**
  - Id (stable unique)
  - Name
  - Direction: `In` | `Out`
  - Protocol: `TCP` | `UDP`
  - LocalPorts: array of string (allow ranges like `"135"`, `"445"`, `"5000-5010"`)
  - RemotePorts: array (optional; usually empty unless needed)
  - Profiles: array (`Public`/`Private`/`Domain`)
  - DesiredAction: `Audit` | `Block` | `AllowScoped`
  - RemoteAddressScope: `Any` | `LocalSubnet` | `MgmtList` | `ExplicitRanges`
  - Rationale: short string
  - Source: string

### Example item (shape only)
```json
{
  "Id": "IN_TCP_445_SMB",
  "Name": "SMB Inbound",
  "Direction": "In",
  "Protocol": "TCP",
  "LocalPorts": ["445"],
  "Profiles": ["Public", "Private", "Domain"],
  "DesiredAction": "Block",
  "RemoteAddressScope": "Any",
  "Rationale": "Reduce exposure of SMB on endpoints",
  "Source": "FirewallCore V2 baseline"
}
```

---

## 2) Receipt JSON (every run)

### Location (planned)
- `C:\ProgramData\FirewallCore\Receipts\ThreatSurface\THREATSURFACE_<timestamp>_<runid>.json`

### Required fields
- ReceiptSchema: `ThreatSurfaceReceipt.v1`
- TimestampUtc
- RunId
- Mode: `AuditOnly` | `Enforce`
- WatchlistId + Version
- Summary
  - ItemsTotal
  - ItemsApplied
  - RulesCreated
  - RulesUpdated
  - RulesUnchanged
- ExposureReport (AuditOnly required; Enforce optional)
  - ListeningPorts (best-effort snapshot)
  - InboundAllowRisks (public/all profiles, edge traversal, no scope)
  - Notes
- ApplyResults[]
  - ItemId
  - RuleName
  - Outcome (Success/Failed/NoChange/NotSupported/Skipped)
  - Error (nullable)
- Telemetry
  - TierEnabled (1/2/3/4)
  - CaptureId (if Tier 3)
  - CaptureDurationSeconds (if Tier 3)
- GuardrailsEnforced
  - PublicSafeBoundaryPreserved (bool)
  - EdgeTraversalAvoided (bool)

---

## 3) EVTX Contract (events)

### Provider / Channel
- Provider(s): FirewallCore.ThreatSurface (planned)
- Channel: FirewallCore

### Required events
- ThreatSurface.Start
- ThreatSurface.WatchlistLoaded
- ThreatSurface.AuditReportWritten
- ThreatSurface.EnforceApplied
- ThreatSurface.TelemetryTierEnabled
- ThreatSurface.Complete
- ThreatSurface.Failed

### Payload rules
- Always include WatchlistId/Version + RunId + Mode
- Never log raw packet payloads in EVTX
- Tier 3 capture outputs go to diagnostics bundles, referenced by pointer only

---

## 4) Telemetry Tiers (policy)

- **Tier 1**: baseline events (low noise)
- **Tier 2**: process correlation if available (moderate)
- **Tier 3**: support-mode capture, time-bounded and explicit operator intent (high)
- **Tier 4**: optional/experimental (future)

Tier 3 must:
- Require Admin + explicit confirmation
- Have a hard duration cap
- Store outputs under diagnostics folder with retention limits
