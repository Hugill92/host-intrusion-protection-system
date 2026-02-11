# FirewallCore - Signing Shim
# Usage:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File .\Tools\Signing\Sign-FirewallCore.ps1
#   pwsh -NoProfile -ExecutionPolicy Bypass -File .\Tools\Signing\Sign-FirewallCore.ps1 -AlsoSignLive

param(
  [switch]$AlsoSignLive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "`n=== FirewallCore: Sign Shim ===" -ForegroundColor Cyan

# This file is: <repo>\Tools\Signing\Sign-FirewallCore.ps1
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$signer   = Join-Path $repoRoot 'Tools\Signing\ReSign-FirewallCoreAllSigned.ps1'
if (-not (Test-Path -LiteralPath $signer)) { throw "Missing signer tool: $signer" }

Write-Host ("[INFO] RepoRoot: {0}" -f $repoRoot) -ForegroundColor DarkCyan
Write-Host ("[INFO] Signer:  {0}" -f $signer)   -ForegroundColor DarkCyan
Write-Host ("[INFO] AlsoSignLive requested: {0}" -f $AlsoSignLive.IsPresent) -ForegroundColor DarkCyan

# IMPORTANT: Only pass -AlsoSignLive if user requested it.
# IMPORTANT: Only pass -AlsoSignLive if user requested it.
# Also IMPORTANT: enforce signer exit code (external pwsh) and fail loud if signer fails.
$pwshArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $signer)
if ($AlsoSignLive.IsPresent) { $pwshArgs += @('-AlsoSignLive') }

Write-Host ("[INFO] Invoking signer: pwsh {0}" -f ($pwshArgs -join ' ')) -ForegroundColor DarkCyan
$signOut = & pwsh @pwshArgs 2>&1
$signOut | Out-Host

if ($LASTEXITCODE -ne 0) {
  throw ("Signer FAILED (exit={0}). See output above." -f $LASTEXITCODE)
}

Write-Host "`n[OK] Sign shim completed." -ForegroundColor Green

