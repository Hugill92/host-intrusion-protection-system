<#
One-command “release freeze”.
1) Signs all scripts
2) Builds payload manifest
3) Verifies signatures + manifest sanity
#>

[CmdletBinding()]
param(
  [string]$Root = "C:\Firewall",
  [string]$Thumbprint = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function STEP($m){ Write-Host "[*] $m" }
function OK($m){ Write-Host "[OK] $m" }

# -----------------------------
# Resolve Release tools CORRECTLY
# -----------------------------
$ReleaseRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$sign = Join-Path $ReleaseRoot "Sign-FirewallPayload.ps1"
$man  = Join-Path $ReleaseRoot "Build-FileManifest.ps1"

if (-not (Test-Path $sign)) { throw "Missing: $sign" }
if (-not (Test-Path $man))  { throw "Missing: $man"  }

# -----------------------------
# 1/3 Sign payload
# -----------------------------
STEP "1/3 Signing Firewall payload..."
& $sign -Root $Root -Thumbprint $Thumbprint

# -----------------------------
# 2/3 Build manifest
# -----------------------------
STEP "2/3 Building manifest..."
$out = Join-Path $Root "Golden\payload.manifest.sha256.json"
& $man -Root $Root -OutFile $out

# -----------------------------
# 3/3 Verify signatures
# -----------------------------
STEP "3/3 Verifying signatures..."

$bad = Get-ChildItem $Root -Recurse -File -Force |
  Where-Object { $_.Extension -in ".ps1",".psm1",".psd1" } |
  ForEach-Object {
    $s = Get-AuthenticodeSignature -FilePath $_.FullName
    if ($s.Status -ne "Valid") { $_.FullName }
  }

if ($bad) {
  throw ("Some scripts are not Valid-signed:`n" + ($bad -join "`n"))
}

OK "Golden freeze complete."
OK "Manifest written to:"
OK "  $out"
