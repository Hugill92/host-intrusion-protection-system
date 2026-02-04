# Codex Deterministic Test Loop (FirewallCore)

**Run this checklist after every Codex-generated code change.**
Goal: deterministic, PS5.1-safe, AllSigned-safe changes with clean evidence.

## Acceptance Contract (MUST PASS)

### 1) Parse gate
- Use `System.Management.Automation.Language.Parser::ParseFile`
- **Expected:** 0 parse errors
- If failing, capture: message + line + column + extent text

### 2) PS5.1 compatibility gate
- No PS7-only syntax (examples: `??`, `.Where()`, LINQ-style pipeline methods)
- Assume Windows PowerShell 5.1 unless explicitly allowed otherwise

### 3) ScheduledTaskAction gate
- `New-ScheduledTaskAction -Argument` MUST be a **single string**
- No arrays (`@(...)`) passed directly to `-Argument`
- If building args from parts, join deterministically (e.g., `($parts -join ' ')`)

### 4) Signing gate (A33)
- Strip old signature block if needed
- Re-sign with **A33** cert using SHA256
- **Expected:** `Get-AuthenticodeSignature` returns `Status = Valid`

### 5) Run gate (AllSigned)
- Run installer under `ExecutionPolicy AllSigned`
- DEV mode first
- On failure, capture a trace/log excerpt showing the failing line/area

## Evidence to capture (attach to PR / notes)
- `git diff`
- installer console output
- trace snippet (or log tail) if failure

## Suggested order (do not reorder)
1. Parse
2. PS5.1 check
3. ScheduledTaskAction argument check
4. Strip + re-sign (A33, SHA256) + verify Valid
5. Run under AllSigned (DEV first)
6. Evidence capture
