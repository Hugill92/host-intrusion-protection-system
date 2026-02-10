# Secure Token Phase A/B Implementation Plan

## Phase A (fast + strong, ship first)
Mechanism:
- Token signed using an HMAC key protected by DPAPI (LocalMachine) OR verified by a locally stored verifier key.
- PowerShell scripts issue/validate/revoke tokens.
- ACL hardening enforced on token directory/file.

Pros:
- No external dependency
- Deterministic
- Strong operational story

Cons:
- If attacker has full local admin control, they may be able to interfere (within expected trust boundary)

## Phase B (hardware-backed)
Mechanism:
- Signed helper (compiled, Authenticode) performs sign/verify using YubiKey PIV.
- PowerShell becomes thin orchestration; no sensitive crypto in scripts.
- Token signature is produced only with YubiKey PIN+touch.
- Token verification uses public cert thumbprint + chain trust installed by FirewallCore.

Pros:
- Strongest gate (hardware-backed)
- Clear enterprise narrative

Cons:
- Requires helper build/sign pipeline and YubiKey presence

## Verification rules (both phases)
- Token must be rejected if:
  - missing / expired
  - missing required scope
  - signature invalid
  - schema mismatch
- Token file ACL must be enforced at install/update/repair and during token issuance
