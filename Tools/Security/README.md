# Tools\Security (scaffold)

This folder contains scaffolding scripts for the Sprint-4 Secure Token gate.
Phase A implementation can be DPAPI+HMAC.
Phase B should move crypto to a signed helper (YubiKey-backed), leaving PowerShell as thin orchestration.

Files:
- Assert-FirewallCoreMaintenance.ps1 (gate helper)
- New-FirewallCoreSecureToken.ps1 (issue token)
- Test-FirewallCoreSecureToken.ps1 (validate token)
- Revoke-FirewallCoreSecureToken.ps1 (revoke token)
