# Sprint 3 Risks and Triage

## Known Risks
- AllSigned reinstall break if any imported dependency is NotSigned/HashMismatch.
- Any console patch/edit invalidates Authenticode and will fail under AllSigned until re-signed.
- Encoding/empty-file signing edge cases (empty scripts must include a stub comment; normalize UTF-8 if signatures do not persist).
- DISM/servicing and edition constraints when enabling Windows optional features (V2 planning area).

## Triage Playbooks

### A) AllSigned blocks install/reinstall due to unsigned/invalid dependency
**Symptoms**
- Console error: “not digitally signed” or signature status not `Valid` for imported module/script.

**Checks**
1) Identify first failing path from console output.
2) `Get-AuthenticodeSignature` on offender.
3) If MOTW suspected: `Unblock-File` on offender.

**Mitigation (locked SOP)**
- Re-sign execution surface (modules/helpers/task scripts) with the locked signing certificate (SHA256) and verify `Status=Valid`.
- Re-run operation under AllSigned.

**Evidence pointers**
- ProgramData logs + transcript for the failed run
- Signature verification output

### B) Signature does not persist / unexpected HashMismatch
**Symptoms**
- Signed file later shows HashMismatch or NotSigned with no intentional edits.

**Checks**
- Confirm file encoding is UTF-8.
- Check for accidental whitespace edits or line-ending changes.

**Mitigation**
- Normalize encoding to UTF-8 and re-sign.
- Ensure empty scripts contain a stub comment (>4 bytes) to be signable.

### C) Feature enable fails (V2 planning)
**Symptoms**
- DISM enable feature fails, feature unavailable, or reboot required.

**Checks**
- Pending reboot state
- Edition/build compatibility
- Servicing stack health

**Mitigation**
- Record NotApplicable vs Failed deterministically
- Surface reboot requirement without forcing restart

### D) Sharing/profile drift or accidental exposure
- Symptoms:
  - Public network ends with discovery or file/printer sharing enabled.
- Checks:
  - Active network category (Public/Private)
  - Rule-group state for discovery/sharing
- Mitigation:
  - Enforce Public-safe posture immediately
  - Record evidence in receipt + EVTX
- Evidence pointers:
  - Network report receipt + EVTX entries

### E) Watchlist drift / noisy telemetry
- Symptoms:
  - Telemetry volume too high, disk growth, or irrelevant events drown signal.
- Checks:
  - Receipt shows which tier enabled; confirm Tier 3 is support-mode only.
- Mitigation:
  - Default to AuditOnly + Tier 1; make deeper tiers explicit.
  - Add volume controls and retention caps for any capture outputs.
- Evidence pointers:
  - Receipt JSON + EVTX summary events
