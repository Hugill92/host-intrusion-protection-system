# Sprint 3 — FirewallCorev1 rule ownership tagging (PRE/POST diff + Group tagging)

Date: 2026-02-10 01:53:14

## Summary
- Captured PRE (WinDefault) and POST (FirewallCore v1 applied) snapshots from PersistentStore.
- Computed Added + Modified rule set from PRE→POST diff (manifest size: 343).
- Applied Group tag: FirewallCorev1 (v1 “owned/managed” marker) to the Added + Modified set.
- Key fix: Set-NetFirewallRule cannot "set Group" using -Group while selecting by -Name (parameter set conflict).
  Working method: mutate Group property and pipe:
  - `$rule.Group = 'FirewallCorev1'; $rule | Set-NetFirewallRule`

## Evidence
Baseline folder: C:\ProgramData\FirewallCore\Baselines\BASELINE_20260210_011159
Key artifacts:
- PRE_Default.json
- POST_FirewallCorev1.json
- TAG_Manifest_AddedPlusModified.json
- TAG_Plan_AddedPlusModified.csv
- TAG_Backup_OriginalGroups_*.json (rollback map)
- UNTAG_Inbound_AppRules_* (optional cleanup of per-machine app rules)

## Operational notes
- Tagging must be performed while the POST policy is applied; otherwise some rule names may be missing.
- Rollback is deterministic: restore each rule’s Group to OldGroup from TAG_Backup_OriginalGroups*.json.
- Optional hygiene: remove v1 tag from inbound per-machine app rules (Store apps / user-installed apps) to keep v1 ownership deterministic across machines.
