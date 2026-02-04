# Sprint 3 — Hardware-backed Script Signing

## Summary
- Implemented batch Authenticode signing for shipped PowerShell artifacts using a hardware-backed, non-exportable private key (PIN required).
- Certificates can be imported into Windows stores, but signing requires physical token presence.

## Results
- Date: 2026-02-03 02:34:13
- Signed and verified: 155/155 scripts (Valid).

## Deliverables
- Tools\Release\Sign-FirewallCoreScripts.ps1
- Tools\Release\Verify-FirewallCoreSignatures.ps1
- Docs\DEV\SIGNING_SOP.md

## Scope
- Repo root installer scripts
- Firewall\
- Tools\
- Tests\

## Exclusions
- Docs\_local\, Docs\_archive
- .git\, .vs\, bin\, obj\, node_modules
- backup patterns (*.bak*, *.old*, *.disabled*, *~)

## Determinism Notes
- Empty scripts (<4 bytes) must contain a stub comment to be signable.
- If signatures do not persist, normalize encoding to UTF-8 and re-sign.
## Sprint 3 — Installer Signoff
- LIVE install signoff complete:
  - Deterministic INSTALL START / INSTALL NOOP events
  - Transcript artifacts produced per run
  - Authenticode signatures verify as Valid
- Installer is locked on main; future work proceeds under uninstall artifacts.

