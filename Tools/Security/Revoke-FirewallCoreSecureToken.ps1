Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$tokenPath = 'C:\ProgramData\FirewallCore\Security\Tokens\Maintenance.token.json'
if (Test-Path -LiteralPath $tokenPath) {
  Remove-Item -LiteralPath $tokenPath -Force
  # TODO: EVTX log: SecurityToken.Revoke.Result
  Write-Host "[OK] Token revoked."
} else {
  Write-Host "[OK] No token present (noop)."
}
