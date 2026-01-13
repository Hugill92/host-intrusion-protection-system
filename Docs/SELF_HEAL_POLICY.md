# Self-heal policy (FirewallCore)

## Goal
Self-heal restores firewall configuration back to the current known-good policy set.

## Source of truth
The current known-good policy set is represented by an authoritative policy artifact (e.g., a .wfw file) stored/packaged with the project.

## Drift detection
Drift is detected by comparing a normalized snapshot of effective firewall state (profiles + selected rule fields, sorted deterministically) against a stored baseline.

## Remediation
When drift is detected:
1) Re-apply the authoritative policy artifact.
2) Re-capture the normalized snapshot.
3) Verify the machine state matches baseline expectations.

## Evidence
Each remediation should log:
- Which baseline/tag is targeted
- Policy artifact hash used
- Post-remediation snapshot hash
- A small diff summary if remediation fails
