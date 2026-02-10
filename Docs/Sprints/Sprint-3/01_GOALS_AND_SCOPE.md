# Sprint 3 Goals and Scope

## Goals (what we WILL do)
- [x] Finalize hardware-backed Authenticode signing for shipped PowerShell artifacts.
- [x] Complete LIVE installer signoff with deterministic telemetry + deterministic operator evidence.
- [ ] Enforce a deterministic **Signing Health Gate** preflight (fail fast if any executed/imported ps1/psm1/psd1 is not `Valid`).
- [ ] Uninstall direction: build canonical uninstall engine with deterministic logs + transcript.

## Scope Boundaries (what we WILL NOT do)
- [ ] No “megadoc” sprint note. Planning stays split by responsibility.
- [ ] No pasted logs/output inside docs (use evidence pointers only).
- [ ] No further installer feature expansion while installer is locked on main (unless regression forces a critical fix).

## Definition of Done (Sprint-level)
- [ ] Signing SOP and tools are stable; signing verifies `Status=Valid` for shipped surfaces.
- [ ] Installer remains deterministic and repeatable (START/NOOP + transcript artifacts).
- [ ] AllSigned failures are prevented by a Signing Health Gate (or fail early with clear evidence).
- [ ] Uninstall has deterministic telemetry and operator evidence (transcript + logs), suitable for regression gating.
