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

