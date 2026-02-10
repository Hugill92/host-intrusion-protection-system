# Sprint Notes

## Updates


### V2 Optimizer Tier Builder (OOSU + Winaero) — deterministic tier outputs ✅

- Implemented a robust tier-splitter for **O&O ShutUp10++** config + **Winaero Tweaker** INI (tab-delimited OOSU parsing supported).
- Discovery + curation workflow produces deterministic outputs for **Tier1 / Tier2 / Tier3**.
- Outputs are emitted to: E:\Drivers\Drivers.Progs\config\V2_Tiered
  - V2_Tier1_OOSU.cfg, V2_Tier2_OOSU.cfg, V2_Tier3_OOSU.cfg
  - V2_Tier1_Winaero.ini, V2_Tier2_Winaero.ini, V2_Tier3_Winaero.ini
- Tier counts observed on this run:
  - OOSU: **T1=195**, **T2=10**, **T3=21**
  - Winaero: **T1=0**, **T2=0**, **T3=76**
- Recommendation: keep Winaero Tier1/Tier2 empty by default (ship minimal UX changes). If desired later, curate a small Tier2 set; keep Tier3 as opt-in.

### V2 Optimizer Tier Builder (OOSU + Winaero) — deterministic tier outputs ✅

- Implemented a robust tier-splitter for **O&O ShutUp10++** config + **Winaero Tweaker** INI (tab-delimited OOSU parsing supported).
- Discovery + curation workflow produces deterministic outputs for **Tier1 / Tier2 / Tier3**.
- Outputs are emitted to: E:\Drivers\Drivers.Progs\config\V2_Tiered
  - V2_Tier1_OOSU.cfg, V2_Tier2_OOSU.cfg, V2_Tier3_OOSU.cfg
  - V2_Tier1_Winaero.ini, V2_Tier2_Winaero.ini, V2_Tier3_Winaero.ini
- Tier counts observed on this run:
  - OOSU: **T1=195**, **T2=10**, **T3=21**
  - Winaero: **T1=0**, **T2=0**, **T3=76**
- Recommendation: keep Winaero Tier1/Tier2 empty by default (ship minimal UX changes). If desired later, curate a small Tier2 set; keep Tier3 as opt-in.

