# Host Intrusion Protection System (HIPS)

**Official project name:** Host Intrusion Protection System (HIPS)  
**GitHub repo slug (recommended):** `host-intrusion-protection-system` (or `HIPS`)  
**Primary module/entrypoint:** `FirewallInstaller` (installer + orchestration + suites)

A Windows PowerShell-based host intrusion protection system focused on:
- firewall policy enforcement (FirewallCore)
- monitoring + alerting + notifications (Firewall Monitor)
- install/uninstall orchestration (FirewallInstaller)
- DEV / Forced / Pentest / Regression test suites

## Support / Donations

If you find HIPS useful, you can support development via donations:

- PayPal: (link in the GitHub Sponsor button  see `.github/FUNDING.yml`)

Future versions may offer optional paid convenience packages (installer bundles) and/or paid support, while keeping the core project open.

## Repo guardrails

- `AGENTS.md` defines non-negotiable automation rules and the notifier contract.
- `.gitignore` prevents committing runtime state, logs, snapshots, and per-machine baselines.

## License

Apache License 2.0 (see `LICENSE`).
