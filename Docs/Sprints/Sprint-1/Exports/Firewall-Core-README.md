# Firewall Core + WFP Monitor
## Unified Documentation

This document is the authoritative reference for the Firewall Core + WFP Monitor project.
It covers architecture, installation, runtime behavior, security model, and maintenance.

---


## Installer Architecture

Firewall Core uses a two-layer design:

- **FirewallInstaller** (one-shot, mutable)
- **Firewall** (runtime, protected)

The installer copies a signed payload from
`C:\FirewallInstaller\Firewall` into `C:\Firewall`,
then registers scheduled tasks running as SYSTEM.

Installer scripts are never scheduled and are safe
to remove after uninstall.


## 1. Project Overview

Firewall Core + WFP Monitor is a defensive Windows firewall orchestration system built on:
- Windows Defender Firewall
- Windows Filtering Platform (WFP)
- PowerShell-based enforcement and monitoring

Goals:
- Detect anomalous network behavior
- Enforce temporary and persistent blocks
- Preserve system stability
- Provide auditable, reversible actions

---

## 2. Directory Layout

C:\
├─ FirewallInstaller\          ← INSTALL / UNINSTALL LAYER (one-shot)
│  ├─ install-firewall.cmd     ← user entrypoint (Admin)
│  ├─ uninstall-firewall.cmd   ← restores system to default
│  ├─ install-debug.txt        ← transcript output (persistent)
│  │
│  ├─ _internal\               ← installer-only PowerShell
│  │  ├─ Install-Firewall.ps1
│  │  └─ Uninstall-Firewall.ps1   (next phase)
│  │
│  ├─ Firewall\                ← PAYLOAD (copied verbatim)
│  │  ├─ Monitor\
│  │  ├─ Modules\
│  │  ├─ Maintenance\
│  │  ├─ Scripts\
│  │  ├─ State\
│  │  ├─ Golden\
│  │  ├─ Tests\
│  │  ├─ Tools\
│  │  ├─ README.md
│  │  └─ ScriptSigningCert.cer
│  │
│  └─ Docs\
│     ├─ Firewall-Core-README.md
│     └─ Firewall-Core-Documentation.pdf
│
└─ Firewall\                   ← LIVE SYSTEM (runtime)
   ├─ Monitor\
   ├─ Modules\
   ├─ Maintenance\
   ├─ Scripts\
   ├─ State\
   ├─ Golden\
   ├─ Logs\
   └─ README.md

---

## 3. Installer

Install-Firewall.ps1 performs:
- Directory creation
- Payload copy
- Certificate trust (best-effort)
- Firewall baseline application
- Scheduled task registration
- Execution policy hardening

Installer is idempotent and safe to re-run.

---

## 4. Firewall Core Monitor

Runs every 5 minutes as SYSTEM.

Responsibilities:
- Detect firewall drift
- Restore baseline rules
- Log drift (EventId 3200)
- Log restore actions (EventId 3001)

No enforcement escalation occurs here.

---

## 5. WFP Monitor (Phases A–C4)

### Phase A – Audit Enablement
Enables Security log events:
- 5152
- 5157
- 5159

### Phase B – Passive Observation
- Parses WFP Security events
- Writes summary EventId 3400

### Phase C1 – Signal Analysis
- Noise filtering
- Burst detection (EventId 3410)

### Phase C2 – Temporary Enforcement
- Threshold-based alerts (EventId 3401)
- Temporary outbound block (WFP-TEMP-BLOCK)

### Phase C3 – Persistent Enforcement
- Strike-based escalation
- Persistent outbound block (WFP-PERSISTENT-BLOCK)
- EventId 3402

### Phase C4 – Deny-Hash Enforcement
- SHA256 denylist
- Immediate quarantine
- EventId 3404

---

## 6. State Files

- baseline.json
  Canonical firewall rule state

- golden.hash.json
  Integrity hashes for protected scripts

- wfp.config.json
  Runtime thresholds and feature toggles

- wfp.allowlist.json
  Noise suppression rules

- wfp.denyhash.json
  Known-bad executable hashes

- wfp.strikes.json
  Per-executable strike counters

- wfp.blocked.json
  Persistent enforcement registry

- wfp.bookmark.json
  Event log resume pointer

---

## 7. Tamper Protection

- Golden hash verification
- Script signing
- SYSTEM-owned scheduled tasks
- Idempotent restoration

---

## 8. Tests

Tests\ contains DEV-ONLY scripts:
- Test-WFP-C2.ps1
- Test-WFP-C3.ps1
- Test-WFP-C4.ps1

These simulate enforcement paths and validate state transitions.

---

## 9. Maintenance

Maintenance\ scripts handle:
- Baseline regeneration
- State cleanup
- Rule pruning
- Log rotation

---

## 10. Logs & Events

Custom Event Log: Firewall

Key Event IDs:
- 3001 – Baseline restore
- 3200 – Drift detected
- 3400 – WFP summary
- 3401 – WFP alert
- 3402 – Persistent block
- 3404 – Deny-hash block
- 3410 – Burst warning
- 3412 – Correlation warning

---

## 11. Security Model

- Default deny escalation
- Least privilege
- Explicit allowlist
- Full reversibility
- No kernel drivers
- No packet injection

---

## 12. Uninstall (Future)

Planned uninstall will:
- Remove scheduled tasks
- Remove WFP-* rules
- Restore firewall defaults
- Remove certificates
- Preserve logs (optional)

---

## 13. Change Management

This README is version-controlled.
Update when:
- New phases are added
- Thresholds change
- Enforcement logic changes

