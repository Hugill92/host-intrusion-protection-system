<#
.SYNOPSIS
  Ensure a PREINSTALL baseline exists under ProgramData.

.DESCRIPTION
  Creates baseline folder PREINSTALL_YYYYMMDD_HHMMSS with:
    - Firewall-Policy.wfw
    - Firewall-Policy.json
    - Firewall-Policy.thc (optional/placeholder if not implemented yet)
    - Hashes via existing tamper hashing routine (wired by caller)

  Must be called BEFORE applying any FirewallCore rules/policy.

.RETURNS
  PSCustomObject:
    Created (bool)
    BaselinePath (string)
    Reason (string)
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ProgramDataRoot = "C:\ProgramData\FirewallCore",
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-Timestamp { Get-Date -Format "yyyyMMdd_HHmmss" }

$baseRoot = Join-Path $ProgramDataRoot "Baselines"
if (-not (Test-Path $baseRoot)) { New-Item -ItemType Directory -Force -Path $baseRoot | Out-Null }

# Detect existing PREINSTALL baseline
$existing = Get-ChildItem $baseRoot -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like "PREINSTALL_*" } |
  Sort-Object LastWriteTime -Desc |
  Select-Object -First 1

if ($existing -and -not $Force) {
  return [pscustomobject]@{
    Created      = $false
    BaselinePath = $existing.FullName
    Reason       = "baseline-exists"
  }
}

$bundle = Join-Path $baseRoot ("PREINSTALL_{0}" -f (New-Timestamp))
New-Item -ItemType Directory -Force -Path $bundle | Out-Null

$wfw  = Join-Path $bundle "Firewall-Policy.wfw"
$json = Join-Path $bundle "Firewall-Policy.json"
$thc  = Join-Path $bundle "Firewall-Policy.thc"

# 1) Export authoritative firewall policy
# TODO (Codex): implement robust WFAS export command(s) used by project
# Example placeholder:
# netsh advfirewall export "$wfw"
"TODO: export firewall policy" | Set-Content -Path $wfw -Encoding UTF8

# 2) Write inventory JSON
# TODO (Codex): generate structured JSON inventory (rules count, groups, timestamp, machine, user)
@{
  Type      = "PREINSTALL"
  CreatedAt = (Get-Date).ToString("o")
  Computer  = $env:COMPUTERNAME
  User      = $env:USERNAME
  Notes     = "TODO: inventory fields"
} | ConvertTo-Json -Depth 6 | Set-Content -Path $json -Encoding UTF8

# 3) THC (optional)
# TODO (Codex): if THC generator exists, call it. Otherwise write stub and log warning upstream.
"TODO: thc artifact" | Set-Content -Path $thc -Encoding UTF8

return [pscustomobject]@{
  Created      = $true
  BaselinePath = $bundle
  Reason       = "created"
}
