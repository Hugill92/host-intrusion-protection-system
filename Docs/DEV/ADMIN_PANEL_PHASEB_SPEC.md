# FirewallCore Admin Panel – Phase B Spec (Sprint 3)

## Purpose
Phase B implements a stable operator UI with:
- A deterministic checklist grid
- Unified Actions area (Repair + System actions)
- Unified Admin Tests area (Safe tests + gated Lab simulations)
- Evidence paths surfaced in the UI
- Logging for all actions and outputs

This spec defines UI contracts, data model expectations, and acceptance criteria.

---

## Layout Requirements

### A) System Checklist Grid (Top)
**Must render first and remain stable during refresh.**

**DataGrid columns (left → right)**
1. Check
2. Status
3. Details (word-wrap, multi-line)
4. Suggested Action (narrower)
5. Help (narrower)
6. Evidence / Path (word-wrap)

**Behavior**
- Columns resizable
- Details is the primary narrative column
- Evidence/Path must show output file locations for report-producing actions

**Row sizing**
- Multi-line rows enabled
- Minimum of 2–3 lines visible in Details without truncation

**Word-wrap**
- Use TextBlock wrapping for Details and Evidence/Path
- Vertical alignment top for multi-line readability
- Avoid horizontal scroll where possible

---

### B) Actions Area (Unified: Repair + System Actions)
Combine Repair Options and System Actions into one operator area.

**Refresh controls**
- Refresh interval dropdown
- Auto-refresh checkbox
- Re-apply policy checkbox (same row as refresh interval/auto-refresh)
- Refresh Now button (manual refresh; remove/avoid refresh inside dropdowns)

**Repair options**
- Restart notifications
- Archive queue
- (optional) Re-apply policy (explicitly selected)
- Apply Selected button
- Reset Defaults button

**System actions**
- Action dropdown (Install/Repair/Maintenance/Uninstall/Clean Uninstall)
- Run Action button

**Close button placement**
- Must not sit centered mid-panel
- Place top-right or bottom-right (right-aligned) consistently

---

### C) Admin Tests Area (Unified: Safe + Lab Simulations)
Combine Safe tests and Dev Mode lab simulations into one box to reduce vertical space usage.

**Safe test selector + Run button**
- Quick Health Check
- Notification Demo
- Baseline Drift Check
- Inbound Allow Risk Report
- Rules Report
- Export Diagnostics Bundle

**Dev Mode (Lab simulations)**
- Dev Mode checkbox triggers unlock prompt dialog
- When locked: disable lab action dropdown + run button
- When unlocked: enable lab actions list
- Lab simulations should generate Event Log evidence and user alert notifications (pop-ups) by default so the operator can observe behavior.

---

## Dev Mode Unlock Contract (Time-limited Secure Unlock)

### Why time-limited unlock
Time-limited unlock reduces standing privilege:
- Safe mode is default
- Dev tools enable only intentionally
- Dev tools re-lock automatically

### UI behavior
When operator enables Dev Mode:
1. Show modal unlock prompt
2. If unlock valid:
   - DevMode = true
   - DevUnlockExpiresAt set (example: 10 minutes)
   - Enable lab action controls
3. If invalid:
   - DevMode remains false
   - Revert checkbox
   - Log failed attempt (do not log secrets)

### Default unlock secret
- `admin` (lowercase)

### First-run password setup
On first run (or first Dev Mode use), allow installer/admin to set the Dev unlock secret:
- Prompt to set a secret if none exists
- Store the secret securely (admin-only ACL)
- Provide an admin-only reset workflow

Design must preserve a future hardware-backed unlock path using the same UX contract.

---

## Data Model

### Checklist row object
Minimum fields:
- Check (string)
- Status (PASS/WARN/FAIL)
- Details (string)
- SuggestedAction (string)
- Help (string)
- EvidencePath (string)

---

## Output Locations (Standard)
- Logs:
  - C:\ProgramData\FirewallCore\Logs\AdminPanel-Actions.log
- Reports:
  - C:\ProgramData\FirewallCore\Reports\
- Diagnostics:
  - C:\ProgramData\FirewallCore\Diagnostics\

---

## Refresh Status Line
A status text line under the title must reflect refresh lifecycle:
- Refreshing…
- Refresh complete: <timestamp>
- Refresh failed: <reason> (see logs)

Implementation requirement:
- UI updates must run on the UI thread (Dispatcher).

---

## Action Wiring Contract

### One button → one function → one log entry
Every action must:
- Log Start
- Execute
- Log OK/FAIL
- For report actions: capture output path and surface it in Evidence/Path and logs

---

## Rules Report
Rules Report must:
- Generate output under Reports\
- Surface the exact output path in Evidence/Path
- Log success/failure in AdminPanel-Actions.log
- Avoid silent failures

---

## Acceptance Criteria

### UI/UX
- Details wraps and shows 2–3 lines minimum per row
- Suggested Action and Help columns are narrower
- Evidence/Path column exists and shows real output locations
- Auto-refresh and Re-apply policy are on the same row as Refresh interval
- Refresh Now exists as a dedicated button (not hidden inside dropdown flows)
- Actions area unifies Repair + System actions cleanly
- Tests area unifies Safe tests + gated Dev Mode
- Close button placed top-right or bottom-right

### Functional
- Refresh updates status line deterministically
- Rules Report works and surfaces output path
- Safe tests remain functional
- Dev Mode unlock gating works and is time-limited
- Lab simulations generate Event Log evidence and user alert notifications (pop-ups)
