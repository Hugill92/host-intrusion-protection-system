param(
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Scope
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$tokenPath = 'C:\ProgramData\FirewallCore\Security\Tokens\Maintenance.token.json'
if (-not (Test-Path -LiteralPath $tokenPath)) {
  throw "Maintenance token missing. Scope required: $Scope"
}

$raw = Get-Content -LiteralPath $tokenPath -Raw -ErrorAction Stop
$tok = $raw | ConvertFrom-Json

if (-not $tok.payload) { throw "Token payload missing." }
if ($tok.payload.schema -ne 'MaintenanceToken.v1') { throw "Token schema mismatch." }

$now = (Get-Date).ToUniversalTime()
$exp = [datetime]$tok.payload.expiresUtc
if ($now -ge $exp) { throw "Maintenance token expired ($($exp.ToString('o')) UTC)." }

if (-not $tok.payload.scopes -or ($tok.payload.scopes -notcontains $Scope)) {
  throw "Maintenance token missing required scope: $Scope"
}

# Signature verification placeholder:
# Phase A: verify HMAC over normalized payload JSON using DPAPI-protected key.
# Phase B: call signed helper to verify signature (YubiKey-backed issuance).
if (-not $tok.sigAlg -or -not $tok.signature) {
  throw "Token signature missing."
}

return $true
