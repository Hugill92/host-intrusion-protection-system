# Sprint 4 — Secure Token + Maintenance Gating

This sprint introduces a short-lived **Secure Token** that gates privileged actions (Maintenance Mode) with deterministic receipts and EVTX.

## Documents
- [Secure Token v1 Spec](SecureToken_V1_Spec.md)
- [Secure Token v1 Scopes](SecureToken_V1_Scopes.md)
- [Secure Token v1 Storage + ACL](SecureToken_V1_StorageAndACL.md)
- [Secure Token v1 Admin Panel UX](SecureToken_V1_AdminPanelUX.md)
- [Secure Token Phase A/B Implementation Plan](SecureToken_PhaseA_PhaseB_ImplementationPlan.md)

## Sprint intent
- Implement Phase A (fast + strong) first, then Phase B (hardware-backed) with the signed helper.
- Keep PowerShell thin orchestration; move sensitive crypto into signed helper when ready.
