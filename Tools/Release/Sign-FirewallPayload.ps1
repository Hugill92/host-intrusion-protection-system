param(
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$canonical = Join-Path $PSScriptRoot "Sign-FirewallCoreScripts.ps1"
if (-not (Test-Path $canonical)) {
  throw "Canonical signer not found: $canonical"
}

& $canonical @Args
exit $LASTEXITCODE
