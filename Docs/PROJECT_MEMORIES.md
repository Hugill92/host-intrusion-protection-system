# Protectus / FirewallCore — Project Memories

This document captures durable, project-level decisions and invariants for the Windows Host Intrusion Protection System (HIPS) project (FirewallCore).  
It is intended to be stable, actionable, and safe to publish.

---

## Deterministic workflow invariants

- Repo is the source of truth; live paths are treated as read-only except for deploy/sync steps.
- Use a repeatable loop for changes: edit → deploy to live → restart listener → preflight queue archive/purge → run signoff.
- Prefer paste-once console blocks for patches and reproducible operations.
- PowerShell rules:
  - PS5.1-safe syntax only; define functions before first use.
  - Avoid PS7-only operators/features.
  - When generating markdown in PowerShell, avoid backticks inside double-quoted strings.

---

## Process launch contract (no console flashes)

Scheduled tasks / protocol handlers must launch using:

- `powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden`
- Add `-STA` only when required.

---

## Event log architecture

- Create a dedicated `FirewallCore` Windows Event Log during install.
- Unify all FirewallCore.* providers under that log (including pentest/validation providers).
- Creation should run once on install for new machines.
- Uninstall may optionally remove the dedicated log (policy-dependent).

---

## Notifiers / toast pipeline invariants

- Listener is queue-based; severity behaviors are deterministic and validated by a manual visual signoff loop.
- Mandatory preflight before visual signoff:
  - Restart the listener
  - Archive/purge `C:\ProgramData\FirewallCore\NotifyQueue` to avoid ghost/stuck alerts impacting deterministic results
- Platform limitation: if Windows PowerShell cannot subscribe to Windows Runtime events, run without WinRT subscriptions (timer-based/queue-based behavior remains the baseline).

---

## Firewall baselines, exports, and hashing

- Before/after any policy or rule change:
  - Export authoritative policy (.wfw)
  - Compute and store SHA256
  - Capture inventory and evidence
- Enforcement invariant:
  - Enabled + Block rules enforce security posture
  - Disabled rules do not apply
  - Block takes precedence over Allow
- Baseline labels are for export folders (e.g., DEFAULT / PRE-<change> / POST-<change>), not for rule Group tags.

---

## Firewall rule tagging architecture (WFAS Group)

Purpose: Make ownership of firewall rule state explicit. If FirewallCore changes a Windows rule (or adds one), it becomes a version-owned rule state and must be tagged.

### Group tag values (exact strings)
- `FirewallCorev1` = rules added/modified by v1 policy application
- `FirewallCorev2` = rules added/modified by v2 policy application (future)
- `FirewallCorev3` = rules added/modified by v3 policy application (future)

### What gets tagged
- Any rule whose effective configuration was changed by FirewallCore (even if originally shipped with Windows)
- Any new rule added by FirewallCore

### Canonical tagging workflow
1) Capture PRE baseline export + SHA256 (same machine/state).
2) Apply FirewallCore policy changes.
3) Capture POST baseline export + SHA256.
4) Diff PRE vs POST to produce a Names manifest of Added + Modified rules (WFAS `rule.Name`).
5) Apply Group tag to only those Names using a reliable tagging method (WFAS COM API is the fallback when NetSecurity cmdlets are unreliable).
6) Verify tagged count, log missing names, then export the canonical tagged policy (.wfw) + SHA256.

### Canonical policy artifacts (repo)
Policy must exist in BOTH locations (same hash), replacing prior versions:
- `C:\FirewallInstaller\Policies\FirewallCorePolicy_v1.wfw`
- `C:\FirewallInstaller\Firewall\Policy\FirewallCorePolicy_v1.wfw`
…and each must have a sidecar hash file:
- `FirewallCorePolicy_v1.wfw.sha256.txt`

### Names manifest contract
- A JSON manifest (Grouping=`FirewallCorev1`; Names[] contains WFAS rule.Name strings) is the source of truth for which rules must be tagged.
- Tagging must NOT guess by DisplayName; tag by WFAS rule.Name from the manifest.

---

## Risk audit notes for inbound allows (v1 analysis)

- Inbound Allow rules scoped to Public/all profiles and without RemoteAddress restrictions are high-risk.
- Known areas to review and restrict as appropriate: Print Spooler, WMI, mDNS (5353), SSDP (1900), Delivery Optimization (7680), Hyper-V/VMMS RPC exposure, and EdgeTraversal inbound allows.
- Preserve essential DHCP inbound rules (UDP 68/546).

---

## Admin Panel direction (v1 → future)

- v1 Admin Panel should show:
  - Health/Status (install state, task status, rule counts by Group tags, event log health, queue counts, last test summary)
  - Actions (Repair, Uninstall with keep logs option, Open Logs, Open Event Viewer filtered view, Export Baseline+SHA256)
  - Safe self-tests (notification pipeline per severity, listener running, rule integrity, queue permissions)
- Privileged actions must be gated behind admin elevation + an explicit maintenance mode unlock.

---

## Time integrity feature (TimeGuard / Clock Integrity)

- Monitor system time changes via Security Event ID 4616 (who/process/previous/new time)
- Correlate with System “Kernel-General” clock change events and Time-Service operational events
- Maintain allowlist + delta thresholds
- Default: audit-only (log + notify on suspicious/unapproved/large jumps)
- Optional harden mode: tighten time-change privileges, validate time service config, auto-resync when unauthorized drift detected
- Surface a “Time Integrity” health row + “Export Time Integrity Report” action in the Admin Panel

---

## Signing direction (future hardening)

- Enforce Authenticode signing for shipped scripts and binaries.
- Run scheduled tasks under AllSigned policy with an integrity gate (refuse to run if signatures are invalid).
- Use hardware-backed code signing keys/certificates and install trust chain as part of the product lifecycle.
