# Decisions

## 2026-02-09 — V2 Network Support Bundle prototype (milestone)

- Completed a validated external prototype for V2 diagnostics: “Network Support Bundle”.
- Split into discrete exporters:
  - IP config evidence (ipconfig/route/arp/netstat/netsh + best-effort Get-Net* JSON).
  - Network properties evidence (adapter/bindings/advanced props/TCP globals/profiles; optional TCP/IP registry parameters).
  - Windows Features/Capabilities capture is planned/pending full validation; will be finalized after VM test pass.
- Fixed a real PowerShell native-call argument issue:
  - `Invoke-NativeToFile` used `$Args` (collides with automatic `$args`) → native tools ran without intended args.
  - Now uses `$ArgumentList` with `-Args` alias + logs native exit codes.
- IPv6 disabled: netsh IPv6 route queries may exit non-zero; treat as WARN (non-blocker).
- Prototype kept outside package/repo deployment path for clean versioning; will be wired into V2 runtime later (AllSigned + ProgramData deploy).

