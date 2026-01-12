## Documentation Index
- Docs/ARCHITECTURE.md — invariants + core system theory
- Docs/ROADMAP.md — implementation plan and sequencing
- Docs/ERRORS.md — exit code conventions and failure logging
- SECURITY_NOTES.md — artifact hygiene + baselining notes
# HIPS Project Context

- Official name: Host Intrusion Protection System (HIPS)
- Root orchestrator: FirewallInstaller
- Current focus: Notifier correctness (Info tray, Warn/Critical popup, click-to-EventViewer, correct sounds)
- Constraints: minimal diffs, no broad refactors, never commit runtime artifacts (State/Logs/Snapshots)
- See AGENTS.md for hard rules

