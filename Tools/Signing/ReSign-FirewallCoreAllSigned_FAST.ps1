param(
  [string]$RepoRoot = 'C:\FirewallInstaller',
  [switch]$ReportOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FirewallCoreSigningCert {
  $c = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object { $_.Subject -like '*CN=FirewallCore Signature 9C*' -and $_.HasPrivateKey } |
    Sort-Object NotBefore -Descending |
    Select-Object -First 1
  if (-not $c) { throw "Missing working 9C signing cert in Cert:\CurrentUser\My (HasPrivateKey=True). Run your binding step first." }
  return $c
}

function Strip-AuthenticodeIfPresent {
  param([Parameter(Mandatory)][string]$Path)

  $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop

  # Only treat the true Authenticode signature header as the cut-line.
  $hdr = [regex]::Match($raw, '(?m)^[#]\sSIG\s#\sBegin\s(signature\sblock)\s*$')
  if (-not $hdr.Success) { return $false }

  $clean = $raw.Substring(0, $hdr.Index).TrimEnd() + "`r`n"
  Set-Content -LiteralPath $Path -Value $clean -Encoding UTF8 -NoNewline
  return $true
}

function Get-RepoTargets {
  
function Convert-ExcludeToRegex {
  param([Parameter(Mandatory)][string]$Pattern)

  # If it looks like a path-fragment pattern: "\name\" or "/name/" (common in this repo)
  # convert to safe path-segment regex: (^|\\)name(\\|$)
  $t = ($Pattern ?? '').Trim()
  if ([string]::IsNullOrWhiteSpace($t)) { return $t }

  if ($t -match '^[\\/].*[\\/]param([Parameter(Mandatory)][string]$Root)

  $exDirs = @(
    '\.git($|\\)',
    '\.vs($|\\)',
    '(^|\\)bin(\\|$)',
    '(^|\\)obj(\\|$)',
    '\Docs\_local\',
    '\Docs\Old\',
    '\Docs\Archive\',
    '\Tools\Releases\',
    '\Tools\Releases\Deploy\Certs\'
  )

  $items = Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop |
    Where-Object { $_.Extension -in '.ps1','.psm1','.psd1' }

  $filtered = foreach ($i in $items) {
    $p = $i.FullName
    $skip = $false
    foreach ($d in $exDirs) { if ($p -match $d) { $skip = $true; break } }
    if (-not $skip) { $i }
  }

  return $filtered
}

Write-Host "`n=== FirewallCore FAST ReSigner (repo-only) ===" -ForegroundColor Cyan
Write-Host ("[INFO] RepoRoot: {0}" -f $RepoRoot)

$cert = Get-FirewallCoreSigningCert
Write-Host ("[OK] Using cert: Thumbprint={0} Serial={1} NotBefore={2}" -f $cert.Thumbprint,$cert.SerialNumber,$cert.NotBefore) -ForegroundColor Green

# Warmup: prompt PIN once + prime smartcard session
$warm = Join-Path $env:TEMP 'FirewallCore_SignWarmup.ps1'
"Write-Output 'warmup'" | Set-Content -LiteralPath $warm -Encoding UTF8
if (-not $ReportOnly) {
  Write-Host "[WARMUP] One-time PIN prompt may appear now..." -ForegroundColor Yellow
  Set-AuthenticodeSignature -FilePath $warm -Certificate $cert -HashAlgorithm SHA256 | Out-Null
}

$targets = Get-RepoTargets -Root $RepoRoot
Write-Host ("[INFO] Targets: {0}" -f $targets.Count)

$stamped = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportPath = Join-Path (Join-Path $RepoRoot 'Tools\Signing') ("SignReport_{0}.csv" -f $stamped)

$results = New-Object System.Collections.Generic.List[object]
[int]$stripped = 0
[int]$signedOk = 0
[int]$signedFail = 0

foreach ($f in $targets) {
  $path = $f.FullName

  $didStrip = Strip-AuthenticodeIfPresent -Path $path
  if ($didStrip) { $stripped++ }

  if ($ReportOnly) {
    $sig = Get-AuthenticodeSignature -FilePath $path
    $results.Add([pscustomobject]@{
      Path   = $path
      Status = $sig.Status
      Note   = 'ReportOnly'
    })
    continue
  }

  try {
    $r = Set-AuthenticodeSignature -FilePath $path -Certificate $cert -HashAlgorithm SHA256
    $ok = ($r.Status -eq 'Valid')
    if ($ok) { $signedOk++ } else { $signedFail++ }

    $results.Add([pscustomobject]@{
      Path   = $path
      Status = $r.Status
      Note   = $(if($didStrip){'Stripped+Signed'}else{'Signed'})
    })
  }
  catch {
    $signedFail++
    $results.Add([pscustomobject]@{
      Path   = $path
      Status = 'Error'
      Note   = $_.Exception.Message
    })
  }
}

$results | Export-Csv -LiteralPath $reportPath -NoTypeInformation -Encoding UTF8
Write-Host ("`n[OK] Report: {0}" -f $reportPath) -ForegroundColor Green
Write-Host ("[OK] Stripped={0}  SignedValid={1}  Failed={2}" -f $stripped,$signedOk,$signedFail) -ForegroundColor Green

# Show a quick rollup
$results | Group-Object Status | Sort-Object Count -Descending | Format-Table Count,Name -AutoSize



) {
    $seg = $t.Trim('\','/')
    return "(^|\\){0}(\\|$)" -f [regex]::Escape($seg)
  }

  # Otherwise assume it is an intentional regex and leave it as-is
  return $t
}
param([Parameter(Mandatory)][string]$Root)

  $exDirs = @(
    '\.git($|\\)',
    '\.vs($|\\)',
    '(^|\\)bin(\\|$)',
    '(^|\\)obj(\\|$)',
    '\Docs\_local\',
    '\Docs\Old\',
    '\Docs\Archive\',
    '\Tools\Releases\',
    '\Tools\Releases\Deploy\Certs\'
  )

  $items = Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop |
    Where-Object { $_.Extension -in '.ps1','.psm1','.psd1' }

  $filtered = foreach ($i in $items) {
    $p = $i.FullName
    $skip = $false
    foreach ($d in $exDirs) { if ($p -match $d) { $skip = $true; break } }
    if (-not $skip) { $i }
  }

  return $filtered
}

Write-Host "`n=== FirewallCore FAST ReSigner (repo-only) ===" -ForegroundColor Cyan
Write-Host ("[INFO] RepoRoot: {0}" -f $RepoRoot)

$cert = Get-FirewallCoreSigningCert
Write-Host ("[OK] Using cert: Thumbprint={0} Serial={1} NotBefore={2}" -f $cert.Thumbprint,$cert.SerialNumber,$cert.NotBefore) -ForegroundColor Green

# Warmup: prompt PIN once + prime smartcard session
$warm = Join-Path $env:TEMP 'FirewallCore_SignWarmup.ps1'
"Write-Output 'warmup'" | Set-Content -LiteralPath $warm -Encoding UTF8
if (-not $ReportOnly) {
  Write-Host "[WARMUP] One-time PIN prompt may appear now..." -ForegroundColor Yellow
  Set-AuthenticodeSignature -FilePath $warm -Certificate $cert -HashAlgorithm SHA256 | Out-Null
}

$targets = Get-RepoTargets -Root $RepoRoot
Write-Host ("[INFO] Targets: {0}" -f $targets.Count)

$stamped = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportPath = Join-Path (Join-Path $RepoRoot 'Tools\Signing') ("SignReport_{0}.csv" -f $stamped)

$results = New-Object System.Collections.Generic.List[object]
[int]$stripped = 0
[int]$signedOk = 0
[int]$signedFail = 0

foreach ($f in $targets) {
  $path = $f.FullName

  $didStrip = Strip-AuthenticodeIfPresent -Path $path
  if ($didStrip) { $stripped++ }

  if ($ReportOnly) {
    $sig = Get-AuthenticodeSignature -FilePath $path
    $results.Add([pscustomobject]@{
      Path   = $path
      Status = $sig.Status
      Note   = 'ReportOnly'
    })
    continue
  }

  try {
    $r = Set-AuthenticodeSignature -FilePath $path -Certificate $cert -HashAlgorithm SHA256
    $ok = ($r.Status -eq 'Valid')
    if ($ok) { $signedOk++ } else { $signedFail++ }

    $results.Add([pscustomobject]@{
      Path   = $path
      Status = $r.Status
      Note   = $(if($didStrip){'Stripped+Signed'}else{'Signed'})
    })
  }
  catch {
    $signedFail++
    $results.Add([pscustomobject]@{
      Path   = $path
      Status = 'Error'
      Note   = $_.Exception.Message
    })
  }
}

$results | Export-Csv -LiteralPath $reportPath -NoTypeInformation -Encoding UTF8
Write-Host ("`n[OK] Report: {0}" -f $reportPath) -ForegroundColor Green
Write-Host ("[OK] Stripped={0}  SignedValid={1}  Failed={2}" -f $stripped,$signedOk,$signedFail) -ForegroundColor Green

# Show a quick rollup
$results | Group-Object Status | Sort-Object Count -Descending | Format-Table Count,Name -AutoSize




