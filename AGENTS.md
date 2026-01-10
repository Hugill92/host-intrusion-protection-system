# FirewallInstaller  Agent Instructions (AGENTS.md)

This repository is a Windows PowerShell project for FirewallCore + Firewall Monitor.
**FirewallInstaller is the primary module/entrypoint** and must remain the root orchestrator for:
- install/uninstall functions
- Forced / DEV-Only / Pentest / Regression test suites
- packaging/release scripts (when present)

## Non-negotiable rules
1. **Minimal diffs only.** Do not refactor or rename files/folders unless explicitly requested.
2. **Do not break what already works.** Preserve existing CLI behavior and test runner flows.
3. **Do not rename/move test suites.** Keep these suite folders under the repo:
   - `Firewall\DEV-Only\`
   - `Firewall\DEV-Only\Forced\` (if present)
   - `Firewall\DEV-Only\Tests\` (if present)
   - `Firewall\Pentest\` (if present)
   - `Firewall\Regression\` (if present)
4. **No secrets/PII in commits.** Never add or modify runtime artifacts that contain machine/user data:
   - `Firewall\State\`
   - `Firewall\Logs\`
   - `Firewall\Snapshots\`
   - `Firewall\DEV-Only\State\`
   - `Firewall\Live\Baseline\firewall-baseline.json`
   Use templates like `*.example.json` when needed.

## Project conventions
- Prefer `$PSScriptRoot` and relative paths instead of hard-coded developer machine paths.
- Keep configuration as a single source of truth (avoid duplicated mappings/fallback logic).
- Logging should be deterministic and structured; do not spam output during normal runs.

## Notifier contract (do not regress)
Event-driven notifications must follow these rules:

### Severity  UI + sound
- **Info**
  - UI: **Tray**
  - Sound: info sound (per mapping)
  - Click: opens the correct Event Viewer location (FirewallCore log / relevant view)
- **Warning**
  - UI: **Popup**
  - Sound: warning sound (per mapping)
  - Click: opens the correct Event Viewer location
- **Critical**
  - UI: **Popup**
  - Sound: critical sound (per mapping)
  - **Manual review required**:
    - must not auto-dismiss by timeout
    - must not dismiss via X button
    - dismissal requires explicit acknowledgement

### Mapping
- EventId  Severity/UI/Sound/View mapping must be the **single source of truth** (no hardcoded duplicates).

## How to work changes (expected workflow)
- Make changes in small steps.
- After each step:
  - run the relevant test(s)
  - review `git diff`
  - commit with a clear message

## Testing expectations
- Tests should remain runnable from repo root.
- Do not change test schemas/IDs unless explicitly requested.
- If a test fails, fix the root cause instead of loosening assertions.

## When uncertain
- Ask for the intended behavior/spec and point to the exact file/line you would change.
