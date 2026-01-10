# HIPS Project Context (for ChatGPT/Codex)

## What this repo is
Host Intrusion Protection System (HIPS) — Windows PowerShell HIPS with:
- FirewallCore enforcement
- Monitor + notifications
- Installer/orchestration
- DEV/Forced/Pentest/Regression suites

## Non-negotiables
- FirewallInstaller is the root orchestrator.
- Do not commit runtime artifacts (State/Logs/Snapshots/Baselines).
- Follow notifier contract in AGENTS.md.

## Current focus
Notifiers:
- Info => tray + correct sound + click opens correct Event Viewer view
- Warning => popup + correct sound + click opens correct Event Viewer view
- Critical => popup + correct sound + manual review required (no X dismiss, no timeout)

## How to work
- Minimal diffs only.
- Prefer targeted fixes.
- Always identify root cause before refactor.
