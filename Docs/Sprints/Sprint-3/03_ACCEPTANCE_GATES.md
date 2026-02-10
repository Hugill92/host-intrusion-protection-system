# Sprint 3 Acceptance Gates

**Rule:** gates are deterministic PASS/FAIL checks. Keep them short and repeatable.

## Repo Hygiene Gate
- [ ] `git status --porcelain` is empty before test runs.
- [ ] Anchor commit recorded (short SHA).

## PowerShell Parse Gate (modified scripts only)
- [ ] `Parser::ParseFile()` returns 0 errors for modified `.ps1/.psm1/.psd1`.

## PS5.1 Compatibility Gate (modified scripts only)
- [ ] No PS7-only syntax/operators (e.g., `??`), no `.Where()` use, no modern-only APIs.
- [ ] ScheduledTaskAction `-Argument` is a single string (no arrays).

## Signing Gate (shipped scripts only)
- [ ] After changes, run signing stabilizer and confirm `Get-AuthenticodeSignature` is `Valid` for:
  - Modified shipped scripts/modules
  - Critical entrypoints (installer/uninstall/repair + signer toolchain)

## Signing Health Gate (mandatory preflight under AllSigned)
- [ ] Preflight enumerates all executed/imported ps1/psm1/psd1 for the operation and fails fast if any is:
  - NotSigned
  - HashMismatch
  - UnknownError
- [ ] Gate emits: first offender path + signature status + remediation hint.

## AllSigned Run Gate
- [ ] Install/Repair/Uninstall complete under intended policy without unsigned dependency failures.
- [ ] Unplug-key failure test behaves correctly (signing cannot occur without token).

## Installer Determinism Gate (LIVE signoff)
- [ ] INSTALL START emitted on entry.
- [ ] INSTALL NOOP emitted when already-installed (no side effects).
- [ ] Transcript artifacts produced per run (timestamped).

## FeatureSet V2 Gate (Windows Features) — planning only in Sprint 3
- [ ] AuditOnly mode: computes delta; makes no changes; writes a receipt.
- [ ] Enforce mode: enables only missing features; writes receipt; logs EVTX.
- [ ] Idempotent: second Enforce run delta=0.
- [ ] Reboot handling: apply uses `/NoRestart`; reboot-required is detected and surfaced.

## Network Admin Suite Gate (V2 planning / future implementation)
- [ ] AuditOnly: captures network inventory and writes receipt + EVTX; makes no changes.
- [ ] Enforce: executes only selected actions; writes receipt + EVTX.
- [ ] Public boundary: Public profile never ends with discovery/sharing enabled.
- [ ] Reset actions: require explicit operator intent; log reboot-required flags deterministically.
- [ ] NotSupported/NotApplicable are recorded deterministically (no brittle hacks by default).

## Threat Surface Watchlist Gate (V2 planning / future implementation)
- [ ] AuditOnly: generates exposure report + receipt + EVTX; no rule changes.
- [ ] Enforce: applies deterministic rules under `FirewallCorev2`; idempotent.
- [ ] Public-safe posture preserved: no high-risk inbound allows on Public without explicit scoped policy.
- [ ] Telemetry tiers: Tier 3 is support-mode only, time-bounded, explicit operator intent.
