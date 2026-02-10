# Secure Token v1 Storage + ACL

## Token storage (planned)
- Token directory:
  - `C:\ProgramData\FirewallCore\Security\Tokens\`
- Primary maintenance token file:
  - `Maintenance.token.json`

## ACL requirements
Token directory and token file must be restricted to:
- SYSTEM: Full
- BUILTIN\Administrators: Full
- (Optional) TrustedInstaller: Full
- No Users read access.

## Retention
- Token expires by time.
- Token can be revoked explicitly.
- Old token receipts are retained under Receipts policy (separate from active token).

## Integrity
- Token must be tamper-evident via signature
- Token must be time-bounded via expiresUtc
- Verifier must check:
  - schema match
  - not expired
  - required scope present
  - signature valid
  - machine binding fields present (at minimum machineGuid)
