# V2 Threat Surface: Port Watch + Kernel/Near-Kernel Network Telemetry (Planning)

This doc defines a V2 threat-surface capability focused on:
- **Watching high-risk ports/services** (not “CVE ports”)
- **Capturing network telemetry** using legitimate Windows mechanisms
- Producing deterministic receipts + EVTX evidence

---

## 1) Goals
- Provide a versioned **ThreatSurface Watchlist** (ports/services, TCP/UDP, inbound/outbound).
- Implement deterministic firewall rules (AuditOnly vs Enforce).
- Provide tiered observability:
  - Tier 1: Windows Firewall/WFP auditing signals (event-driven)
  - Tier 2: Process ↔ connection correlation signals (when available)
  - Tier 3: Deep capture (support-mode) via ETW/pktmon style capture
  - Tier 4: Optional modern kernel-adjacent observability (eBPF for Windows) as it matures

---

## 2) Watchlist Model (manifest-driven)
Use a signed/hashed manifest that defines:
- Id
- Name
- Direction (In/Out)
- Protocol (TCP/UDP)
- LocalPort(s)
- Profiles (Domain/Private/Public)
- DefaultAction (Audit / Block / AllowWithScope)
- Scope (RemoteAddress ranges, LocalSubnet, Mgmt IPs)
- Rationale (short)
- Source (internal policy, hardening profile)

**Rule principle:** default to **EnableOnly** and **Public-safe posture**.

---

## 3) Enforcement Modes
### AuditOnly (default)
- No blocks added
- Reports:
  - Listening ports (what is bound)
  - Inbound allow exposure (public/all profiles, edge traversal, no remote address scoping)
  - Observed hits where telemetry supports it
- Writes receipt + EVTX

### Enforce (Admin-only)
- Creates/updates rules under Group tag `FirewallCorev2`
- Applies:
  - Block on Public by default for high-risk inbound
  - Scope required (LocalSubnet or Mgmt IP) for any inbound allow that remains
- Writes receipt + EVTX

---

## 4) Telemetry Tiers (legitimate)
### Tier 1 — WFP / firewall audit events (event-driven)
- Use Windows Filtering Platform and firewall auditing to observe allow/block decisions.
- Use EVTX routing into FirewallCore log for review.

### Tier 2 — Process ↔ network correlation (visibility)
- Where supported, correlate connections to processes (for outbound watchlist).
- Purpose: “which process is talking on watched ports” for containment.

### Tier 3 — Deep capture (support-mode only)
- On-demand capture sessions for diagnostics (ETW/pktmon class of tooling).
- Strict time-bounded capture + explicit operator intent + privacy notes.

### Tier 4 — eBPF for Windows (optional tracking)
- Track eBPF for Windows as a future observability hook for networking/security telemetry.
- Do not require it for V2 baseline; treat as optional/experimental.

---

## 5) Evidence + Logging
Every run writes:
- Receipt JSON:
  - Watchlist version, mode, deltas, rules changed, telemetry enabled, reboot-required flags
- EVTX events:
  - WatchlistLoaded, AuditReportWritten, EnforceApplied, TelemetryCaptureStarted/Stopped

No pasted logs in docs; pointers only.

---

## 6) Acceptance Criteria (future implementation gates)
- AuditOnly writes receipt + EVTX and makes no changes.
- Enforce is idempotent (second run delta=0).
- Public boundary never ends with discovery/sharing or high-risk inbound exposure enabled.
- Telemetry tiers are opt-in and evidence-driven (Tier 3 always support-mode, time-bounded).
- Manifest integrity is verifiable (hash/signature planned for V2+).

