# FirewallCore — Uninstall Verification Ledger (Admin Panel Ready)

## Goal
Provide a deterministic, line-by-line verification checklist after Standard Uninstall or Clean Uninstall.

Each check row reports:
- Status: PASS / WARN / FAIL
- Evidence: counts, names, paths, timestamps
- Single remediation action (if applicable)

## Verification phases

### Phase A — Runtime components
1. Listener process not running
   - PASS: no listener process
   - WARN: running (offer Stop action)
2. Services not present (if any)
3. Scheduled tasks removed
   - FirewallCore*
   - Firewall-Defender-Integration

### Phase B — Filesystem state
4. Live payload
   - PASS: C:\Firewall absent
5. ProgramData handling
   - Standard Uninstall: PASS if logs/baselines remain per policy
   - Clean Uninstall: PASS if C:\ProgramData\FirewallCore absent
6. Queue folders (NotifyQueue)
   - Standard: may remain archived
   - Clean: must be removed

### Phase C — Firewall state
7. FirewallCore rule groups absent
   - PASS: no rules with Group FirewallCorev1/v2/v3
8. Optional drift summary
   - Compare against PRE baseline when available
   - WARN only; do not treat as uninstall failure unless FirewallCore-owned rules remain

### Phase D — Event logs
9. FirewallCore log channel state
   - Standard: may remain
   - Clean: may be removed if contract specifies
10. Uninstall completion record exists
   - PASS: “UNINSTALL OK” or “CLEAN UNINSTALL OK” within recent timeframe
   - Evidence includes correlation/TestId when available

### Phase E — Reinstall readiness
11. Reinstall readiness gate
   - No conflicting tasks
   - No FirewallCore rule groups
   - Required directories writable
   - PASS: Ready to reinstall

## Evidence fields (recommended)
- Timestamp
- Mode (Standard/Clean)
- Correlation/TestId
- Task list results
- Rule group counts (FirewallCorev1/v2/v3)
- Key paths present/absent
- Event log last uninstall event summary
