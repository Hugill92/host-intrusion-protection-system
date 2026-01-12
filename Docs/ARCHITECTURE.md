# Architecture Overview

This document describes the installer, repair, and system integration architecture for FirewallCore.

---

## Installer Layout
[unchanged]

---

## Wrapper Pattern
[unchanged]

---

## Install, Repair, and Uninstall Modes
[unchanged]

---

## Event Viewer Integration

- Custom Event Viewer views are deterministically staged.
- Views are assumed present and loaded during install.
- ACL hardening and separation is deferred to a future sprint.
- View staging logic is idempotent and safe to rerun.
- Review actions are invoked from notifications and dialogs.

### Known Limitation
- A transient console window may appear when launching log review actions.
- This behavior is cosmetic and tracked for cleanup in a future sprint.

---
