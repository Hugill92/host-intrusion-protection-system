# PR TASKING: Admin Panel Phase B – Layout Polish + Deterministic Wiring

## Source of Truth
- Follow: `Docs/DEV/ADMIN_PANEL_PHASEB_SPEC.md` (authoritative contract).

## Goals
1) Improve Admin Panel layout + spacing for usability (no functional regressions).
2) Ensure checklist grid is readable (word-wrap, multi-line, evidence paths).
3) Make refresh behavior deterministic and obvious.
4) Keep operator actions/logging deterministic: one click → one function → one logged outcome.
5) Implement Dev Mode as time-limited Secure Unlock (password today, hardware later).

## Non-Goals
- Do NOT redesign the product or change core behavior beyond what’s specified.
- Do NOT remove working features.
- Do NOT add external dependencies.
- Do NOT introduce PS7-only syntax; must remain compatible with Windows PowerShell 5.1.
- Do NOT mention AI/tooling in repo docs.

---

## Acceptance Criteria (Hard Gates)
### UI/UX
- Checklist grid:
  - **Details** column word-wrap enabled and shows **2–3 lines minimum** without truncation.
  - **Evidence/Path** column exists and word-wrap enabled.
  - Suggested Action + Help columns are narrower than current.
  - Columns remain resizable.
- Layout merges:
  - Merge **Repair Options + System Actions** into a single “Actions” box.
  - Merge **Safe Tests + Dev Mode Lab Simulations** into a single “Admin Tests” box.
- Refresh:
  - Add a dedicated **Refresh Now** button near refresh controls.
  - Remove/avoid “Refresh” inside dropdown flows (if present).
  - Status line must reliably update to “Refreshing…” then “Refresh complete: <timestamp>”.
- Close button:
  - Must be **top-right** or **bottom-right** (not centered mid-page).
- Dev Mode:
  - Enabling Dev Mode triggers unlock prompt.
  - Unlock is **time-limited** (example 10 minutes) and auto-relocks.

### Functional
- Working actions must remain working:
  - Apply Selected, Reset Defaults, Install, Repair, Maintenance, Uninstall, Clean Uninstall
  - Quick Health Check, Notification Demo, Baseline Drift Check, Inbound Allow Risk Report, Export Diagnostics Bundle
- Rules Report must be deterministic:
  - Always outputs a report file under `C:\ProgramData\FirewallCore\Reports\`
  - Evidence/Path column shows the exact output file path
  - Action result logged (OK/FAIL) in `AdminPanel-Actions.log`
- Lab simulations:
  - Must generate Event Log evidence.
  - Must generate **user alert pop-ups** by default (operator-visible validation).

---

## Implementation Checklist (Do in This Order)

### 1) Checklist Grid improvements (XAML)
- Set `MinRowHeight` and `RowHeight="Auto"`.
- Enable word-wrap for Details and Evidence/Path.
- Confirm columns:
  - Check | Status | Details | Suggested Action | Help | Evidence/Path
- Reduce width of Suggested Action and Help columns.
- Ensure multi-line vertical alignment is top.
- Keep column resizing enabled.

---

### 2) Layout restructure (XAML containers)
- Merge **Repair Options + System Actions** into one “Actions” box.
- Merge **Safe Tests + Dev Mode Lab Simulations** into one “Admin Tests” box.
- Add **Refresh Now** button near refresh interval/auto-refresh.
- Place Close button top-right or bottom-right (right-aligned).

---

### 3) Refresh workflow correctness (PowerShell)
- Implement `Invoke-RefreshNow`:
  - Status “Refreshing…” → “Refresh complete: <timestamp>”
  - On fail: “Refresh failed: <reason> (see logs)”
- Ensure UI updates use Dispatcher.

---

### 4) Rules Report reliability (PowerShell)
- Always generate report under `C:\ProgramData\FirewallCore\Reports\`
- Surface output path in Evidence/Path
- Log start + OK/FAIL

---

### 5) Dev Mode Secure Unlock (time-limited)
- Dev Mode checkbox triggers unlock prompt
- On success:
  - Set unlock expiry (example 10 minutes)
  - Enable Lab actions UI
  - Show “unlocked until …”
- Auto-relock after expiry
- First-run: prompt to set a secret if none exists (default secret `admin`)
- Future-ready: keep verification modular (password today, hardware later)

---

### 6) Lab simulations pop-ups
- Lab simulations must generate:
  - Event Log evidence
  - User alert pop-ups by default

---

## Deliverables
- Updated Admin Panel script (layout merges + refresh + rules report + secure unlock)
- Preserve docs:
  - `Docs/ADMIN_PANEL_GUIDE.md`
  - `Docs/DEV/ADMIN_PANEL_PHASEB_SPEC.md`
- Add “Changes Made / Implementations Done” section in the PR output.

---

## Quick Smoke Tests
- Refresh Now updates status to complete
- Quick Health Check produces evidence + log
- Notification Demo shows pop-ups + event logs
- Rules Report produces file + evidence path updated
- Dev Mode unlock works, expires, relocks
- Lab action shows pop-up + event log
- Close placement correct, resize OK
