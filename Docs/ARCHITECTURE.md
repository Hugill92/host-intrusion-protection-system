# FirewallCore Architecture

## Purpose
FirewallCore is a Windows security/hardening package that manages firewall policy, monitoring, and user notification with a focus on reliability, auditability, and enterprise-friendly conventions.

This document defines the *invariants* and core design philosophy. It should change slowly.

---

## Design principles (invariants)

### 1) Fail early, fail loud
- Any install/repair/start operation must validate prerequisites first.
- If validation fails, the operation must stop **before** making changes, and must log:
  - the root cause
  - the phase that failed
  - a standard exit code (Windows Installer style where applicable)

### 2) One orchestration brain
- A single coordinator (“orchestrator”) owns and sequences:
  - Install
  - Repair
  - Uninstall
  - Verify
  - Stop (force-close/unload)
- All workers (scripts, tasks, listeners) are started *only* through the orchestrator.
- Each time any worker/thread/task is started, the orchestrator re-checks guardrails.

### 3) Deterministic install semantics
- The install flow must be deterministic and idempotent where feasible:
  - running install twice should not create inconsistent state
  - repair should converge state back to expected baseline
- Uninstall should aim for full cleanup (best-effort “rm -f” behavior) unless constrained by enterprise packaging rules.

### 4) Explicit state + logs
- State must be written to a known location (e.g., ProgramData) and never silently assumed.
- Logs must be structured enough to support:
  - quick operator diagnosis
  - CI/build debugging
  - postmortem analysis

### 5) Enterprise alignment
- Prefer standard conventions:
  - Windows Installer-style exit codes (1600-series, 3010, etc.)
  - clear separation of install/repair/uninstall responsibilities
  - compatibility with managed endpoint constraints (Defender/Tamper considerations)

### 6) Supply chain & artifact hygiene
- Builds must be auditable:
  - minimize unexpected artifacts
  - scan outputs for suspicious filenames/metadata
  - support optional hash baselining for shipped artifacts
- Detect packaging drift early (e.g., multiple EXEs when only one is expected).

---

## System components (conceptual)

### Orchestrator (the “brain”)
Responsibilities:
- Acquire a lock to prevent concurrent runs (avoid “install.cmd went rogue” scenarios).
- Run preflight validation.
- Start/stop workers and scheduled tasks only after validation passes.
- Provide a jetison path: if an internal component fails, stop cleanly and report why.

### Preflight validation
Must verify:
- execution context (admin vs user)
- script integrity (parse validation at minimum)
- dependencies required for the mode requested (install/repair/verify)
- environment constraints (managed endpoint / Defender coexistence, as applicable)

### Workers (PowerShell and/or Python)
- PowerShell remains the OS automation layer (“instruction booklets”).
- Python (optional) may act as a thin wrapper that calls Windows APIs or runs orchestration logic, and can be packaged as a single EXE via PyInstaller.

### Scheduled tasks
- Must not be registered or started unless validation passes.
- Must use verified principals (SYSTEM/service accounts/user where intended).
- Must have explicit failure reporting and retry behavior defined.

---

## Packaging strategy (architectural intent)
- WiX/MSI is **not required** for builds.
- MSI/WiX is primarily valuable for:
  - registry injection requirements
  - enterprise deployment ergonomics
  - strict install/repair/upgrade/rollback semantics
- Alternate distribution path:
  - GitHub Actions builds a single-file Windows EXE via PyInstaller (`--onefile`).

---

## Security posture (architectural intent)
- Document and support:
  - file scanning + hashing baseline strategies
  - registry scanning strategies
  - intended GPO policy scope (what policies are set and why)
- Treat unexpected extra packages/artifacts as build failures (or at least elevated warnings).

---

## Exit codes (architectural intent)
- Use well-known Windows Installer-style codes when aborting operations.
- Always log the root cause before exiting non-zero.

## Notifier pipeline (Queue → Listener → Toast/Dialog)

### Producer
- Send-FirewallNotification writes a SchemaVer=1 JSON payload to:
  - C:\ProgramData\FirewallCore\NotifyQueue\Pending\*.json
- Payload includes: CreatedUtc, Severity, Title, Message, EventId (derived), TestId, Provider, Mode, Host, User, and UX routing.

### Listener (user session, STA)
- Runner: C:\Firewall\User\FirewallToastListener-Runner.ps1
- Listener: C:\Firewall\User\FirewallToastListener.ps1
- Reads Pending, moves items to Processing, then routes:
  - Toast-only → Processed
  - Dialog workflow → Reviewed (Warning) / Working (Critical)
- Heartbeat file used to confirm listener activity:
  - C:\ProgramData\FirewallCore\State\toastlistener.heartbeat

### Toast behavior
- WinRT toast rendered via ToastNotificationManager.
- Toast XML uses <audio silent='true'/> so Windows system sounds never play.
- Custom WAV sounds are played by FirewallCore (ding/chimes/chord).
- Toast buttons/actions use protocol activation:
  - irewallcore-review://open?... handled by FirewallToastActivate.ps1

### Dialog behavior
- Warning dialog auto-closes (20s).
- Critical dialog requires manual review and reminds (10s cadence).

