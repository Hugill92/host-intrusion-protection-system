# FirewallCore — EVTX Event ID Continuity Contract

## Goal
Ensure installer and uninstaller Event Log entries are easy to correlate and do not “jump” or fragment.

## Requirements
1. Single log channel:
   - LogName: FirewallCore
2. Stable event sources:
   - FirewallCore-Installer (preferred single source)
   - Optionally FirewallCore-Uninstaller (allowed, but keep consistent)
3. Monotonic, non-jumping Event IDs:
   - IDs increase in small increments
   - Avoid large jumps that break operator mental mapping
   - Avoid reusing IDs for different meanings
4. Shared numeric space:
   - Install and Uninstall use the same ID range strategy
   - Do not reset numbering between phases

## Suggested ID bands (example)
- 1000–1099: Install START/OK/FAIL + major steps
- 1100–1199: Uninstall START/OK/FAIL + major steps
- 1200–1299: Clean Uninstall START/OK/FAIL + major steps
- 1300–1399: Verification / audit summaries

## Required events
- Install START, Install OK/FAIL
- Uninstall START, Uninstall OK/FAIL
- Clean Uninstall START, Clean Uninstall OK/FAIL
- Optional: step PASS/WARN/FAIL events with correlation/TestId

## Notes
- Event log should never be the sole evidence sink; file logs must mirror outcomes.
- Logging failures must not abort uninstall; emit WARN and continue.






********************************************************************
Base Offset: 1000 (or whatever you choose)

Example:

Base Offset: 1000 (all ranges below assume this base; if project base changes, shift all ranges by the same delta)

That way when you later decide “tests start at 1800/1900,” you can just assign those blocks cleanly without debate.


Event ID Allocation Model (50-ID Blocks)
Rules

Each functional area gets its own 50-ID block.

Within a block:

Reserve low IDs for lifecycle “Started/Completed/No-Op/Failed”

Reserve mid IDs for step-level milestones

Reserve high IDs for error variants and edge cases

Never reuse an EventId once published.

Do not renumber—if a block fills, allocate a new block and link it.

Master Map (50-ID blocks)

Pick a base you like (e.g., starting at 1000). Below assumes 1000+ for clarity. If you already have IDs in use, shift the whole table to your existing base and keep the 50-step pattern.

Core lifecycle (Install / Repair / Uninstall)
Block	Range	Purpose
20	1000–1049	Install lifecycle (start/stop/no-op + major phases)
21	1050–1099	Repair lifecycle
22	1100–1149	Uninstall lifecycle
23	1150–1199	Rollback / Recovery lifecycle
Logging / Observability / Evidence
Block	Range	Purpose
24	1200–1249	Event log provisioning (create log, provider registration, ACLs)
25	1250–1299	File logging + evidence paths (log folder, bundle paths, rotation)
26	1300–1349	Diagnostics bundle export (bundle start/finish, zip integrity)
27	1350–1399	Baseline export + SHA256 (PRE/POST capture, hashing)
Scheduled tasks / services / runtime wiring
Block	Range	Purpose
28	1400–1449	Scheduled tasks create/update
29	1450–1499	Scheduled tasks runtime (start/stop health, watchdog behavior)
30	1500–1549	Runtime components (listeners/handlers registration/wiring)
Firewall policy / rules (do not touch policy artifacts; logging only)
Block	Range	Purpose
31	1550–1599	Firewall rule inventory / counts / drift
32	1600–1649	Inbound Allow Risk Report (risk findings + export results)
Notification pipeline (user alerts engine)
Block	Range	Purpose
33	1650–1659 → lifecycle (started/completed/no-op/failed)
	1660–1669 → Info events
	1670–1679 → Warning events
	1680–1689 → Critical events
	1690–1699 → errors/edge cases
34	1700–1749	Notification demo tests (Info/Warn/Critical)
Admin Panel actions
Block	Range	Purpose
35	1750–1799	Admin Panel actions (maintenance) (repair/export/uninstall triggers)
36	1800–1849	Admin Panel gating (admin check, maintenance unlock, dev/lab gates)
Security hardening / signing / integrity
Bock	Range	Purpose
37	1850–1899	Authenticode / signing integrity gates
38	1900–1949	Trust store / cert presence (publisher/root checks)
Reserved for future
Block	Range	Purpose
39	1950–1999	Reserved (future v1 additions)
40	2000–2049	Reserved (future v2 additions)

