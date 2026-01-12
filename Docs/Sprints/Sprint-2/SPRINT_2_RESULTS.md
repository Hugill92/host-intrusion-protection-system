# Sprint 2 Results - Installer/Uninstaller Hardening

## Summary
- Clean Uninstall verified via deterministic log markers + post-action fail-safe checks.
- Installer/uninstaller lifecycle is moving toward repeatable: install -> uninstall -> reinstall.

---

## What passed
- Uninstall completed successfully with start/end markers.
- Scheduled tasks validated removed/missing (installer-owned set).
- No toast listener/runner PowerShell processes remained after uninstall.
- Project-tag firewall rule scan returned no matches post-uninstall.
- Owned paths absent: C:\Firewall and C:\ProgramData\FirewallCore.

---

## What failed (and how it was fixed)
- Symptom: Uninstall appeared to hang / ambiguous “success” signals.
- Fix: enforce deterministic ordering: stop tasks -> stop processes -> remove keys -> reset firewall -> remove owned paths.
- Fix: add post-action verification (tasks/process/rules/profile sanity) to remove ambiguity.

---

## Evidence captured
- Uninstall log + debug log
- Pre/post snapshots in Tools\Snapshots
- Fail-safe verification output (tasks/process/rules/profile)

---

## Next steps (pipeline)
1) Integrate verification checks into the Maintenance UI (admin panel) post-action status.
2) Keep destructive actions admin-only; require typed confirmation for Clean Uninstall.
3) Run full lifecycle loop on at least one VM: install -> verify -> uninstall -> verify -> reinstall.
4) Sprint 3: regression testing across Forced/DEV/Live suites + signing/packaging guardrails.

---

## Maintenance UI note
- Add the post-uninstall verification checks as a status summary section.
- Keep the UI minimal: status panel + install/uninstall/repair + relaunch-as-admin.
