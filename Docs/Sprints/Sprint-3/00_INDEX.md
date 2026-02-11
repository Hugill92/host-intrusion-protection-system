# Sprint 3 Index

**Rule:** Sprint 3 is the active planning hub. Use **small docs** with clear responsibility. No megadocs.  
**Rule:** Docs never contain pasted logs. Use **evidence pointers** only.

## Navigation
- [Goals and Scope](01_GOALS_AND_SCOPE.md)
- [Work Breakdown](02_WORKBREAKDOWN.md)
- [Acceptance Gates](03_ACCEPTANCE_GATES.md)
- [Risks and Triage](04_RISKS_AND_TRIAGE.md)
- [Decisions](05_DECISIONS.md)
- [Test Logs](06_TEST_LOGS.md)
- [Backlog](07_BACKLOG.md)
- [V2 FeatureSet: Windows Features](FeatureSet_V2_WindowsFeatures.md)
- [V2 Network Admin: Networking Suite + Sharing/Profile](NetworkAdmin_V2_NetworkingSuiteAndSharing.md)
- [V2 Threat Surface: Port Watch + Kernel Telemetry](ThreatSurface_V2_PortWatchAndKernelTelemetry.md)

## Current Status (keep ~10 lines)
- ✅ LIVE installer signoff complete: deterministic START/NOOP events + transcript artifacts per run.
- 🔒 Installer now locked on `main` (no further changes unless regression forces a critical fix).
- ✅ Hardware-backed Authenticode signing finalized; verify `Status=Valid` end-to-end.
- ⚠️ Known locked-in issue: uninstall → reinstall can break under AllSigned if any imported module is NotSigned/HashMismatch; re-sign SOP is required and a **Signing Health Gate** must exist.
- Next direction: build canonical uninstall engine + deterministic uninstall logs/transcripts; keep signing gates as mandatory.
- Next V2 planning: Network Admin Suite (IPConfig/NetStack + profile/sharing + privacy posture).

## Evidence Pointers (no pasted logs)
- ProgramData logs: `C:\ProgramData\FirewallCore\Logs\`
- Transcripts: `C:\ProgramData\FirewallCore\Runs\<RunId>\` (or current run transcript location)
- Baselines: `C:\ProgramData\FirewallCore\Baselines\`
- Diagnostics bundles: `C:\ProgramData\FirewallCore\Diagnostics\`
- Event Viewer: dedicated FirewallCore / FirewallCore providers log (filtered views as applicable)




