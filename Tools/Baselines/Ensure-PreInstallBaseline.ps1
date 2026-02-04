<#
.SYNOPSIS
  Ensure a PREINSTALL baseline exists under ProgramData.

.DESCRIPTION
  Creates baseline folder PREINSTALL_YYYYMMDD_HHMMSS with:
    - Firewall-Policy.wfw
    - Firewall-Policy.json
    - Firewall-Policy.thc (optional/placeholder if not implemented yet)
    
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
- SHA256SUMS.txt + BaselineManifest.json (deterministic hashing evidence)

  
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
Must be called BEFORE applying any FirewallCore rules/policy.

.RETURNS
  PSCustomObject:
    Created (bool)
    
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
BaselinePath (string)
    
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
Reason (string)

$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
#>

[CmdletBinding()
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
]
param(
  [Parameter(Mandatory)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
][string]$ProgramDataRoot = "C:\ProgramData\FirewallCore",
  [switch]$Force
)


$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-Timestamp { Get-Date -Format "yyyyMMdd_HHmmss" }

function Get-Sha256Hex {
  param([Parameter(Mandatory)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
][string]$Path)
  
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
.Hash.ToLowerInvariant()

$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
}

function Write-Sha256Sums {
  param(
    [Parameter(Mandatory)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
][string]$Folder,
    [Parameter(Mandatory)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
][string[]]$Files
  )
  
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
$out = Join-Path $Folder "SHA256SUMS.txt"

  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($f in $Files) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
{
    $p = Join-Path $Folder $f
    if (-not (Test-Path $p)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
{ throw ("Hash target missing: " + $p) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
}
    $h = Get-Sha256Hex -Path $p
    $lines.Add(("{0}  {1}" -f $h, $f)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
)
  
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
}

  $lines | Set-Content -Path $out -Encoding ASCII
  return $out
}

function Write-Manifest {
  param(
    [Parameter(Mandatory)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
][string]$Folder,
    [Parameter(Mandatory)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
][hashtable]$Meta,
    [Parameter(Mandatory)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
][string[]]$Files
  )
  
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
$manifestPath = Join-Path $Folder "BaselineManifest.json"

  $items = @()
  
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
foreach ($f in $Files) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
{
    $p = Join-Path $Folder $f
    $fi = Get-Item -LiteralPath $p
    $items += [pscustomobject]@{
      Name   = $f
      Bytes  = [int64]$fi.Length
      Sha256 = (Get-Sha256Hex -Path $p)
    
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
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

  ($obj | ConvertTo-Json -Depth 8) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
| Set-Content -Path $manifestPath -Encoding UTF8
  return $manifestPath
}

$baseRoot = Join-Path $ProgramDataRoot "Baselines"
if (-not (Test-Path $baseRoot)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
{ New-Item -ItemType Directory -Force -Path $baseRoot | Out-Null }

# Detect existing PREINSTALL baseline
$existing = Get-ChildItem $baseRoot -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like "PREINSTALL_*" } |
  Sort-Object LastWriteTime -Desc |
  Select-Object -First 1

if ($existing -and -not $Force) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
{
  return [pscustomobject]@{
    Created      = $false
    BaselinePath = $existing.FullName
    Reason       = "baseline-exists"
  }
}

$bundle = Join-Path $baseRoot ("PREINSTALL_{0}" -f (New-Timestamp)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
)

$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
New-Item -ItemType Directory -Force -Path $bundle | Out-Null

$wfw  = Join-Path $bundle "Firewall-Policy.wfw"
$json = Join-Path $bundle "Firewall-Policy.json"
$thc  = Join-Path $bundle "Firewall-Policy.thc"

# 1) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
Export authoritative firewall policy
# TODO (Codex)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
: replace placeholder with project-authoritative export (netsh or WFAS export)

$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
"TODO: export firewall policy" | Set-Content -Path $wfw -Encoding UTF8

# 2) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
Write inventory JSON (minimum viable)

$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
$meta = @{
  Type      = "PREINSTALL"
  CreatedAt = (Get-Date)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
.ToString("o")
  
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
Computer  = $env:COMPUTERNAME
  User      = $env:USERNAME
  Notes     = "THC may be stubbed until generator is wired; export method may be placeholder until replaced."
}

($meta | ConvertTo-Json -Depth 6) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
| Set-Content -Path $json -Encoding UTF8

# 3) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
THC (optional)

$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
# TODO (Codex)
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
: if THC generator exists, call it. Otherwise keep stub and ensure uninstall logs WARN.
"TODO: thc artifact" | Set-Content -Path $thc -Encoding UTF8

# 4) 
$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
Deterministic hashing evidence inside the bundle
$files = @("Firewall-Policy.wfw","Firewall-Policy.json","Firewall-Policy.thc")

$here = Split-Path -Parent $(\System.Management.Automation.InvocationInfo.MyCommand.Path)
$repo = Split-Path -Parent $(Split-Path -Parent $here)
Import-Module (Join-Path $repo 'Tools\Modules\FirewallBaseline.psm1') -Force
$null = Write-Sha256Sums -Folder $bundle -Files $files
$null = Write-Manifest   -Folder $bundle -Meta $meta -Files $files

return [pscustomobject]@{
  Created      = $true
  BaselinePath = $bundle
  Reason       = "created"
}

