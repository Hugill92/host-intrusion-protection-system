# 03 - Signing / AllSigned Gate (FirewallCore)

## Purpose
Any PowerShell edit invalidates Authenticode signatures.
Under ExecutionPolicy=AllSigned, scripts must be re-signed after changes.

This skill defines the mandatory post-edit signing gate.

## Rules
- PowerShell 5.1 only
- All shipped scripts must have Status=Valid
- Signing happens in repo, not live paths

## Canonical signing certificate
Thumbprint:
A33C8BA75D7975C2D67D2D5BB588AED7079B93A4

Location:
Cert:\CurrentUser\My

## Required flow
1. Parse gate (0 errors)
2. Remove Mark-of-the-Web if present
3. Re-sign with SHA256
4. Verify signature = Valid
5. Run under ExecutionPolicy AllSigned

## Signing helper (reference only)
PowerShell helper exists locally to:
- find modified *.ps1 / *.psm1 / *.psd1
- re-sign with the canonical cert
- verify Status=Valid

YubiKey PIN prompts are expected when private key access is required.

## Failure handling
- If HasPrivateKey=False → certificate is not bound to YubiKey
- Repair using certutil -user -repairstore My <SerialNumber>
