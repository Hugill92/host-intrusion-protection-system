# Sprint 3 Decisions

**Rule:** durable decisions only. Date entries and keep them concise.

## 2026-02-03 — Hardware-backed script signing (Sprint 3 completion)
- Decision: Ship PowerShell artifacts Authenticode-signed using hardware-backed, non-exportable private key (PIN required).
- Rationale: Prevent key exfiltration; enforce operator-intent signing; align to enterprise distribution expectations.
- Impact: Any patch/edit invalidates signature; re-sign + verify is mandatory before running under AllSigned.
- Evidence: Signature verify tool reports 155/155 Valid in the Sprint note.

## 2026-02-04 — Installer signoff complete; installer locked on main
- Decision: Installer behavior is considered signed-off and locked on main; changes only if regression forces a critical fix.
- Rationale: Reduce churn and preserve determinism while moving focus to uninstall artifacts and regression.
- Impact: New work proceeds under uninstall pipeline + regression gates.

## 2026-02-05 — Locked-in SOP: AllSigned reinstall break requires re-sign workflow
- Decision: Treat reinstall failures under AllSigned as a gate failure; remediation is deterministic re-sign SOP + preflight signing health gate.
- Rationale: AllSigned blocks any NotSigned/HashMismatch dependency; entrypoint signing is insufficient.
- Impact: Add a Signing Health Gate preflight that fails fast and points to first offender.

## (Planning) V2 FeatureSet stance (Windows Features)
- Decision: Default is EnableOnly (no disable during install/update/repair); virtualization/lab stack is opt-in.
- Rationale: Avoid surprise platform posture changes; preserve least-change behavior.
- Impact: FeatureSet requires explicit selection for high-impact features; receipts/EVTX required.

## (Planning) V2 Network Admin Suite stance
- Decision: Network troubleshooting actions are split into AuditOnly vs Enforce; Enforce is admin-only and requires explicit operator intent.
- Rationale: Avoid disruptive changes and surprise toggles; preserve determinism and auditability.
- Impact: Every run produces receipt + EVTX; reset actions must record reboot-required flags.
- Evidence: NetworkAdmin_V2_NetworkingSuiteAndSharing.md
