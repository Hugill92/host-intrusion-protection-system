# Test Logs

## 2026-02-09 — V2 Network Support Bundle prototype validation

Environment notes:
- Host currently validating stability; VM validation pending (VMs paused/offline for now).

Validation results (external prototype):
- IP config exporter: captures ipconfig /all (+ compartments), arp -a, netstat -ano, route print, netsh snapshots, and structured Get-Net* JSON (best-effort).
- Network properties exporter: captures adapter/bindings/advanced properties, TCP settings/globals, connection profiles, neighbors; optional TCP/IP registry parameters.
- Observed WARN: some netsh IPv6 route commands may exit non-zero when IPv6 is disabled; acceptable.

Operational note:
- Ensure final V2 orchestrator zips AFTER all sections run so ZIP contains full bundle contents (zip-at-end).

