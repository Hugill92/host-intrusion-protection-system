param(
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Scope
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$tokenPath = 'C:\ProgramData\FirewallCore\Security\Tokens\Maintenance.token.json'
if (-not (Test-Path -LiteralPath $tokenPath)) {
  Write-Host "[FAIL] Token missing."
  exit 2
}

$raw = Get-Content -LiteralPath $tokenPath -Raw -ErrorAction Stop
$tok = $raw | ConvertFrom-Json

try {
  if ($tok.payload.schema -ne 'MaintenanceToken.v1') { throw "Schema mismatch." }

  $now = (Get-Date).ToUniversalTime()
  $exp = [datetime]$tok.payload.expiresUtc
  if ($now -ge $exp) { throw "Expired: $($exp.ToString('o')) UTC" }

  if (-not $tok.payload.scopes -or ($tok.payload.scopes -notcontains $Scope)) {
    throw "Scope missing: $Scope"
  }

  if (-not $tok.sigAlg -or -not $tok.signature) { throw "Signature missing." }

  # TODO: Verify signature (Phase A DPAPI+HMAC, Phase B signed helper)
  Write-Host ("[OK] Token valid for scope: {0}" -f $Scope)
  exit 0
} catch {
  Write-Host ("[FAIL] {0}" -f $_.Exception.Message)
  exit 3
}
