# Secure Token v1 Spec

This document defines the **Secure Token** used to gate privileged actions under Maintenance Mode.

## Goals
- Short-lived unlock (time-bounded)
- Scope-limited capability token (principle of least privilege)
- Deterministic, auditable outcomes (receipt + EVTX)
- Machine-bound and operator-bound context

## Non-goals
- Not intended to "change public internet IP"
- Not a stealth mechanism; it must be visible and auditable

---

## Token concepts
### Token envelope
A token file is an envelope containing:
- `payload` (JSON object)
- `sigAlg` (string)
- `signature` (base64)
- `keyId` (identifier for verifier key/cert)

### Payload schema
`MaintenanceToken.v1`

Minimum payload fields:
- schema
- runId
- issuedUtc
- expiresUtc
- scopes[]
- machine: machineGuid, hostname
- principal: userSid, username, isAdmin
- attestation: unlockMethod, certThumbprint (optional), keyId (optional)
- nonce (base64)

### Token lifecycle
- Issue → Validate → Use → Revoke/Expire
- Every privileged action must validate required scope(s) before execution

---

## Receipt contract (planned)
Each issuance/validation/use should produce a receipt under:
- `C:\ProgramData\FirewallCore\Receipts\SecurityTokens\`

Receipt schema:
- `SecureTokenReceipt.v1`

Receipt fields:
- ReceiptSchema, TimestampUtc, RunId
- Operation: Issue | Validate | Revoke | Use
- Outcome: Success | Failed | Expired | Missing | ScopeMissing | InvalidSignature
- ScopeRequested (if relevant)
- TokenPath
- ExpiresUtc
- CallerContext (User, IsAdmin, UiSource)
- Error (nullable)

---

## EVTX contract (planned)
Provider(s):
- FirewallCore.SecurityToken

Required event names:
- SecurityToken.Issue.Start
- SecurityToken.Issue.Result
- SecurityToken.Validate.Result
- SecurityToken.Revoke.Result
- SecurityToken.Use.Result

Payload rules:
- Always include RunId + Operation + Outcome
- Never log secrets (PINs, private key material, etc.)
