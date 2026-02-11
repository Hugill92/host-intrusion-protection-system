# Sprint 3 — V2 Optimizer Tier Builder (O&O ShutUp10++ + Winaero Tweaker)

## Outcome
Created a deterministic “Tier Builder” workflow for V2 Optimizer to split **O&O ShutUp10++** and **Winaero Tweaker** configs into Tier 1/2/3 outputs, with a stable allowlist model.

This enables the V2 optimizer to operate in three clear stages:
1) **Inventory + Backup** (capture current state + export originals)
2) **Preview** (show what would change, tier-by-tier)
3) **Apply** (apply selected tier/profile)

## Inputs (Source)
- OOSU: `E:\Drivers\Drivers.Progs\config\ooshutup10.cfg`
- Winaero: `E:\Drivers\Drivers.Progs\config\Winaero Tweaker_2025_12_31.ini`

## Outputs (Tiered)
Output folder:
- `E:\Drivers\Drivers.Progs\config\V2_Tiered\`

Generated files:
- `V2_Tier1_OOSU.cfg`
- `V2_Tier2_OOSU.cfg`
- `V2_Tier3_OOSU.cfg`
- `V2_Tier1_Winaero.ini`
- `V2_Tier2_Winaero.ini`
- `V2_Tier3_Winaero.ini`

## Tier model artifacts
Allowlists:
- Discovery allowlist (all discovered IDs/pages start in Tier3):
  - `E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json`
- Main allowlist (curated):
  - `E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json`
- Backup created during run:
  - `E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.backup_*.json`

Splitter:
- `E:\Drivers\Drivers.Progs\config\Split-V2OptimizerTiers_FIXED.ps1`

## Key fixes / hardening
### OOSU parsing
- OOSU config is **tab-delimited** (e.g., `P001<TAB>+<TAB># comment`), not necessarily `ID=+`.
- Robust parser now:
  - Handles TAB format and whitespace fallback
  - Handles possible BOM marker on first setting line (TrimStart U+FEFF)
  - Produces deterministic outputs even when a tier is empty (header-only cfg is valid)

### Winaero parsing
- Discovers Winaero `page*=` entries under `[User]`
- Conservative default: ship none in Tier1/Tier2 until curated

## Curated tier counts (current)
- OOSU: T1=195, T2=10, T3=21
- Winaero: T1=0, T2=0, T3=76

## Rationale (defaults)
- Tier1 focuses on “safe privacy / noise reduction” toggles (low break risk).
- Tier2 introduces moderate-impact preferences (still avoids support-breaking items).
- Tier3 remains for aggressive or potentially disruptive changes and power-user customization.

## Next steps
1) **Manually curate Winaero Tier2** into a small “normal user” set.
   - Keep “crazy right-click menu explosion” items in Tier3 by default.
2) Add V2 Optimizer Action wiring:
   - Inventory/Backup → Preview → Apply
   - Profile-based opt-in (Tier1/Tier2/Tier3)
3) Add safety gates:
   - Explicit logging + reversible backups
   - Clear warnings for Tier3 actions