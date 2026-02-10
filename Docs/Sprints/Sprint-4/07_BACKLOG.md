# Backlog

## 2026-02-09 — V2 Network Bundle follow-ups

- Windows Features/Capabilities exporter:
  - finalize capture scope and validate on VM (offline/stable environment).
  - decide default filters (Enabled-only OptionalFeatures; Installed-only Capabilities) vs capture-all switches.
- V2 wiring:
  - versioned ProgramData deployment path + AllSigned signing gate for shipped scripts.
  - single orchestrator: create bundle root → run all sections → write manifest/SHA256 → zip-at-end.

