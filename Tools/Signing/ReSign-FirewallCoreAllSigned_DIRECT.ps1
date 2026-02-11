param(
  [string]$Root = 'C:\FirewallInstaller',
  [switch]$IncludeLocalDocs,
  [switch]$IncludeOld
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsCodeSigningCert {
  param([Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert)
  if (-not $Cert.HasPrivateKey) { return $false }
  foreach ($ext in $Cert.Extensions) {
    if ($ext -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]) {
      foreach ($oid in $ext.EnhancedKeyUsages) {
        if ($oid.Value -eq '1.3.6.1.5.5.7.3.3') { return $true } # Code Signing EKU
      }
    }
  }
  return $false
}

function Get-CodeSigningCert {
  $cert = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object { Test-IsCodeSigningCert $_ } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1
  if (-not $cert) { throw "No Code Signing cert with private key found in Cert:\CurrentUser\My" }
  return $cert
}

function Strip-AuthenticodeBlock {
  param([Parameter(Mandatory)][string]$Path)
  $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
  $m = [regex]::Match($raw, '(?m)^\s*# SIG # Begin signature block\s*$')
  if (-not $m.Success) { return $false }
  $clean = $raw.Substring(0, $m.Index).TrimEnd() + "`r`n"
  Set-Content -LiteralPath $Path -Value $clean -Encoding UTF8
  return $true
}

Write-Host "`n=== DIRECT SIGN (NO resigner scripts) ===" -ForegroundColor Cyan
Write-Host ("[INFO] Root: {0}" -f $Root) -ForegroundColor Cyan

$cert = Get-CodeSigningCert
Write-Host ("[OK] Using cert: Thumbprint={0}  NotAfter={1}" -f $cert.Thumbprint, $cert.NotAfter) -ForegroundColor Green
Write-Host "[INFO] Expect ONE PIN/touch prompt during signing." -ForegroundColor Yellow

$exclude = '\\(\.git|\.vs|\.vscode)\\'
if (-not $IncludeLocalDocs) { $exclude += '|\\Docs\\_local\\' }
if (-not $IncludeOld)      { $exclude += '|\\Old\\' }

$targets = Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop |
  Where-Object { $_.Extension -in '.ps1','.psm1','.psd1' } |
  Where-Object { $_.FullName -notmatch $exclude }

Write-Host ("[INFO] Targets: {0}" -f $targets.Count) -ForegroundColor Cyan

$ok=0; $fail=0; $locked=0; $stripped=0
$failList   = New-Object System.Collections.Generic.List[string]
$lockedList = New-Object System.Collections.Generic.List[string]

foreach ($f in $targets) {
  try {
    Unblock-File -LiteralPath $f.FullName -ErrorAction SilentlyContinue

    if (($f.Attributes -band [IO.FileAttributes]::ReadOnly) -ne 0) {
      $f.Attributes = ($f.Attributes -bxor [IO.FileAttributes]::ReadOnly)
    }

    if (Strip-AuthenticodeBlock -Path $f.FullName) { $stripped++ }

    $sig = Set-AuthenticodeSignature -FilePath $f.FullName -Certificate $cert -HashAlgorithm SHA256 -ErrorAction Stop
    if ($sig.Status -ne 'Valid') { throw ("Signature status: {0}" -f $sig.Status) }

    $ok++
  } catch {
    $msg = ($_.Exception.Message + '')
    if ($msg -match 'cannot access the file|being used by another process') {
      $locked++
      $lockedList.Add($f.FullName) | Out-Null
    } else {
      $fail++
      $failList.Add($f.FullName) | Out-Null
    }
  }
}

Write-Host ("`n[OK] Signed: {0}  StrippedOldBlocks: {1}  Locked: {2}  Failed: {3}" -f $ok,$stripped,$locked,$fail) -ForegroundColor Green

if ($locked -gt 0) {
  Write-Host "`n=== LOCKED ===" -ForegroundColor Yellow
  $lockedList | Sort-Object | Out-Host
}
if ($fail -gt 0) {
  Write-Host "`n=== FAILED ===" -ForegroundColor Red
  $failList | Sort-Object | Out-Host
}