- [2026-02-10 13:45:38] **V2 Optimizer Tier Builder (OOSU + Winaero)** ✅
  - Inputs:
    - E:\Drivers\Drivers.Progs\config\ooshutup10.cfg (tab-delimited ID<TAB>+/-<TAB># comment)
    - E:\Drivers\Drivers.Progs\config\Winaero Tweaker_2025_12_31.ini
  - Outputs:
    - Tiered configs: E:\Drivers\Drivers.Progs\config\V2_Tiered\
      - V2_Tier1_OOSU.cfg, V2_Tier2_OOSU.cfg, V2_Tier3_OOSU.cfg
      - V2_Tier1_Winaero.ini, V2_Tier2_Winaero.ini, V2_Tier3_Winaero.ini
    - Allowlist:
      - Main: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json
      - Discovery: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json
  - Notes:
    - OOSU discovery count observed: **226 IDs**
    - Winaero discovery count observed: **76 pages**
    - Default stance: keep Winaero Tier1/Tier2 empty unless curated (min UX changes); keep Tier3 as opt-in.

## Updates
- [2026-02-10 13:45:38] **V2 Optimizer Tier Builder (OOSU + Winaero)** ✅
  - Inputs:
    - E:\Drivers\Drivers.Progs\config\ooshutup10.cfg (tab-delimited ID<TAB>+/-<TAB># comment)
    - E:\Drivers\Drivers.Progs\config\Winaero Tweaker_2025_12_31.ini
  - Outputs:
    - Tiered configs: E:\Drivers\Drivers.Progs\config\V2_Tiered\
      - V2_Tier1_OOSU.cfg, V2_Tier2_OOSU.cfg, V2_Tier3_OOSU.cfg
      - V2_Tier1_Winaero.ini, V2_Tier2_Winaero.ini, V2_Tier3_Winaero.ini
    - Allowlist:
      - Main: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json
      - Discovery: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json
  - Notes:
    - OOSU discovery count observed: **226 IDs**
    - Winaero discovery count observed: **76 pages**
    - Default stance: keep Winaero Tier1/Tier2 empty unless curated (min UX changes); keep Tier3 as opt-in.

### 2026-02-10 12:54:54 — V2 Optimizer Tier Builder (OOSU + Winaero) ✅
- Built a robust tier splitter for **O&O ShutUp10++** + **Winaero Tweaker** config artifacts
- OOSU parsing fixed for **tab-delimited** format (ID<TAB>+/-<TAB>comment) and BOM-safe tokenization
- Generated discovery allowlist + curated allowlist + tiered outputs (Tier1/Tier2/Tier3)
- Output artifacts created deterministically (external working folder):
  - Fixed splitter: E:\Drivers\Drivers.Progs\config\Split-V2OptimizerTiers_FIXED.ps1
  - Inputs: E:\Drivers\Drivers.Progs\config\ooshutup10.cfg ; E:\Drivers\Drivers.Progs\config\Winaero Tweaker_2025_12_31.ini
  - Discovery allowlist: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json
  - Curated allowlist:   E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json
  - Tiered outputs folder: E:\Drivers\Drivers.Progs\config\V2_Tiered
- Counts (from run):
  - OOSU IDs: total=226 ; Tier1=195 ; Tier2=10 ; Tier3=21
  - Winaero pages: total=76 ; Tier1=0 ; Tier2=0 ; Tier3=76
- Default posture:
  - OOSU Tier1/2 curated to avoid disruptive changes (updates/driver updates/OneDrive/notifications/NCSI/Defender cloud tradeoffs)
  - Winaero kept conservative (Tier1/Tier2 empty), with Tier3 holding all pages for power-user opt-in
- Next:
  - Manually pick a **small Winaero Tier2** subset (reduce “crazy right-click menus”), keep Tier3 as power-user.
## Updates

# Sprint Notes

## Updates
- [2026-02-10 13:45:38] **V2 Optimizer Tier Builder (OOSU + Winaero)** ✅
  - Inputs:
    - E:\Drivers\Drivers.Progs\config\ooshutup10.cfg (tab-delimited ID<TAB>+/-<TAB># comment)
    - E:\Drivers\Drivers.Progs\config\Winaero Tweaker_2025_12_31.ini
  - Outputs:
    - Tiered configs: E:\Drivers\Drivers.Progs\config\V2_Tiered\
      - V2_Tier1_OOSU.cfg, V2_Tier2_OOSU.cfg, V2_Tier3_OOSU.cfg
      - V2_Tier1_Winaero.ini, V2_Tier2_Winaero.ini, V2_Tier3_Winaero.ini
    - Allowlist:
      - Main: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json
      - Discovery: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json
  - Notes:
    - OOSU discovery count observed: **226 IDs**
    - Winaero discovery count observed: **76 pages**
    - Default stance: keep Winaero Tier1/Tier2 empty unless curated (min UX changes); keep Tier3 as opt-in.

## Updates
- [2026-02-10 13:45:38] **V2 Optimizer Tier Builder (OOSU + Winaero)** ✅
  - Inputs:
    - E:\Drivers\Drivers.Progs\config\ooshutup10.cfg (tab-delimited ID<TAB>+/-<TAB># comment)
    - E:\Drivers\Drivers.Progs\config\Winaero Tweaker_2025_12_31.ini
  - Outputs:
    - Tiered configs: E:\Drivers\Drivers.Progs\config\V2_Tiered\
      - V2_Tier1_OOSU.cfg, V2_Tier2_OOSU.cfg, V2_Tier3_OOSU.cfg
      - V2_Tier1_Winaero.ini, V2_Tier2_Winaero.ini, V2_Tier3_Winaero.ini
    - Allowlist:
      - Main: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json
      - Discovery: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json
  - Notes:
    - OOSU discovery count observed: **226 IDs**
    - Winaero discovery count observed: **76 pages**
    - Default stance: keep Winaero Tier1/Tier2 empty unless curated (min UX changes); keep Tier3 as opt-in.

### 2026-02-10 12:54:54 — V2 Optimizer Tier Builder (OOSU + Winaero) ✅
- Built a robust tier splitter for **O&O ShutUp10++** + **Winaero Tweaker** config artifacts
- OOSU parsing fixed for **tab-delimited** format (ID<TAB>+/-<TAB>comment) and BOM-safe tokenization
- Generated discovery allowlist + curated allowlist + tiered outputs (Tier1/Tier2/Tier3)
- Output artifacts created deterministically (external working folder):
  - Fixed splitter: E:\Drivers\Drivers.Progs\config\Split-V2OptimizerTiers_FIXED.ps1
  - Inputs: E:\Drivers\Drivers.Progs\config\ooshutup10.cfg ; E:\Drivers\Drivers.Progs\config\Winaero Tweaker_2025_12_31.ini
  - Discovery allowlist: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json
  - Curated allowlist:   E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json
  - Tiered outputs folder: E:\Drivers\Drivers.Progs\config\V2_Tiered
- Counts (from run):
  - OOSU IDs: total=226 ; Tier1=195 ; Tier2=10 ; Tier3=21
  - Winaero pages: total=76 ; Tier1=0 ; Tier2=0 ; Tier3=76
- Default posture:
  - OOSU Tier1/2 curated to avoid disruptive changes (updates/driver updates/OneDrive/notifications/NCSI/Defender cloud tradeoffs)
  - Winaero kept conservative (Tier1/Tier2 empty), with Tier3 holding all pages for power-user opt-in
- Next:
  - Manually pick a **small Winaero Tier2** subset (reduce “crazy right-click menus”), keep Tier3 as power-user.
## Updates

### V2 Optimizer Tier Builder (OOSU + Winaero) — 2026-02-10 13:49:21

- Built deterministic tier splitter + allowlist pipeline for **O&O ShutUp10++** (ooshutup10.cfg, tab-delimited ID<TAB>+/-) and **Winaero Tweaker** ([User] page*= keys).
- Generated outputs under external artifact folder:
  - E:\Drivers\Drivers.Progs\config\V2_Tiered\
  - V2_Tier1_OOSU.cfg, V2_Tier2_OOSU.cfg, V2_Tier3_OOSU.cfg
  - V2_Tier1_Winaero.ini, V2_Tier2_Winaero.ini, V2_Tier3_Winaero.ini
- Discovery + curated allowlist artifacts:
  - E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json
  - E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json
  - Backup created (timestamped) on each curation run.
- Default tiering shipped conservative:
  - **OOSU**: Tier1 populated (safe privacy/UX defaults), Tier2 small, Tier3 remainder.
  - **Winaero**: Tier1/Tier2 empty by default (ship minimal UX changes); Tier3 retains all discovered pages for opt-in later.
- Implementation notes:
  - Parser is BOM-safe and handles tab/whitespace variants.
  - Avoided PS7-only operators; designed for PS5.1 compatibility.
# Sprint Notes

## Updates
- [2026-02-10 13:45:38] **V2 Optimizer Tier Builder (OOSU + Winaero)** ✅
  - Inputs:
    - E:\Drivers\Drivers.Progs\config\ooshutup10.cfg (tab-delimited ID<TAB>+/-<TAB># comment)
    - E:\Drivers\Drivers.Progs\config\Winaero Tweaker_2025_12_31.ini
  - Outputs:
    - Tiered configs: E:\Drivers\Drivers.Progs\config\V2_Tiered\
      - V2_Tier1_OOSU.cfg, V2_Tier2_OOSU.cfg, V2_Tier3_OOSU.cfg
      - V2_Tier1_Winaero.ini, V2_Tier2_Winaero.ini, V2_Tier3_Winaero.ini
    - Allowlist:
      - Main: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json
      - Discovery: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json
  - Notes:
    - OOSU discovery count observed: **226 IDs**
    - Winaero discovery count observed: **76 pages**
    - Default stance: keep Winaero Tier1/Tier2 empty unless curated (min UX changes); keep Tier3 as opt-in.

## Updates
- [2026-02-10 13:45:38] **V2 Optimizer Tier Builder (OOSU + Winaero)** ✅
  - Inputs:
    - E:\Drivers\Drivers.Progs\config\ooshutup10.cfg (tab-delimited ID<TAB>+/-<TAB># comment)
    - E:\Drivers\Drivers.Progs\config\Winaero Tweaker_2025_12_31.ini
  - Outputs:
    - Tiered configs: E:\Drivers\Drivers.Progs\config\V2_Tiered\
      - V2_Tier1_OOSU.cfg, V2_Tier2_OOSU.cfg, V2_Tier3_OOSU.cfg
      - V2_Tier1_Winaero.ini, V2_Tier2_Winaero.ini, V2_Tier3_Winaero.ini
    - Allowlist:
      - Main: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json
      - Discovery: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json
  - Notes:
    - OOSU discovery count observed: **226 IDs**
    - Winaero discovery count observed: **76 pages**
    - Default stance: keep Winaero Tier1/Tier2 empty unless curated (min UX changes); keep Tier3 as opt-in.

### 2026-02-10 12:54:54 — V2 Optimizer Tier Builder (OOSU + Winaero) ✅
- Built a robust tier splitter for **O&O ShutUp10++** + **Winaero Tweaker** config artifacts
- OOSU parsing fixed for **tab-delimited** format (ID<TAB>+/-<TAB>comment) and BOM-safe tokenization
- Generated discovery allowlist + curated allowlist + tiered outputs (Tier1/Tier2/Tier3)
- Output artifacts created deterministically (external working folder):
  - Fixed splitter: E:\Drivers\Drivers.Progs\config\Split-V2OptimizerTiers_FIXED.ps1
  - Inputs: E:\Drivers\Drivers.Progs\config\ooshutup10.cfg ; E:\Drivers\Drivers.Progs\config\Winaero Tweaker_2025_12_31.ini
  - Discovery allowlist: E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist_DISCOVERY.json
  - Curated allowlist:   E:\Drivers\Drivers.Progs\config\V2_Optimizer_TierAllowlist.json
  - Tiered outputs folder: E:\Drivers\Drivers.Progs\config\V2_Tiered
- Counts (from run):
  - OOSU IDs: total=226 ; Tier1=195 ; Tier2=10 ; Tier3=21
  - Winaero pages: total=76 ; Tier1=0 ; Tier2=0 ; Tier3=76
- Default posture:
  - OOSU Tier1/2 curated to avoid disruptive changes (updates/driver updates/OneDrive/notifications/NCSI/Defender cloud tradeoffs)
  - Winaero kept conservative (Tier1/Tier2 empty), with Tier3 holding all pages for power-user opt-in
- Next:
  - Manually pick a **small Winaero Tier2** subset (reduce “crazy right-click menus”), keep Tier3 as power-user.
## Updates
