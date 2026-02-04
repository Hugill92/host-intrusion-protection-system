<#
.SYNOPSIS
  Ensure a PREINSTALL baseline exists under ProgramData.

.DESCRIPTION
  Creates baseline folder PREINSTALL_YYYYMMDD_HHMMSS with:
    - Firewall-Policy.wfw
    - Firewall-Policy.json
    - Firewall-Policy.thc (optional/placeholder if not implemented yet)
    - SHA256SUMS.txt + BaselineManifest.json (deterministic hashing evidence)

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

function Get-Sha256Hex {
  param([Parameter(Mandatory)][string]$Path)
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Write-Sha256Sums {
  param(
    [Parameter(Mandatory)][string]$Folder,
    [Parameter(Mandatory)][string[]]$Files
  )
  $out = Join-Path $Folder "SHA256SUMS.txt"

  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($f in $Files) {
    $p = Join-Path $Folder $f
    if (-not (Test-Path $p)) { throw ("Hash target missing: " + $p) }
    $h = Get-Sha256Hex -Path $p
    $lines.Add(("{0}  {1}" -f $h, $f))
  }

  $lines | Set-Content -Path $out -Encoding ASCII
  return $out
}

function Write-Manifest {
  param(
    [Parameter(Mandatory)][string]$Folder,
    [Parameter(Mandatory)][hashtable]$Meta,
    [Parameter(Mandatory)][string[]]$Files
  )
  $manifestPath = Join-Path $Folder "BaselineManifest.json"

  $items = @()
  foreach ($f in $Files) {
    $p = Join-Path $Folder $f
    $fi = Get-Item -LiteralPath $p
    $items += [pscustomobject]@{
      Name   = $f
      Bytes  = [int64]$fi.Length
      Sha256 = (Get-Sha256Hex -Path $p)
    }
  }

  $obj = [ordered]@{
    Type      = $Meta.Type
    CreatedAt = $Meta.CreatedAt
    Computer  = $Meta.Computer
    User      = $Meta.User
    Notes     = $Meta.Notes
    Files     = $items
  }

  ($obj | ConvertTo-Json -Depth 8) | Set-Content -Path $manifestPath -Encoding UTF8
  return $manifestPath
}

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
# TODO (Codex): replace placeholder with project-authoritative export (netsh or WFAS export)
"TODO: export firewall policy" | Set-Content -Path $wfw -Encoding UTF8

# 2) Write inventory JSON (minimum viable)
$meta = @{
  Type      = "PREINSTALL"
  CreatedAt = (Get-Date).ToString("o")
  Computer  = $env:COMPUTERNAME
  User      = $env:USERNAME
  Notes     = "THC may be stubbed until generator is wired; export method may be placeholder until replaced."
}

($meta | ConvertTo-Json -Depth 6) | Set-Content -Path $json -Encoding UTF8

# 3) THC (optional)
# TODO (Codex): if THC generator exists, call it. Otherwise keep stub and ensure uninstall logs WARN.
"TODO: thc artifact" | Set-Content -Path $thc -Encoding UTF8

# 4) Deterministic hashing evidence inside the bundle
$files = @("Firewall-Policy.wfw","Firewall-Policy.json","Firewall-Policy.thc")
$null = Write-Sha256Sums -Folder $bundle -Files $files
$null = Write-Manifest   -Folder $bundle -Meta $meta -Files $files

return [pscustomobject]@{
  Created      = $true
  BaselinePath = $bundle
  Reason       = "created"
}
