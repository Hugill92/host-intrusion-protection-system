<#
Builds a SHA256 manifest for all payload files.
Outputs JSON with paths relative to root.
Recommended output path:
  C:\Firewall\Golden\payload.manifest.sha256.json
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$Root = "C:\Firewall",

  [string]$OutFile = "C:\Firewall\Golden\payload.manifest.sha256.json",

  # What to include
  [string[]]$IncludeExtensions = @(".ps1",".psm1",".psd1",".cmd",".bat",".json",".md",".txt",".cer",".count",".hash"),

  # Optional: exclude transient logs/state
  [string[]]$ExcludePathContains = @("\Logs\", "\State\wfp.bookmark.json", "\State\wfp.strikes.json", "\State\wfp.blocked.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function STEP($m){ Write-Host "[*] $m" }
function OK($m){ Write-Host "[OK] $m" }

$rootFull = (Resolve-Path $Root).Path
STEP "Building manifest for: $rootFull"

$files = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force |
  Where-Object { $IncludeExtensions -contains $_.Extension.ToLowerInvariant() }

# Exclusions (by substring match)
if ($ExcludePathContains.Count -gt 0) {
  $files = $files | Where-Object {
    $p = $_.FullName
    -not ($ExcludePathContains | Where-Object { $p -like "*$_*" })
  }
}

STEP ("Hashing {0} files..." -f $files.Count)

$items = foreach ($f in $files) {
  $rel = $f.FullName.Substring($rootFull.Length).TrimStart("\")
  $h = (Get-FileHash -Algorithm SHA256 -Path $f.FullName).Hash
  [pscustomobject]@{
    Path = $rel
    Sha256 = $h
    Size = $f.Length
    LastWriteTimeUtc = $f.LastWriteTimeUtc.ToString("o")
  }
}

$manifest = [pscustomobject]@{
  Schema = "FirewallPayloadManifest.v1"
  Root   = $rootFull
  BuiltAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  Count  = $items.Count
  Items  = $items | Sort-Object Path
}

New-Item -ItemType Directory -Path (Split-Path $OutFile -Parent) -Force | Out-Null
$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding UTF8

OK "Manifest written: $OutFile"
