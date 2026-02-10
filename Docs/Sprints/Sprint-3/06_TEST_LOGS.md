# Sprint 3 Test Logs

**Rule:** summarize what was run + verdict + evidence pointers. Do not paste large outputs.

## 2026-02-03 — Signing: batch Authenticode signing + verify
- What ran: batch signing for shipped PowerShell artifacts; signature verification.
- Verdict: PASS (Signed and verified 155/155 scripts as Valid).
- Evidence pointers:
  - Signing tools: `Tools\Release\Sign-FirewallCoreScripts.ps1` and `Tools\Release\Verify-FirewallCoreSignatures.ps1`
  - Signing SOP doc: `Docs\DEV\SIGNING_SOP.md`
  - ProgramData logs/transcripts (as applicable for the run)

## 2026-02-04 — LIVE installer signoff (deterministic START/NOOP + transcript artifacts)
- What ran: LIVE install signoff validation for deterministic telemetry and operator evidence.
- Verdict: PASS (deterministic START/NOOP; transcripts created per run; signatures Valid).
- Evidence pointers:
  - ProgramData logs: `C:\ProgramData\FirewallCore\Logs\`
  - Transcripts: `C:\ProgramData\FirewallCore\Runs\<RunId>\` (or current transcript location)
  - EVTX: FirewallCore log view / filtered view

## 2026-02-05 — AllSigned uninstall→reinstall break (locked-in)
- What ran: uninstall then reinstall under AllSigned.
- Verdict: FAIL (expected gate failure when dependency is NotSigned/HashMismatch; requires re-sign SOP).
- Evidence pointers:
  - First failing module path from console output
  - Signature status from `Get-AuthenticodeSignature`
  - Re-sign stabilizer output + post-fix PASS run pointer
