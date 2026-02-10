# V2 Network Admin: Networking Suite + Sharing/Profile Controls (Planning)

This doc defines V2 “Admin / Advanced Network Features” that help operators quickly stabilize networking and enforce safer defaults—without guesswork.  
**Scope:** planning + deterministic data flow (not implementation yet).

---

## 1) Goals (V2)
- Provide an **IPConfig / NetStack Suite** for troubleshooting (audit-first; admin-enforced actions gated).
- Allow deterministic configuration of:
  - Network profile category (Public/Private)
  - Per-network properties (e.g., randomized MAC rotation cadence where supported)
  - Sharing posture (Network Discovery / File & Printer Sharing / Password-protected sharing)
- Wire visibility into **Windows Security / Defender** posture and firewall enforcement.

---

## 2) Design Principles (Deterministic + Safe)
- **Idempotent converge:** desired state → compute delta → apply only what’s missing.
- **AuditOnly mode:** compute + report, no changes.
- **Enforce mode:** makes changes (admin-only).
- **Receipts + EVTX:** every run produces a receipt and structured events.
- **No surprise toggles:** high-impact changes require explicit operator action (Maintenance/Admin mode).
- **Profile-aware:** Public vs Private is treated as a security boundary; Public defaults stay locked down.

---

## 3) Capability Model (V2 “NetworkAdmin” FeatureSet)
V2 introduces a versioned “NetworkAdmin FeatureSet” (separate from Windows Optional Features FeatureSet).

### Capability groups
1) **Network Diagnostics Suite (Safe)**
   - View adapter/IP state, DNS, routes, TCP connections, gateway
   - Run targeted connectivity checks

2) **Network Reset / Repair Actions (High-impact; admin-only)**
   - Flush DNS client cache
   - Renew DHCP lease (release/renew)
   - Reset Winsock catalog
   - Reset TCP/IP stacks (IPv4/IPv6)
   - Optional: selective NIC disable/enable (if required; gated)

3) **Network Profile Controls (Security boundary)**
   - Set active connection category: Public/Private
   - Validate against expected policy (e.g., always Public on unknown networks)
   - Record SSID + profile + last-change evidence

4) **Per-Network Privacy Controls**
   - Random hardware addresses (MAC randomization) policy per SSID, with “Change daily” target where supported

5) **Sharing Posture Controls**
   - Network Discovery (Private on / Public off)
   - File & Printer Sharing (Private on/off by policy; Public off)
   - Password-protected sharing (On by default for security posture)
   - Public folder sharing (Off by default)

---

## 4) Data Flow (AuditOnly → Enforce)
### A) Preflight
- Confirm elevation if Enforce requested
- Determine active adapters + connection profiles
- Detect pending reboot state (for reset actions)

### B) Detect (Inventory)
- Capture current:
  - IP configuration, gateways, DNS, route table, adapter status
  - Network category (Public/Private)
  - Sharing posture (Discovery/FPS/Password-protected/Public folder sharing)
  - Firewall rule-group state relevant to discovery/sharing (as evidence)

### C) Decide
- Compare current state to target policy
- Compute delta:
  - Changes needed (per capability group)

### D) Apply (Enforce)
- Execute only selected actions, in safe order:
  1) Non-disruptive (DNS flush)
  2) DHCP renew (optional)
  3) Winsock/TCPIP resets (last resort; warn reboot requirement)
  4) Profile/sharing convergence (policy-driven)

### E) Verify + Receipt
- Re-inventory key signals
- Write receipt: actions attempted, outcomes, reboot-required flags

---

## 5) IPConfig / NetStack Suite (Operator UX)
This suite should exist as:
- CLI tool (PowerShell entrypoint) for support ops
- Admin Panel buttons (AuditOnly + Enforce variants)
- “Export Network Report” action for evidence bundles

### Diagnostics commands (examples)
- Show IP state
- Show adapter state
- Show DNS client cache / resolver tests
- Show routes
- Show active connections
- Connectivity test (targeted)

### Repair actions (admin-only)
- Flush DNS cache
- Release/Renew DHCP
- Reset Winsock
- Reset IPv4/IPv6 TCPIP

**Policy note:** reset actions must clearly warn about transient disconnects / reboot requirement and must log evidence.

---


