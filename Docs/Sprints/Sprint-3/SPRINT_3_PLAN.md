# Sprint 3 Plan - Regression Testing + Signing Readiness

- Created: 2026-01-12 14:03:02

## Theme
- Prove reliability with repeatable regression tests, then prepare signing + packaging.

## Objectives
1) Regression testing for installer/uninstaller lifecycle
2) Complete all test suites (Forced/DEV and any live-mode gates) with evidence
3) Demonstrate real-world usability (not just functional demos)
4) Signing readiness: pre-hash guardrails, signing workflow, release/tag checklist

## Definition of done
- Clean install -> uninstall -> reinstall loop passes on at least 2 fresh VMs.
- No ghost consoles from background components.
- All required tests pass or have documented exceptions with follow-up issues.
- Evidence bundle produced under `Docs/Sprints/Sprint-3/Evidence/`.

## Inputs
- Sprint 2 prestage checklist: `Docs/Sprints/Sprint-2/PRESTAGE_CHECKLIST.md`
- Canonical docs remain in `Docs/` root (ARCHITECTURE, ERRORS, ROADMAP, NOTIFIERS_SIGNOFF, PROJECT_MEMORIES).

