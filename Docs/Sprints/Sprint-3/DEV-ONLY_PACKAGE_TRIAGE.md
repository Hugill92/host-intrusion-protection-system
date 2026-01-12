# DEV-Only Package — Triage & Patch Notes

Date: 2026-01-12

## Issue
`DEV-Only/Tests/Test-Install-TamperProtection.ps1` failed to run because the script had an invalid structure:
- The helper dot-source line was placed **inside** the `param(...)` block, which breaks PowerShell parsing.

In addition, `DEV-Only/Tests.zip` needed regeneration so the packaged tests matched the fixed source.

---

## Fix Applied
- Repaired `DEV-Only/Tests/Test-Install-TamperProtection.ps1`
  - Valid `param(...)` block
  - `. "$PSScriptRoot\Test-Helpers.ps1"` moved **after** `param`
  - Ensured `$EventsFound` is computed from test results
  - If no matching events are found, test emits a **WARN** and returns PASS (DEV usability), while still surfacing the signal
- Regenerated `DEV-Only/Tests.zip`

---

## How to apply the patch to the repo
Recommended: copy only the two updated artifacts into your repo working tree:

- `DEV-Only/Tests/Test-Install-TamperProtection.ps1`
- `DEV-Only/Tests.zip`

### Option A — manual copy (safe)
1. Extract the patched package to a temporary folder (NOT your repo root).
2. Copy the two files above into your repo at the same relative paths.
3. Run `git status` and commit.

### Option B — PowerShell copy commands
From a PowerShell prompt (adjust `$PatchRoot`):
```powershell
$RepoRoot  = "C:\FirewallInstaller"
$PatchRoot = "C:\Temp\DEV-Only_patched\DEV-Only"

Copy-Item -Force -LiteralPath (Join-Path $PatchRoot "Tests\Test-Install-TamperProtection.ps1") `
  -Destination (Join-Path $RepoRoot "DEV-Only\Tests\Test-Install-TamperProtection.ps1")

Copy-Item -Force -LiteralPath (Join-Path $PatchRoot "Tests.zip") `
  -Destination (Join-Path $RepoRoot "DEV-Only\Tests.zip")
```

---

## Verification
Run the DEV test harness you already use, or invoke the test directly:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\FirewallInstaller\DEV-Only\Tests\Test-Install-TamperProtection.ps1"
```

Expected behavior:
- Script parses and runs cleanly.
- If no matching events are found, it warns (but does not hard-fail DEV execution).

---

## Follow-up (Sprint 3)
Add a `Tools/Build-DevOnlyPack.ps1` generator so `Tests.zip` is always rebuilt from `DEV-Only/Tests/*` and never drifts from the source tree.