## 5.1) IP Change Feature (DHCP Renew + Static Write)

V2 supports **both** “new IP” paths with deterministic receipts + EVTX, and explicit operator intent for disruptive actions.

### A) New IP via DHCP (recommended default)
**Intent:** request a new IP from the DHCP server (lease refresh). This is the safe default.

- AuditOnly:
  - Show active adapter, current IPv4/IPv6, gateway, DNS, DHCP state
  - Record lease metadata when available
- Enforce (Admin-only):
  - Execute a DHCP release/renew cycle for the selected adapter
  - Verify new configuration and record delta
  - Record reconnect impact evidence (disconnect window)

**Guardrails**
- Do not promise public internet IP change (ISP/NAT controlled).
- If DHCP server returns same lease, outcome is `NoChange` (still deterministic).

### B) Write a Static IP (advanced)
**Intent:** set a specific IPv4/IPv6 on an interface (requires explicit parameters).

Inputs (minimum):
- InterfaceAlias
- IPAddress
- PrefixLength
- DefaultGateway (optional but typical)
- DnsServers (optional)

- AuditOnly:
  - Validate the IP is within the local subnet
  - Best-effort conflict checks (ARP/neighbor cache evidence where possible)
  - Show “proposed config” vs “current config”
- Enforce (Admin-only + Maintenance Mode recommended):
  - Snapshot prior config (for rollback)
  - Apply static config
  - Verify post-state and record delta
- Rollback:
  - One-click revert to prior snapshot

**Guardrails**
- Must write a receipt capturing Before/After, and store rollback snapshot with the receipt.
- Must warn that connectivity disruption is expected.

## 6) Network Profile Controls (Public/Private)
V2 should support:
- Read current category per active connection
- Enforce target category under policy (e.g., “unknown networks default to Public”)
- Record every change in EVTX + receipt

---

## 7) Per-Network MAC Randomization (Privacy)
Goal:
- Per-network setting for random hardware address rotation (e.g., “Change daily”).

Plan:
- Provide **AuditOnly detection** of:
  - Whether random hardware addresses are enabled for the SSID
  - The configured rotation cadence (when discoverable)
- Provide **Enforce** to set the desired policy, only when supported by OS/build and adapter.

Guardrail:
- If OS/build does not expose a stable configuration API, record `NotSupported` deterministically (no brittle hacks by default).

---

## 8) Sharing Settings Convergence (Discovery/FPS/Password-Protected)
Target posture example (your “FirewallCore” desired stance):
- **Private networks:** Discovery = On, File/Printer Sharing = On (if required), Password-protected sharing = On
- **Public networks:** Discovery = Off, File/Printer Sharing = Off
- **All networks:** Public folder sharing = Off; stronger sharing connection security where available

Implementation plan (deterministic):
- Measure/drive using:
  - Firewall rule groups associated to “Network Discovery” and “File and Printer Sharing”
  - Service state evidence where applicable
  - Policy/security settings evidence for password-protected sharing

Guardrail:
- Never open inbound sharing on Public. If Public profile is active, enforce Public-safe posture immediately.

---

## 9) Windows Security / Defender Wiring (Visibility)
V2 should surface:
- Defender health status signals (high-level)
- Firewall profile enforcement status
- Tamper-protection relevant indicators (visibility only; no brittle modifications)

Output:
- “Security Posture Snapshot” section in the Network Report
- EVTX events for posture checks, not just actions

---

## 10) Evidence + Logging
- Receipt JSON written every run:
  - Mode (AuditOnly/Enforce)
  - Connection profile details (category, SSID, adapter)
  - Actions requested, attempted, outcomes
  - Reboot required flags
  - NotSupported / NotApplicable determinations

- EVTX events (network admin band):
  - InventoryCaptured
  - ActionRequested
  - ActionResult
  - ConvergeComplete (with reboot-required)

**Docs rule:** no pasted logs; only pointers.

---

## 11) Acceptance Criteria (Sprint gates; implementation later)
- AuditOnly makes no changes; produces receipt + EVTX.
- Enforce changes only what’s targeted; produces receipt + EVTX.
- Public profile never ends with discovery/sharing enabled.
- Reset actions require explicit operator intent and record impact evidence.
- NotSupported conditions are recorded deterministically.




