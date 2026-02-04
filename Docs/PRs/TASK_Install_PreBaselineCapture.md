# Tasking — Install Hardening: PRE Baseline Capture (Deterministic)

## Objective
Ensure every FirewallCore install produces (or verifies) a **PREINSTALL firewall baseline** BEFORE applying any FirewallCore rules/policy. This enables deterministic uninstall restore.

---

## Scope
### Files to implement / modify
1) Create helper:
- `Tools\Baselines\Ensure-PreInstallBaseline.ps1`

2) Modify installer entrypoint:
- `Install-FirewallCore.ps1` (or the canonical installer PS1 used by Install.cmd)
  - Call helper early (before any policy import / rule changes)
  - Log results (event IDs + transcript/file log)

---

## Constraints / Standards
- PowerShell **5.1** compatible only.
- Must run under **AllSigned**.
- Deterministic logging: Event Log + file log (transcript already exists).
- Must be idempotent:
  - First install: create PRE baseline
  - Subsequent installs: NOOP (baseline exists) unless `-Force` explicitly used (if supported)

---

## Baseline Output Contract
Create under:
- `C:\ProgramData\FirewallCore\Baselines\PREINSTALL_YYYYMMDD_HHMMSS\`

Required artifacts:
- `Firewall-Policy.wfw`  (authoritative WFAS export)
- `Firewall-Policy.json` (inventory/metadata)
- `Firewall-Policy.thc`  (end-to-end artifact; if generator missing, write stub + log WARN)

Hashing:
- Hash the artifacts using the **existing tamper/hashing function** already in repo.
- Hash output location should be in the same folder (e.g., `SHA256SUMS.txt` or equivalent existing format).

---

## Deterministic Event Log Contract
Log: `FirewallCore`  
Source/Provider: `FirewallCore-Installer`

Event IDs:
- **1100** — `BASELINE PRECAPTURE START`
- **1108** — `BASELINE PRECAPTURE OK | path=<...>`
- **1103** — `BASELINE PRECAPTURE NOOP | reason=baseline-exists | path=<...>`
- **1901** — `BASELINE PRECAPTURE FAIL | <exception>`

Rules:
- Always emit START then exactly one terminal event (OK/NOOP/FAIL).

---

## Implementation Notes

### Discovery logic
- Detect existing PRE baseline folder by pattern: `PREINSTALL_*` (latest by LastWriteTime).
- If exists and not forced:
  - Verify required artifacts exist. If any missing, treat as FAIL (or repair if safe; must be logged).
  - Return NOOP with reason.

### Export logic (WFW)
- Use the project’s authoritative “bulletproof export” method if present.
- If not present, implement a safe export using `netsh advfirewall export <path>` and verify file exists + non-zero size.

### JSON inventory content (minimum)
Include:
- Type = PREINSTALL
- Timestamp (ISO 8601)
- ComputerName, Username
- Count of firewall rules (optional but preferred)
- Note whether export succeeded, and any warnings

### THC artifact
- If a THC generator exists in the repo, call it and write the artifact.
- If not, write a placeholder file and log WARN into file log (do not fail install solely due to missing THC until generator is wired).

### Hashing
- Call the existing hashing routine (tamper protection / baseline hashing).
- If hashing fails, log FAIL and stop install (preferred) OR log WARN (only if you decide hashing is “best effort” — must be explicit).

---

## Acceptance Tests

### Fresh install
- Run installer → baseline folder created with .wfw/.json/(.thc)
- Event log shows 1100 → 1108
- File log includes baseline path and hash evidence

### Re-run installer (already installed)
- Baseline pre-capture returns NOOP (baseline exists)
- Event log shows 1100 → 1103

### Failure mode
- Simulate export failure (deny write / disk full) → event log 1901 and install exits non-zero

---

## Signing / Release Gate
After code changes:
1) Parse gate (0 parse errors)
2) PS5.1 syntax gate
3) Re-sign modified scripts with A33 cert (SHA256)
4) Verify `Get-AuthenticodeSignature` = Valid
5) Run installer under AllSigned (DEV first)

---

## Changes Made / Implementations Done
(Fill in)

- [ ] Helper created: Ensure-PreInstallBaseline.ps1
- [ ] Installer wired to call helper pre-policy changes
- [ ] WFW export implemented and verified
- [ ] JSON inventory implemented
- [ ] THC artifact implemented or stubbed with WARN
- [ ] Hashing integrated using existing function
- [ ] Event IDs wired (1100/1108/1103/1901)
- [ ] Scripts re-signed with A33 and verified Valid
- [ ] Acceptance tests executed and evidence captured
