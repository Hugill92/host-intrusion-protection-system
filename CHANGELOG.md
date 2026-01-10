# Changelog

This project follows tag-based releases. See `VERSIONING.md`.

## [v1.0] - Baseline release

### What this is
- Initial public baseline of **Host Intrusion Protection System (HIPS)**.
- Repository source-of-truth is the `FirewallInstaller` root orchestrator (installer + suites).

### Included
- Installer/orchestration scaffolding
- DEV / Forced / Pentest / Regression suite layout
- Core scripts/modules for firewall enforcement + monitoring
- Guardrails to prevent committing runtime artifacts (logs/state/snapshots/baselines)

### Known limitations / not yet
- Some features and polish items may still be under active iteration (e.g., notifier UX edge-cases).
- Packaging/distribution format may evolve (e.g., MSI / signed bundle).

### Upgrade notes
- Treat v1.0 as the baseline tag. New tags will identify stable checkpoints.
