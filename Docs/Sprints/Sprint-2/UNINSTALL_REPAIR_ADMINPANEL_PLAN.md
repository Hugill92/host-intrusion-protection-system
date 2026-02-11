# Sprint 2 — Uninstall / Repair / Admin Panel Plan

## Scope
- Uninstall: two modes
  - Uninstall (reinstall later)
  - Clean uninstall (requires typing DELETE; admin-only)
- Repair / Self-heal: re-register tasks, enable tasks, optional policy re-apply, optional toast restart, optional queue archive
- Admin Panel: checklist UI + buttons (Install / Uninstall / Repair / Maintenance Mode)

## Entry points
- `Install.cmd` (already signed off)
- `Uninstall.cmd` (existing)
- `Uninstall-Clean.cmd` (new)
- `Repair.cmd` (new)
- `C:\Firewall\User\FirewallAdminPanel.ps1` (new UI)

## Acceptance (Sprint 2)
- Uninstall mode works and leaves system ready for later reinstall
- Clean uninstall requires explicit DELETE and removes ProgramData + cert cleanup attempt
- Repair restores tasks + stabilizes runtime; produces repair transcript under C:\Firewall\Logs\Repair
- Admin panel displays checklist PASS/WARN/FAIL and can launch actions

