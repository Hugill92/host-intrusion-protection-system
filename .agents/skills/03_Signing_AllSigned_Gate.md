## Signing Gate (AllSigned) — ALWAYS run last

Any PowerShell edit invalidates Authenticode signatures. This repo is executed under `-ExecutionPolicy AllSigned`,
so EVERY Codex change-set must end with a re-sign + verification gate.

### Mandatory final step (run last)
From repo root:

- Run the repo signing tool:
  - `C:\FirewallInstaller\Tools\ReSign-FirewallCoreAllSigned.ps1`
  - Use repo-first signing; only sign live paths if explicitly requested:
    - Optional: `-AlsoSignLive` (only when the task requires it)

- The signing tool MUST:
  - Strip ONLY real Authenticode blocks by matching the header line exactly:
    - `^# SIG # Begin signature block`
  - Avoid self-truncation: sign the signing tool itself LAST
  - Unblock Mark-of-the-Web where applicable (`Unblock-File`)
  - Sign with the A33 YubiKey cert (SHA256) and then VERIFY

### Verification (required evidence)
After signing, verify that ALL intended scripts report `Status = Valid`:

- `Get-AuthenticodeSignature` must return `Valid` for modified files at minimum
- If the task touched wrappers/tasks/entrypoints, verify those as well

### Signing scope rules
- DO sign: installer/runtime PowerShell scripts, Tools, Modules, DEV-only tools, regression scripts
- DO NOT sign: `Docs/_local/**`, `Old/**`, backups, artifacts, exported logs/bundles/baselines, or anything ignored by git
- DO NOT invent new certs; use the existing A33 workflow and the repo’s signing tool

### Codex response format update (required)
Every Codex response MUST include:

- **Changes Made**
- **Files Modified**
- **Tests/Evidence**
  - Include the signing tool run + a snippet of signature verification results
- **Notes**
