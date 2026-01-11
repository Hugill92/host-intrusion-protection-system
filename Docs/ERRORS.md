# Error Codes and Failure Conventions

This project uses **Windows Installer–style exit codes** where it makes operational sense, so logs and automation map to enterprise expectations.

## Core rule
If we fail, we fail **early** and **loudly**:
- Print a human-readable root cause
- Identify the phase (Preflight, Install, Repair, Uninstall, Verify, Runtime)
- Return a meaningful exit code

## Common exit codes

### 1600-series (installer-style)
- **1602** — User cancelled
- **1603** — Fatal error (generic). Only use if we *also* logged the exact root cause.
- **1605** — Action valid only for products currently installed
- **1618** — Another installation already in progress (use for orchestration lock contention)
- **1620** — Package could not be opened (use when a required payload is missing/unreadable)
- **1638** — Another version of the product is already installed

### Reboot semantics
- **1641** — Reboot initiated
- **3010** — Restart required to complete operation

## Logging expectations (minimum)
Every non-zero exit should log:
- Timestamp
- Mode (Install/Repair/Uninstall/Verify/Stop)
- Phase
- Root cause message
- Exit code

## Scheduling guardrail (policy)
Do not register or start scheduled tasks unless:
- preflight passes
- script integrity/parse checks pass
- principals are verified (SYSTEM vs user vs service account)

## Notifiers troubleshooting notes (2026-01-10)

### Toast popup not visible (Show() returns OK)
Symptom: WinRT toast Show() returns success, payloads drain, sounds play, but no banner appears.
Notes: Can be caused by shell-host state, notification platform state, or per-app banner suppression.
Mitigations used during sprint:
- Ensure listener runs in interactive user session (STA).
- Ensure HKCU values are enabled:
  - PushNotifications\ToastEnabled=1
  - Notifications\Settings\<AppId>\ShowBanner=1
- Restart WpnService / WpnUserService and shell hosts (Explorer / ShellExperienceHost), or reboot.

### StrictMode gotcha when searching strings containing `$f` / `$QueueFile`
Symptom: Select-String -Pattern "...\$f..." throws because PowerShell expands variables in double quotes under StrictMode.
Fix: Use single-quoted patterns:
- -Pattern 'QueueFile\s*=\s*\$f\.Name'

### Select-String -Recurse parameter
Symptom: Select-String -Recurse not available in some PS builds/contexts.
Fix: Use Get-ChildItem pipeline:
- Get-ChildItem -Recurse -File | Select-String -Pattern ...

### Kafka native dependency load failure (rolled back)
Symptom: Confluent.Kafka Build() fails: "Failed to load the librdkafka native library."
Fix: Defer until we have a pinned runtime distribution plan for librdkafka.dll (win-x64) plus managed dll placement and load-path guarantees.

