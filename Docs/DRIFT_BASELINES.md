# Drift baselines (FirewallCore)

## Baseline storage location
Baselines are captured under:

C:\FirewallInstaller\Tools\Baselines\<COMPUTERNAME>-<TAG>-<yyyyMMdd-HHmmss>\

Each capture folder contains:
- FirewallPolicy.wfw (raw firewall policy export)
- FirewallPolicy.reg (registry export of firewall policy hive)
- FirewallSnapshot.normalized.json (normalized snapshot for stable comparisons)
- HASH.FirewallPolicy.wfw.sha256.txt (SHA-256 of the .wfw)
- HASH.Snapshot.normalized.sha256.txt (SHA-256 of the normalized snapshot JSON)
- README.txt (tag/note metadata)

## Two-hash model
This project supports two complementary hashes:

1) Policy artifact hash (authoritative intent)
- Hash the policy artifact used as the source of truth (e.g., FirewallPolicy.wfw).
- Used to validate the intended policy payload.

2) Effective state hash (drift detection)
- Hash the normalized snapshot (FirewallSnapshot.normalized.json).
- Used to detect unexpected state changes (drift/tamper) in a stable way.

## Self-heal remediation
On drift detection, remediation restores the machine by re-applying the authoritative policy artifact (e.g., import the .wfw), then capturing a new normalized snapshot and verifying hashes.

## Naming / tags
Recommended tags:
- DEFAULT (machine default baseline)
- UPDATED-POLICY (post-policy application baseline)
- POST-REPAIR, POST-UNINSTALL, etc (as needed)

Tags should remain short and consistent.

## Comparison workflow
Compare:
- HASH.Snapshot.normalized.sha256.txt (fast equality check)
- Compare-Object of Rules arrays (for specific diffs)
- Optionally compare .wfw hashes (policy payload equality)
