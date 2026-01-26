# Sprint 3 — Admin Panel Phase B — Known Issues (2026-01-26)

## KI-01 — Export Diagnostics Bundle can degrade UI until restart
**Symptom**
- Export Diagnostics Bundle can succeed, but UI buttons become unusable afterward until the panel is closed and reopened.

**Impact**
- Slows validation; creates uncertainty during testing.

**Workaround**
- Close and reopen Admin Panel after export.

**Acceptance criteria**
- Export completes without disabling other controls.
- Busy/refresh gates always exit (no stuck state).

---

## KI-02 — Export Baseline + SHA256 does not create new baseline folders
**Symptom**
- Clicking Export Baseline + SHA256 does not reliably create a new folder under C:\ProgramData\FirewallCore\Baselines\BASELINE_*.
- Baseline artifacts exist inside Diagnostics Bundle output (hashes + policy export), but Baselines folder does not update.

**Impact**
- Breaks deterministic baseline + hashing workflow.

**Workaround**
- Temporarily use Diagnostics Bundle artifacts as the baseline source.

**Acceptance criteria**
- Each click creates a new BASELINE_YYYYMMDD_HHMMSS folder.
- Folder contains consistent exports + hashes.

---

## KI-03 — Evidence Path readability and row selection highlight
**Symptom**
- Evidence Path text is hard to read until hover/click.
- Row selection highlight remains blue longer than desired.

**Impact**
- Minor UX friction.

**Acceptance criteria**
- Evidence Path is readable without hover.
- Selection/hover styling matches desired UX.
