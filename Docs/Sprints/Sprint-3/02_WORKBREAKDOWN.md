# Sprint 3 Work Breakdown

**Format:** each work item includes: Owner, Status, Evidence pointer, Risks.

## Install / Update / Repair
- [x] LIVE installer signoff: deterministic START/NOOP + operator transcripts
  - Owner: Hugh
  - Status: Done (locked on main)
  - Evidence: ProgramData logs + transcript artifacts per run
  - Risks: Regression may force narrow critical fix only

- [x] Deploy full Firewall runtime root during install (mirror full runtime deterministically)
  - Owner: Hugh
  - Status: Done
  - Evidence: C:\Firewall tree exists post-install; install logs show deploy step
  - Risks: Partial tree regressions if staging logic changes

## Signing (Sprint 3 completion item; locked with installer)
- [x] Batch Authenticode signing for shipped PowerShell artifacts (hardware-backed private key; PIN required)
  - Owner: Hugh
  - Status: Done
  - Evidence: Verify tool results show Status=Valid (155/155 at time of note)
  - Risks: Any patch/edit invalidates Authenticode; requires re-sign + verify before retest

- [ ] Implement mandatory **Signing Health Gate** preflight (fail fast)
  - Owner: Hugh
  - Status: Planned
  - Evidence: Gate output recorded in logs; block run under AllSigned if any dependency not Valid
  - Risks: Missing coverage leads to reinstall breaks under AllSigned

## Uninstall (Next direction)
- [ ] Canonical uninstall engine (removes tasks, restores baseline policy, removes ProgramData + event log as per contract)
  - Owner: Hugh
  - Status: Planned
  - Evidence: Deterministic uninstall logs + transcript + EVTX
  - Risks: Legacy task/rule cleanup gaps; evidence loss if logs are deleted too early

## V2 FeatureSet: Windows Features (planning only in Sprint 3)
- [ ] Define manifest-driven “FeatureSet” convergence model for optional Windows features on Install/Update/Repair
  - Owner: Hugh
  - Status: Planned
  - Evidence: FeatureSet doc + acceptance gates + receipts/EVTX defined
  - Risks: Surprise toggles; edition incompatibility; reboot-required handling

## V2 Network Admin (Networking Suite + Profile/Sharing)
- [ ] Implement Network Report (AuditOnly) + receipts + EVTX
  - Owner:
  - Status: Planned
  - Evidence:
  - Risks: data collection drift, missing fields on certain adapters/OS builds

- [ ] Implement targeted repair actions (Enforce; admin-only)
  - Owner:
  - Status: Planned
  - Evidence:
  - Risks: disruptive actions; require explicit operator intent + reboot flags

- [ ] Implement profile/sharing converge (Public-safe defaults; Private optional)
  - Owner:
  - Status: Planned
  - Evidence:
  - Risks: accidental exposure if profile boundary not enforced

## V2 Threat Surface (Port Watch + Kernel/Near-Kernel Telemetry)
- [ ] Define signed/hashed Watchlist manifest schema + default policy buckets (Public-safe)
  - Status: Planned
- [ ] Implement AuditOnly exposure report + receipt + EVTX
  - Status: Planned
- [ ] Implement Enforce rule generation under Group `FirewallCorev2`
  - Status: Planned
- [ ] Implement tiered telemetry (Tier 1/2 baseline; Tier 3 support-mode)
  - Status: Planned
