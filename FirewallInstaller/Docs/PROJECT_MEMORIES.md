# Project Memories (Repo-Safe)

This file captures stable, deterministic operational decisions and workflows.

## Script signing (hardware-backed Authenticode)
- Date: 2026-02-03 02:34:22
- All shipped PowerShell scripts are Authenticode-signed using a hardware-backed, non-exportable private key (PIN required).
- Certificates can be imported into Windows stores, but signing requires physical token presence; possession of certificates alone is insufficient.
- Tooling:
  - Tools\Release\Sign-FirewallCoreScripts.ps1 (batch signer; supports -WhatIf)
  - Tools\Release\Verify-FirewallCoreSignatures.ps1 (verification gate; CI-safe)
- Scope: repo root installer scripts, Firewall\, Tools\, Tests\ (excluding Docs/_local, build/vendor folders, and backups).
- Determinism: Authenticode cannot sign files smaller than 4 bytes; empty scripts must include a stub comment. Normalize encoding to UTF-8 if needed.

## Script signing (hardware-backed Authenticode)
- Date: 2026-02-03 02:34:31
- All shipped PowerShell scripts are Authenticode-signed using a hardware-backed, non-exportable private key (PIN required).
- Certificates can be imported into Windows stores, but signing requires physical token presence; possession of certificates alone is insufficient.
- Tooling:
  - Tools\Release\Sign-FirewallCoreScripts.ps1 (batch signer; supports -WhatIf)
  - Tools\Release\Verify-FirewallCoreSignatures.ps1 (verification gate; CI-safe)
- Scope: repo root installer scripts, Firewall\, Tools\, Tests\ (excluding Docs/_local, build/vendor folders, and backups).
- Determinism: Authenticode cannot sign files smaller than 4 bytes; empty scripts must include a stub comment. Normalize encoding to UTF-8 if needed.