## Event ID allocation model (50-ID blocks)

**Base offset:** `1000`  
All ranges below assume this base. If the project base changes, shift all ranges by the same delta.

### Rules

- Each functional area gets its own **50-ID block**.
- Within a block:
  - Reserve **low IDs** for lifecycle: `Started` / `Completed` / `No-Op` / `Failed`
  - Reserve **mid IDs** for step-level milestones
  - Reserve **high IDs** for error variants and edge cases
- Never reuse an **EventId** once published.
- Do not renumber—if a block fills, allocate a new block and link it.

### Master map (50-ID blocks)

> If you already have IDs in use, shift the whole table to your existing base and keep the 50-step pattern.

#### Core lifecycle (Install / Repair / Uninstall)

| Block | Range | Purpose |
|---:|---|---|
| 20 | 1000–1049 | Install lifecycle (start/stop/No-Op + major phases) |
| 21 | 1050–1099 | Repair lifecycle |
| 22 | 1100–1149 | Uninstall lifecycle |
| 23 | 1150–1199 | Rollback / Recovery lifecycle |

#### Logging / Observability / Evidence

| Block | Range | Purpose |
|---:|---|---|
| 24 | 1200–1249 | Event log provisioning (create log, provider registration, ACLs) |
| 25 | 1250–1299 | File logging + evidence paths (log folder, bundle paths, rotation) |
| 26 | 1300–1349 | Diagnostics bundle export (bundle start/finish, zip integrity) |
| 27 | 1350–1399 | Baseline export + SHA256 (PRE/POST capture, hashing) |

#### Scheduled tasks / services / runtime wiring

| Block | Range | Purpose |
|---:|---|---|
| 28 | 1400–1449 | Scheduled tasks create/update |
| 29 | 1450–1499 | Scheduled tasks runtime (start/stop health, watchdog behavior) |
| 30 | 1500–1549 | Runtime components (listeners/handlers registration/wiring) |

#### Firewall policy / rules (logging only)

| Block | Range | Purpose |
|---:|---|---|
| 31 | 1550–1599 | Firewall rule inventory / counts / drift |
| 32 | 1600–1649 | Inbound Allow Risk Report (risk findings + export results) |

#### Notification pipeline (user alerts engine)

| Block | Range | Purpose |
|---:|---|---|
| 33 | 1650–1699 | Notification engine (Action-first) — lifecycle, actions, health, errors |
| 34 | 1700–1749 | Notification demo tests (Action-first) — demo lifecycle, cases, verification |

**Block 33 (1650–1699) breakdown:**
- 1650–1659 → lifecycle (Started / Completed / No-Op / Failed)
- 1660–1679 → pipeline actions (Queue / Dispatch / Handler / Listener / Dialog / Toast)
- 1680–1689 → validation / health (queue counts, listener running, permissions, wiring)
- 1690–1699 → errors / edge cases (handler failures, launch contract violations, timeouts)

**Block 34 (1700–1749) breakdown:**
- 1700–1709 → demo run lifecycle (Started / Completed / No-Op / Failed)
- 1710–1739 → demo case actions (Info / Warning / Critical)
- 1740–1749 → demo errors / verification failures

#### Admin Panel actions

| Block | Range | Purpose |
|---:|---|---|
| 35 | 1750–1799 | Admin Panel actions (maintenance) (repair/export/uninstall triggers) |
| 36 | 1800–1849 | Admin Panel gating (admin check, maintenance unlock, dev/lab gates) |

#### Security hardening / signing / integrity

| Block | Range | Purpose |
|---:|---|---|
| 37 | 1850–1899 | Authenticode / signing integrity gates |
| 38 | 1900–1949 | Trust store / cert presence (publisher/root checks) |

#### Reserved for future

| Block | Range | Purpose |
|---:|---|---|
| 39 | 1950–1999 | Reserved (future v1 additions) |
| 40 | 2000–2049 | Reserved (future v2 additions) |

