[CmdletBinding()]
param()
#requires -Version 5.1
<#
.SYNOPSIS
  FirewallCore AllSigned re-sign wrapper (repo-first; optional live roots).

.DESCRIPTION
  Thin wrapper that:
  - Derives RepoRoot from $PSScriptRoot (never current directory)
  - Validates canonical uninstaller path under repo root
  - Invokes Tools\Sign-AllFirewallCore.ps1 (canonical signer)

.PARAMETER AlsoSignLive
  If set, also signs known live roots (best-effort, only if present).

.NOTES
  Exit codes:
    0 = success
    2 = environment / missing prerequisites
    3 = signing/verification failure
#>

param(
  [switch]$AlsoSignLive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
  $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

  $engine = Join-Path $RepoRoot '_internal\Uninstall-FirewallCore.ps1'
  if (-not (Test-Path -LiteralPath $engine)) {
    Write-Error ("Missing canonical uninstaller: {0}" -f $engine)
    exit 2
  }

  $signer = Join-Path $PSScriptRoot 'Sign-AllFirewallCore.ps1'
  if (-not (Test-Path -LiteralPath $signer)) {
    Write-Error ("Missing canonical signer: {0}" -f $signer)
    exit 2
  }

  $also = @()
  if ($AlsoSignLive) {
    $candidates = @(
      'C:\Firewall',
      'C:\ProgramData\FirewallCore\User',
      'C:\ProgramData\FirewallCore\System'
    )
    foreach ($p in $candidates) {
      try {
        if (Test-Path -LiteralPath $p) { $also += $p }
      } catch {}
    }
  }

  & $signer -Root $RepoRoot -AlsoSign $also -ExcludePaths @($PSCommandPath)
  exit $LASTEXITCODE
} catch {
  Write-Error $_.Exception.Message
  exit 2
}

