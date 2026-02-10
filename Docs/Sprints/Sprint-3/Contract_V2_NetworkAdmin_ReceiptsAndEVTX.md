# Contract: V2 NetworkAdmin — Manifest + Receipt + EVTX

This document defines the deterministic contract for **NetworkAdmin** actions:
- Network inventory (AuditOnly)
- DHCP “New IP” (default one-click)
- Static IP write (Maintenance-gated)
- Sharing/Profile converge

---

## 1) Policy Manifest (NetworkAdminFeatureSet.json)

### Required fields
- **FeatureSetId**: string (e.g., `NetworkAdmin`)
- **Version**: string (SemVer or date version)
- **ModeDefaults**
  - DefaultMode: `AuditOnly` (recommended)
  - AllowEnforce: boolean
- **Capabilities**
  - Diagnostics: boolean
  - DhcpRenew: boolean
  - StaticIpWrite: boolean
  - SharingConverge: boolean
  - ProfileConverge: boolean
  - RepairActions: boolean (Winsock/TCPIP reset group)
- **Guardrails**
  - RequireAdminForEnforce: true
  - RequireMaintenanceForStaticIp: true
  - PublicSafeSharing: true
  - NoForcedReboot: true
- **Targets**
  - AdapterSelection
    - Default: `ActivePrimary`
    - AllowExplicitInterfaceAlias: true
- **StaticIpDefaults** (optional)
  - RequireGateway: false/true (policy)
  - RequireDns: false/true (policy)

### Example (shape only)
```json
{
  "FeatureSetId": "NetworkAdmin",
  "Version": "2.0.0",
  "ModeDefaults": { "DefaultMode": "AuditOnly", "AllowEnforce": true },
  "Capabilities": {
    "Diagnostics": true,
    "DhcpRenew": true,
    "StaticIpWrite": true,
    "SharingConverge": true,
    "ProfileConverge": true,
    "RepairActions": true
  },
  "Guardrails": {
    "RequireAdminForEnforce": true,
    "RequireMaintenanceForStaticIp": true,
    "PublicSafeSharing": true,
    "NoForcedReboot": true
  },
  "Targets": {
    "AdapterSelection": {
      "Default": "ActivePrimary",
      "AllowExplicitInterfaceAlias": true
    }
  }
}
```

---

## 2) Receipt JSON (every run)

### Location (planned)
- `C:\ProgramData\FirewallCore\Receipts\NetworkAdmin\NETWORKADMIN_<timestamp>_<runid>.json`

### Required fields
- ReceiptSchema: `NetworkAdminReceipt.v1`
- TimestampUtc
- RunId
- Mode: `AuditOnly` | `Enforce`
- CallerContext
  - User
  - IsAdmin
  - MaintenanceMode (true/false)
  - UiSource (AdminPanel/CLI/Task)
- AdapterContext
  - InterfaceAlias
  - InterfaceGuid
  - IfIndex
  - Connected (true/false)
- NetworkContextBefore / NetworkContextAfter
  - Category (Public/Private/DomainAuthenticated if available)
  - IPv4Address[] / IPv6Address[] (may be empty)
  - Gateway[] / DnsServers[]
  - DhcpEnabled (true/false)
- ActionsRequested[] (ordered)
- ActionsResults[] (ordered; one per action)
  - ActionId
  - ActionType (Inventory/DhcpRenew/StaticWrite/DnsFlush/ReleaseRenew/WinsockReset/TcpipReset/ProfileConverge/SharingConverge)
  - Outcome (Success/Failed/NoChange/NotSupported/NotApplicable/Skipped)
  - Error (nullable)
  - DeltaSummary (short)
- RebootRequiredBefore / RebootRequiredAfter (bool)
- ConnectivityImpact (None/TransientDisconnect/Unknown)

### Action-specific payloads
- DhcpRenew
  - LeaseBefore/After (best-effort)
  - IpBefore/After
- StaticWrite
  - StaticConfigRequested (ip/prefix/gateway/dns)
  - SnapshotId (for rollback)
  - RollbackAvailable (bool)

---

## 3) EVTX Contract (events)

### Provider / Channel
- Provider(s): FirewallCore.NetworkAdmin (planned)
- Channel: FirewallCore (dedicated log)

### Required events (names are stable; IDs assigned in EventId schema)
- NetworkAdmin.Start
- NetworkAdmin.InventoryCaptured
- NetworkAdmin.ActionRequested
- NetworkAdmin.ActionResult
- NetworkAdmin.Complete
- NetworkAdmin.Failed

### Payload rules
- Always include RunId + Mode
- Include ActionType + Outcome + short DeltaSummary
- Never log secrets (Wi-Fi passwords, tokens, etc.)

---

## 4) UI Wiring Contract (Admin Panel)

- **“New IP (DHCP)”** button
  - Default path: Enforce (admin required)
  - Shows confirmation (transient disconnect expected)
- **“Static IP…”** button
  - Requires Maintenance Mode + admin
  - Opens dialog to collect:
    - InterfaceAlias (dropdown)
    - IPAddress, PrefixLength, Gateway, DNS (fields)
  - Includes “Rollback after apply” toggle (optional)
- All buttons produce receipt + EVTX and update UI row status deterministically.
