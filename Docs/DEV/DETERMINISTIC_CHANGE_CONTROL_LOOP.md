# Deterministic Change Control Loop (FirewallCore)

**Run this checklist after every generated or externally-sourced code change** (automation output, large refactors, vendor patches, scripted modifications, etc.).
Goal: deterministic execution, Windows PowerShell 5.1 compatibility, and policy-safe enforcement under signed execution.

## Acceptance Contract (MUST PASS)

### 1) Parse gate
- Validate the script parses cleanly via `System.Management.Automation.Language.Parser::ParseFile`
- **Expected:** 0 parse errors
- If failing, capture: message + line + column + extent text (for precise remediation)

### 2) Windows PowerShell 5.1 compatibility gate
- Avoid syntax/features not supported by Windows PowerShell 5.1
- Keep implementations compatible unless an explicit project decision permits newer runtimes

### 3) Scheduled Task argument gate
- `New-ScheduledTaskAction -Argument` MUST be a **single string**
- Do not pass arrays directly to `-Argument`
- If constructing arguments from parts, join deterministically (e.g., `($parts -join ' ')`)

### 4) Signing / integrity gate
- If a signature exists and changes were made: remove any stale signature block, then re-sign
- Use SHA256
- **Expected:** signature verification returns `Status = Valid`

### 5) Execution gate
- Execute using the project’s signed-execution policy (e.g., `ExecutionPolicy AllSigned`)
- Validate in a controlled mode first (e.g., DEV) before broader rollout
- On failure, collect a trace/log excerpt pinpointing the failing line/area

## Evidence to capture (attach to PR / sprint notes)
- `git diff`
- console output from execution
- trace snippet (or log tail) if failure occurs

## Required order (do not reorder)
1. Parse
2. Compatibility
3. Scheduled Task argument invariants
4. Signing verification
5. Controlled execution
6. Evidence capture
