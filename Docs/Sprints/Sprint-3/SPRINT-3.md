# Sprint 3 — Installer Hardening & Install Signoff

**Last updated:** 2026-02-04 00:00:19

## Status
- ✅ Installer signoff (LIVE) complete: deterministic behavior, repeatable logs, and safe NO-OP confirmed.
- 🔒 Installer is now locked on main (no further changes unless regression forces a critical fix).


## Signing (Sprint 3)
- Hardware-backed Authenticode signing finalized and validated.
- Installer artifacts sign and verify **Status=Valid** using the locked signing certificate.
- Signing behavior validated end-to-end (including unplug-key failure test).
- Signing is considered **part of Sprint 3 completion** and is locked with the installer.
## What’s now guaranteed (Install)
### Deterministic Event Log telemetry
- \INSTALL START\ emitted on entry.
- \INSTALL NOOP\ emitted when already-installed (no side effects).

### Deterministic operator evidence
- Transcript logs created per run (timestamped artifacts).
- Console output is consistent/readable for operator validation.

### Signing integrity
- Installer artifacts are Authenticode-signed and verify Status=Valid using the hardware-backed signing certificate.

## Baseline capture enhancement (install-time, one-time)
- Extend installer to ensure a PRE-install baseline export exists:
  - If missing: capture once during install.
  - If present: verify it exists and is readable.
- Baseline export artifacts (minimum):
  - .wfw (authoritative firewall export)
  - .json (inventory/metadata)
  - Additional end-to-end artifact (e.g., *.thc) per baseline workflow
- Hash all baseline artifacts using the existing tamper-protection hashing function (same logic used for Golden baseline integrity).

## Uninstall direction (next)
- Build canonical uninstall engine Uninstall-FirewallCore.ps1 with wrappers.
- Uninstall removes:
  - Scheduled tasks (current + legacy map)
  - FirewallCore-owned rules/policy via PRE baseline restore (fallback behavior explicitly logged)
  - ProgramData + logs/queue + custom event log (complete removal)
- Deterministic uninstall logs + transcript required.

## Repo hygiene decision
- Sprint notes must live on main under Docs\Sprints\Sprint-* so sprint history is visible without digging through branches.


## 2026-02-05 01:39:18 — AllSigned reinstall break / resign required (locked-in)

### Failure
- After uninstall → reinstall, installer fails under ExecutionPolicy=AllSigned when importing unsigned/invalid modules.
- Observed: Firewall\Modules\Firewall-InstallerBaselines.psm1 blocked (“not digitally signed”).
- Secondary issues encountered:
  - Installer logging helpers not available in session (Write-InstallerAuditLine / Write-InstallerEvent scope/order).
  - Signing helper parse error: “An empty pipe element is not allowed” (pipeline construction).

### Root cause
- AllSigned correctly blocks any NotSigned/HashMismatch dependency. Signing entry points is insufficient; imported modules/scripts must also be Valid-signed.
- Any patch/edit invalidates Authenticode → requires re-sign + verify before retest.

### Locked SOP
1) Identify first failing path from console error.
2) Get-AuthenticodeSignature on offender.
3) Unblock-File as needed (MOTW).
4) Re-sign execution surface (modules/helpers/task scripts) with A33 SHA256 and verify Status=Valid.
5) Re-run installer under AllSigned.

### Guardrail to implement
- Add a Signing Health Gate preflight that fails fast if any executed/imported ps1/psm1/psd1 is not Valid.


## 2026-02-05 01:52:47 — Installer fixed: deploy full Firewall root during install

### Fix
- Installer now deploys full Firewall runtime root from repo to C:\Firewall during install (not just partial staging).
- Root cause: Install-FirewallRootRuntime existed but was not called in install flow; call inserted in canonical installer path.

### Outcome
- Install succeeded end-to-end (event log ready, policy + PRE/POST baselines captured, certificate trusted, toast listener registered).
- Verified C:\Firewall exists after install, but initial count check showed partial tree prior to fix; now installer contract is to mirror full runtime root deterministically each install.

### Lessons learned
- AllSigned will fail fast on any unsigned module imported by the installer (e.g., Firewall-InstallerBaselines.psm1). Sign dependencies, not just entry points.
- PS5.1 Join-Path pitfalls: avoid passing object arrays to -AdditionalChildPath; prefer [IO.Path]::Combine() for targets lists.

### Next
- Add deterministic uninstall-step logging during install to stage Admin Panel UI gating and evidence.
- Investigate why some scripts require re-sign after install/uninstall even when no intentional edits were made; add signing health gate + evidence.

