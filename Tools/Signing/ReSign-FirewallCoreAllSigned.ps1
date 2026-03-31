[CmdletBinding()]
param()
Set-StrictMode -Off
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [switch]$AlsoSignLive,
  [string]$Thumbprint
)

function Assert-ParseOk {
  param([Parameter(Mandatory)][string]$LiteralPath)
  $t = $null; $e = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($LiteralPath, [ref]$t, [ref]$e)
  if ($e -and $e.Count -gt 0) {
    $first = $e[0]
    throw ("Parse failed: {0} at line {1}, col {2} :: {3}" -f $LiteralPath, $first.Extent.StartLineNumber, $first.Extent.StartColumnNumber, $first.Message)
  }
}

function Strip-AuthenticodeSignatureBlock {
  param([Parameter(Mandatory)][string]$LiteralPath)

  $content = Get-Content -LiteralPath $LiteralPath -Raw -ErrorAction Stop

  # Only strip a real Authenticode block. Match the canonical header line EXACTLY.
  $sigHeader = [regex]'(?m)^[#]\sSIG\s#\sBegin\ssignature\sblock\s*$'
  $m = $sigHeader.Match($content)
  if (-not $m.Success) { return $false }

  $new = $content.Substring(0, $m.Index).TrimEnd() + [Environment]::NewLine
  Set-Content -LiteralPath $LiteralPath -Value $new -Encoding UTF8 -NoNewline
  return $true
}

function Get-CodeSigningCert {
  param([string]$Thumbprint)

  if ($Thumbprint) {
    $c = Get-Item -LiteralPath ("Cert:\CurrentUser\My\{0}" -f $Thumbprint) -ErrorAction SilentlyContinue
    if (-not $c) { throw ("Cert not found in CurrentUser\My: {0}" -f $Thumbprint) }
    return $c
  }

  # Fallback: pick newest Code Signing cert in CurrentUser\My.
  $cands = Get-ChildItem Cert:\CurrentUser\My -ErrorAction Stop |
    Where-Object {
      $_.EnhancedKeyUsageList | Where-Object { $_.ObjectId.Value -eq '1.3.6.1.5.5.7.3.3' }
    } |
    Sort-Object NotAfter -Descending

  $c = $cands | Select-Object -First 1
  if (-not $c) { throw 'No Code Signing cert found in Cert:\CurrentUser\My' }
  return $c
}

function Sign-One {
  param(
    [Parameter(Mandatory)][string]$LiteralPath,
    [Parameter(Mandatory)]$Cert
  )

  try { Unblock-File -LiteralPath $LiteralPath -ErrorAction SilentlyContinue } catch {}

  $null = Strip-AuthenticodeSignatureBlock -LiteralPath $LiteralPath

  $r = Set-AuthenticodeSignature -FilePath $LiteralPath -Certificate $Cert -HashAlgorithm SHA256
  if (-not $r -or $r.Status -ne 'Valid') {
    $s = Get-AuthenticodeSignature -LiteralPath $LiteralPath
    throw ("Sign failed: {0} :: {1}" -f $s.Status, $s.StatusMessage)
  }
}

Write-Host ''
Write-Host '=== ReSign-FirewallCoreAllSigned ==='
Write-Host ("PS: {0}" -f $PSVersionTable.PSVersion)

$repoRoot = (Get-Location).Path
$targets = New-Object System.Collections.Generic.List[string]

# Repo targets (exclude local-only + Old + archives)
$includeExt = @('*.ps1','*.psm1','*.psd1')
$excludeDirs = @(
  (Join-Path $repoRoot 'Docs\_local'),
  (Join-Path $repoRoot 'Old'),
  (Join-Path $repoRoot 'Docs\_archive')
)

foreach ($pat in $includeExt) {
  Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Filter $pat -ErrorAction Stop | ForEach-Object {
    $full = $_.FullName

    foreach ($xd in $excludeDirs) {
      if ($full.StartsWith($xd, [System.StringComparison]::OrdinalIgnoreCase)) { return }
    }

    $targets.Add($full)
  }
}

# Ensure tool signs itself last (avoid self-truncation risks)
$toolPath = $MyInvocation.MyCommand.Path
$targets = $targets | Where-Object { $_ -ne $toolPath }
$targets = @($targets) + @($toolPath)

$cert = Get-CodeSigningCert -Thumbprint $Thumbprint
Write-Host ("Cert: {0}  Thumbprint={1}  Expires={2:yyyy-MM-dd}" -f $cert.Subject, $cert.Thumbprint, $cert.NotAfter)

# Parse gate on tool itself (and optionally everything else if you want later)
Assert-ParseOk -LiteralPath $toolPath

[int]$stripped = 0
[int]$signed = 0

foreach ($f in $targets) {
  $before = Get-AuthenticodeSignature -LiteralPath $f
  if (Strip-AuthenticodeSignatureBlock -LiteralPath $f) { $stripped++ }

  # Re-parse after strip (catches accidental truncation)
  Assert-ParseOk -LiteralPath $f

  Sign-One -LiteralPath $f -Cert $cert
  $signed++
}

Write-Host ("Done. Stripped={0} Signed={1} Targets={2}" -f $stripped, $signed, $targets.Count)

if ($AlsoSignLive) {
  Write-Host ''
  Write-Host 'NOTE: -AlsoSignLive requested, but live signing is intentionally not implemented here.'
  Write-Host '      Keep repo as source of truth; deploy-to-live should copy already-signed artifacts.'
}


