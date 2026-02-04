Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-FwRuleFingerprint {
  [CmdletBinding()]
  param([string]$PolicyStore = "ActiveStore")

  try {
    $rules = Get-NetFirewallRule -PolicyStore $PolicyStore -ErrorAction Stop
  } catch {
    return [pscustomobject]@{ PolicyStore=$PolicyStore; Count = -1; Sha256 = "<error>"; Error = $_.Exception.Message }
  }

  $lines = foreach ($r in $rules) {
    "{0}|{1}|{2}|{3}|{4}|{5}" -f $r.DisplayName, $r.Direction, $r.Action, $r.Enabled, $r.Profile, $r.Group
  }

  $sorted = $lines | Sort-Object
  $joined = ($sorted -join "`n")

  $sha = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
  $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
  $sha.Dispose()

  [pscustomobject]@{ PolicyStore=$PolicyStore; Count = $lines.Count; Sha256 = $hash; Error = $null }
}

function Get-Sha256Hex {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function New-FirewallBaselineManifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$BaselineDir,
    [Parameter(Mandatory)][string[]]$Files,
    [string]$Type = "PREINSTALL",
    [string]$PolicyStore = "ActiveStore",
    [string[]]$Warnings = @()
  )

  $manifestPath = Join-Path $BaselineDir "FirewallBaseline.manifest.sha256.json"

  $items = @()
  foreach ($f in $Files) {
    $p = Join-Path $BaselineDir $f
    if (-not (Test-Path $p)) { throw ("Manifest target missing: " + $p) }
    $fi = Get-Item -LiteralPath $p
    $items += [pscustomobject]@{
      Name   = $f
      Bytes  = [int64]$fi.Length
      Sha256 = (Get-Sha256Hex -Path $p)
    }
  }

  $fp = Get-FwRuleFingerprint -PolicyStore $PolicyStore

  $obj = [ordered]@{
    Type      = $Type
    CreatedAt = (Get-Date).ToString("o")
    Computer  = $env:COMPUTERNAME
    User      = $env:USERNAME
    Warnings  = $Warnings
    Files     = $items
    FirewallFingerprint = [ordered]@{
      PolicyStore = $fp.PolicyStore
      Count       = $fp.Count
      Sha256      = $fp.Sha256
      Error       = $fp.Error
    }
  }

  ($obj | ConvertTo-Json -Depth 10) | Set-Content -Path $manifestPath -Encoding UTF8
  return $manifestPath
}

function Test-FirewallBaselineManifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$BaselineDir,
    [string]$PolicyStore = "ActiveStore"
  )

  $manifestPath = Join-Path $BaselineDir "FirewallBaseline.manifest.sha256.json"
  if (-not (Test-Path $manifestPath)) {
    return [pscustomobject]@{ Ok=$false; Failures=@("Missing manifest: FirewallBaseline.manifest.sha256.json"); ManifestPath=$manifestPath }
  }

  $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  $fail = New-Object System.Collections.Generic.List[string]

  foreach ($it in $m.Files) {
    $p = Join-Path $BaselineDir $it.Name
    if (-not (Test-Path $p)) { $fail.Add(("Missing file: " + $it.Name)); continue }
    $h = (Get-Sha256Hex -Path $p)
    if ($h -ne ($it.Sha256.ToString().ToLowerInvariant())) {
      $fail.Add(("Hash mismatch: {0}" -f $it.Name))
    }
  }

  $fpNow = Get-FwRuleFingerprint -PolicyStore $PolicyStore
  if ($m.FirewallFingerprint -and $m.FirewallFingerprint.Sha256) {
    $expect = $m.FirewallFingerprint.Sha256.ToString().ToLowerInvariant()
    if ($fpNow.Sha256 -ne $expect) {
      $fail.Add("Firewall fingerprint mismatch (ActiveStore changed)")
    }
  } else {
    $fail.Add("Manifest missing FirewallFingerprint.Sha256")
  }

  return [pscustomobject]@{
    Ok         = ($fail.Count -eq 0)
    Failures   = $fail
    ManifestPath = $manifestPath
    FingerprintNow = $fpNow
  }
}

Export-ModuleMember -Function Get-FwRuleFingerprint,New-FirewallBaselineManifest,Test-FirewallBaselineManifest
