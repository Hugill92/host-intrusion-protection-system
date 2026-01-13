# Baseline capture tooling

## Purpose
Captures firewall policy exports and a normalized snapshot for stable drift comparisons.

## Output
C:\FirewallInstaller\Tools\Baselines\<COMPUTER>-<TAG>-<timestamp>\

## Included artifacts
- FirewallPolicy.wfw
- FirewallPolicy.reg
- FirewallSnapshot.normalized.json
- SHA-256 hashes for .wfw and snapshot JSON
- README.txt metadata

## Recommended usage
Capture at key lifecycle points:
- DEFAULT (fresh/default state)
- UPDATED-POLICY (after applying clean ruleset)
- POST-REPAIR
- PRE-UNINSTALL / POST-UNINSTALL (if needed)
