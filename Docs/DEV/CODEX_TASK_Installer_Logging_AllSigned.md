# Codex Task — Installer Logging + AllSigned Realism (LIVE)

## Goal
Make the LIVE installer produce **deterministic audit logs on every run**, even when the install is a no-op because the system is already installed. Ensure the run behaves correctly under **ExecutionPolicy=AllSigned** (release realism), and that log fields are populated (mode/elevated/etc).

This is a hardening/polish task — not a feature addition.

---

## Scope (Files)
- Primary: `C:\FirewallInstaller\_internal\Install-FirewallCore.ps1`
- Related helpers only if they already exist in this script (do not introduce new modules unless absolutely required)

---

## Current Observations
- `FirewallCore` event log exists and events write correctly under provider/source `FirewallCore-Installer` (EventIds seen: 1000, 1008, 1901).
- File logging under `C:\ProgramData\FirewallCore\Logs` exists as a folder, but installer audit logs are not consistently created/updated per run.
- Some Event Viewer messages show empty `mode=` and `elevated=` due to ordering/scope.
- Running with `-ExecutionPolicy Bypass` masks signing enforcement; LIVE acceptance must be validated under `AllSigned`.
- Repeat install runs should never “skip logging” (even if skipping work is correct).

---

## Required Behavior (Acceptance Criteria)

### A) Event Viewer — Always log per invocation
Each invocation must produce:
- **EventId 1000**: `INSTALL START ...`
- One of:
  - **EventId 1008**: `INSTALL OK ...` (if work performed OR install completes normally)
  - **EventId 1003**: `INSTALL NOOP ... reason=already-installed` (if installer determines no work needed)
  - **EventId 1901**: `INSTALL FAIL ... <exception>` (only on real failure)

Never emit both OK and FAIL for the same run.

Provider/source must remain:
- Log: `FirewallCore`
- Source/ProviderName: `FirewallCore-Installer`

---

### B) File log — Always create/update per invocation
Every installer run must create or append a durable log in:
- `C:\ProgramData\FirewallCore\Logs\Install-FirewallCore_<MODE>_YYYYMMDD_HHMMSS.log`

Log must include at least:
- Start banner / line (mode, user, computer, elevated)
- End line (OK/NOOP/FAIL)
- If fail: exception message and context

---

### C) Populate fields deterministically
Event messages must not contain empty values for:
- `mode=`
- `elevated=`

Ensure these values are computed before the first log write.

---

### D) Correct control-flow (no false FAIL)
`INSTALL FAIL` (1901) must only appear inside a true `catch {}` path.
No unconditional `throw` outside of `catch` is allowed.

---

### E) AllSigned realism
Installer must be runnable under:
- `powershell.exe -ExecutionPolicy AllSigned -File ... -Mode LIVE`

Assume the script is signed after changes. Do not rely on `Bypass` for acceptance.

---

### F) Backward compatibility / safety constraints
- Must remain **PowerShell 5.1 compatible** (no PS7-only operators).
- Do not break existing scheduled task registration logic.
- Keep existing hidden launch contract (arguments must remain single-string, no `-Argument @(` arrays).
- Logging failures must not block installation (best-effort logging).

---

## Implementation Notes

### 1) Logging structure (must be this pattern)
Use this skeleton around the main install logic:
- Compute `$Mode` default and `$Elevated` early (before any logging)
- Start transcript/file log early
- `try { START; (optional) NOOP gate; main install; OK }`
- `catch { FAIL; throw }`
- `finally { Stop-Transcript }`

### 2) Always log START before any early-return
If the script currently performs an idempotency check like “already installed => return”, move it below the START log and emit a NOOP event.

### 3) Message format
Keep the current pipe-delimited format if desired, but ensure fields are populated:
- `INSTALL START | mode=LIVE | user=... | computer=... | elevated=true`
- `INSTALL OK | mode=LIVE | end=...`
- `INSTALL NOOP | mode=LIVE | reason=already-installed`
- `INSTALL FAIL | mode=LIVE | <exception>`

---

## Test Plan (Must Pass)

### 1) Signature verification
Confirm signature state is Valid after changes:
- `Get-AuthenticodeSignature C:\FirewallInstaller\_internal\Install-FirewallCore.ps1`

### 2) AllSigned execution
Run:
- `powershell.exe -NoLogo -NoProfile -ExecutionPolicy AllSigned -File C:\FirewallInstaller\_internal\Install-FirewallCore.ps1 -Mode LIVE`

### 3) Event log verification (repeat runs)
Run installer 3 times:
- Run #1: expect 1000 + (1008 or 1003 depending on install state)
- Run #2: expect 1000 + 1003 (if already installed)
- Run #3: expect 1000 + 1003 again (or 1008 if it legitimately does work)

Verify via:
- `Get-WinEvent -FilterHashtable @{ LogName="FirewallCore"; ProviderName="FirewallCore-Installer" } -MaxEvents 20`

### 4) File log verification
Verify a new log is created per run or appended deterministically:
- `Get-ChildItem C:\ProgramData\FirewallCore\Logs -Filter "Install-FirewallCore_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5`

---

## Deliverables
1) Updated `Install-FirewallCore.ps1` implementing:
   - START/OK/NOOP/FAIL event IDs (1000/1008/1003/1901)
   - File log under ProgramData Logs
   - Deterministic mode/elevation values
   - Correct try/catch/finally structure
2) No remaining `-Argument @(` patterns in scheduled task actions
3) No PS7-only syntax introduced

---

## Changes Made / Implementations Done
(Fill this section in)

- [x] Moved START log above idempotency checks and added NOOP logging path
- [x] Added deterministic `$Mode` defaulting and `$Elevated` computed early
- [x] Implemented file transcript/log creation in ProgramData Logs
- [x] Refactored try/catch/finally to prevent false FAIL events
- [ ] Verified AllSigned run produces new 1000 + (1008/1003) events every invocation (requires re-sign after edits)
- [ ] Verified log files created/updated per invocation (requires running installer)
- [x] Verified no `-Argument @(` remains

---

## Evidence to Paste Back (For Review)
- Output of last 10 events from FirewallCore installer provider
- Names/timestamps of generated install log files
- A single AllSigned run command output (success)
