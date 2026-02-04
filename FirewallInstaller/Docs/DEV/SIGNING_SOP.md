# Script Signing SOP (Hardware-Backed Authenticode)

## Purpose
All shipped PowerShell artifacts must be Authenticode-signed for enterprise-grade integrity, provenance, and tamper-resistance.

## Scope
Sign:
- *.ps1, *.psm1, *.psd1, *.ps1xml, *.pssc, *.psrc
- Repo locations: root installer scripts, Firewall\, Tools\, Tests\

Exclude:
- .git\, .vs\, bin\, obj\, node_modules\
- Docs\_local\, Docs\_archive\
- backup patterns: *.bak*, *.old*, *.disabled*, *~

## Trust Model
- Public certificates may be imported into Windows certificate stores.
- The signing private key is non-exportable and hardware-backed.
- Signing requires the hardware token to be present and unlocked (PIN).
- Without the hardware token, signing operations fail deterministically.

## Required Stores (Windows)
- Root CA -> LocalMachine\Root and CurrentUser\Root
- Publisher trust -> LocalMachine\TrustedPublisher and CurrentUser\TrustedPublisher
- Signing leaf -> CurrentUser\My

## Tools
- Sign: Tools\Release\Sign-FirewallCoreScripts.ps1
- Verify: Tools\Release\Verify-FirewallCoreSignatures.ps1

## Signing
### Dry run
~~~powershell
cd C:\FirewallInstaller
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Tools\Release\Sign-FirewallCoreScripts.ps1 -RepoRoot (Get-Location).Path -WhatIf
~~~

### Sign
~~~powershell
cd C:\FirewallInstaller
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Tools\Release\Sign-FirewallCoreScripts.ps1 -RepoRoot (Get-Location).Path
~~~

## Verification (CI-safe)
~~~powershell
cd C:\FirewallInstaller
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Tools\Release\Verify-FirewallCoreSignatures.ps1 -RepoRoot (Get-Location).Path
~~~

## Determinism Notes
- Authenticode cannot sign files smaller than 4 bytes. Empty scripts must contain at least a stub comment.
- If a file refuses to retain an embedded signature, normalize encoding to UTF-8 and re-sign.
- Keep signing logs out of Git (Tools\Logs\SignScripts_*.log).
