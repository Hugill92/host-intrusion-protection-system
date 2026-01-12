# Architecture Overview

This document describes the FirewallCore installer architecture and future roadmap.

---

## Sprint 1 Scope (Completed)

### Installer Architecture
- Canonical installer logic lives under `_internal`.
- Entry points:
  - `Install.cmd`
  - `Uninstall.cmd`
- Clean install and clean uninstall behavior verified.

### Uninstall Guarantees
- Removes all installer-owned files, tasks, and configuration.
- Leaves the system in a state suitable for immediate reinstall.

---

## Sprint 2 Scope (Planned)

### Repair Mode
- Restore system state back to a known baseline hash.
- Detect and correct drift for installer-owned artifacts.
- Preserve logs and user data.

### Execution Hardening
- Remove visible console windows from toast and dialog actions.
- Ensure hidden execution paths are used consistently.

### Event Viewer Hardening
- ACL separation and hardening.
- Improved install-time verification and logging.

---
