# FeatureSet V2: Windows Features (V2 Planning)

This doc defines how FirewallCore V2 will **deterministically** enable Windows Optional Features during **Install / Update / Repair**, with evidence (EVTX + receipt) and guardrails (no surprise toggles).

---

## 1. Purpose
- Deterministically converge a machine to a **versioned FeatureSet**.
- Run only in elevated installer/update/repair context (not watchdog/background).
- Produce receipts and EVTX events suitable for audit/regression.

---

## 2. Deterministic Naming Rule
**Do not trust the Windows Features UI labels.** Use canonical identifiers:
- Optional Features: `Get-WindowsOptionalFeature -Online`
- Capabilities (if needed): `Get-WindowsCapability -Online`

### Availability handling
- Validate each desired feature exists on the current OS build/edition.
- Record `NotApplicable` deterministically (not silent failure).

---

## 3. FeatureSet Model (versioned)
Minimum fields:
- FeatureSetId
- Version
- EnableOnly (default true)
- DesiredOptionalFeatures[]
- DesiredCapabilities[] (optional)
- Prereqs:
  - RequiresAdmin
  - Edition/build constraints
  - Virtualization support checks (if applicable)
- RebootPolicy:
  - Always apply with `/NoRestart`
  - Detect and record reboot requirement

State + receipts:
- FeatureSet selection stored in ProgramData State
- Receipt written on every run (AuditOnly/Enforce)

---

## 4. Apply Algorithm (Converge, Idempotent)

### Preflight
- Confirm admin
- Confirm OS edition/build support
- Detect pending reboot state and record it
- If virtualization features are in scope, validate prerequisites (CPU virt support, hypervisor state)

### Detect
- Query current feature states
- Compute delta: Missing = DesiredEnabled - CurrentlyEnabled

### Apply (Enforce)
- Enable missing features only
- Use DISM `/Enable-Feature /Online /NoRestart` (and `/All` if dependencies required)
- Collect per-feature outcome + DISM exit code + reboot-required signal

### Verify
- Re-query states after application
- Record: EnabledOk / Failed / NotApplicable

### AuditOnly
- Runs Preflight + Detect + writes receipt
- Makes no system changes

---

## 5. Operational Modes
- AuditOnly: compute delta + receipt + EVTX (no changes)
- Enforce: apply delta + receipt + EVTX
- Update: apply only new delta for updated FeatureSet version
- Repair: apply delta + verify against selected FeatureSet

---

## 6. Reboot Handling
- Always use `/NoRestart`
- If reboot required:
  - Receipt: `RebootRequired = true`
  - EVTX: ApplyComplete includes reboot-required
  - Admin Panel can surface “Reboot required to finalize FeatureSet”

Optional:
- Post-reboot verification run (verify-only)

---

## 7. Evidence + Logging

### Receipt (JSON)
Write a deterministic receipt every run:
- Timestamp
- FeatureSetId + Version
- Mode (AuditOnly/Enforce)
- RequestedOptionalFeatures[]
- DeltaOptionalFeatures[]
- Results[] (per feature):
  - FeatureName
  - ActionAttempted (None/Enable)
  - Outcome (EnabledOk/Failed/NotApplicable)
  - ExitCode/HResult (when available)
- PendingRebootBefore
- RebootRequiredAfter
- Errors[]

### EVTX (events)
Minimum events:
- ApplyRequested
- PreflightResult
- FeatureAttempt / FeatureResult
- ApplyComplete (includes reboot-required)
- ApplyFailed

---

## 8. Security Guardrails
- No feature changes from background/watchdog tasks.
- Require elevation; refuse otherwise with explicit log.
- Manifest integrity must be verifiable (hash/signature plan for V2+).
- Default EnableOnly (no disables during install/update/repair).
- Disable/revert (if ever supported) must be explicit, gated, and logged.

---

## 9. Feature Grouping (policy)
- Tier A: safe baseline features (low-impact)
- Tier B: virtualization/lab stack (high-impact) — opt-in only

---

## 10. Uninstall stance (policy)
Default:
- Do not revert Windows features on uninstall.

Optional future:
- Clean uninstall may offer explicit “Revert FeatureSet changes” based on receipts.

---

## 11. Acceptance Criteria (Sprint gates)
- AuditOnly makes no changes and writes a receipt.
- Enforce enables only missing features and writes a receipt.
- Idempotent: second Enforce run delta=0.
- NotApplicable is recorded deterministically.
- Reboot required is detected and surfaced (no forced reboot).
- Docs contain pointers only (no pasted logs).
