Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$Signed9CCer
)

function Pick-Latest {
  param([string]$Dir,[string]$Name)
  if (-not (Test-Path -LiteralPath $Dir)) { return $null }
  $c = Get-ChildItem -LiteralPath $Dir -Filter $Name -Recurse -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($c) { return $c.FullName }
  return $null
}

if (-not $Signed9CCer) {
  $base = Join-Path $env:USERPROFILE 'Documents\YubiPIV'
  $guess = Pick-Latest -Dir (Join-Path $base 'Certs\Deploy') -Name 'FirewallCore_CodeSigning_9C.cer'
  if (-not $guess) { $guess = Pick-Latest -Dir $base -Name '9c_signed.cer' }
  $Signed9CCer = $guess
}

if (-not $Signed9CCer -or -not (Test-Path -LiteralPath $Signed9CCer)) {
  throw "Could not locate Signed9CCer. Provide -Signed9CCer <path to FirewallCore_CodeSigning_9C.cer>."
}

Write-Host ''
Write-Host '=== Bind 9C CodeSigning Cert to YubiKey Private Key (Windows Gate) ==='
Write-Host ("9C CER: {0}" -f $Signed9CCer)
Write-Host ''

Write-Host '[STEP] 1) Import 9C cert into CurrentUser\My'
Import-Certificate -FilePath $Signed9CCer -CertStoreLocation 'Cert:\CurrentUser\My' | Out-Host

Write-Host '[STEP] 2) Select newest Code Signing cert in CurrentUser\My'
$cs = Get-ChildItem 'Cert:\CurrentUser\My' | Where-Object {
  $_.EnhancedKeyUsageList.ObjectId -contains '1.3.6.1.5.5.7.3.3'
} | Sort-Object NotAfter -Descending | Select-Object -First 1

if (-not $cs) { throw 'No Code Signing cert found in CurrentUser\My after import.' }

$cs | Format-List Subject,Thumbprint,SerialNumber,NotAfter,HasPrivateKey

Write-Host '[STEP] 3) Smart-card health check (expect OK after slots have certs)'
certutil -scinfo | Out-Host

Write-Host '[STEP] 4) Bind via certutil repairstore (PIN + touch prompt)'
Write-Host ('Running: certutil -user -repairstore My {0}' -f $cs.SerialNumber)
certutil -user -repairstore My $cs.SerialNumber | Out-Host

Write-Host '[STEP] 5) Verify Provider/Key Container + HasPrivateKey=True'
$bound = Get-Item ("Cert:\CurrentUser\My\{0}" -f $cs.Thumbprint)
$bound | Select-Object Subject,Thumbprint,HasPrivateKey,NotAfter | Format-List
certutil -user -store My $cs.Thumbprint | Out-Host

if (-not $bound.HasPrivateKey) {
  throw 'HasPrivateKey=False. Replug YubiKey, Restart-Service SCardSvr, run certutil -scinfo, then rerun this script.'
}

Write-Host '[STEP] 6) Smoke-sign (must end Status=Valid)'
$smokeDir = Join-Path $env:USERPROFILE 'Documents\YubiPIV\Smoke'
New-Item -ItemType Directory -Force -Path $smokeDir | Out-Null
$target = Join-Path $smokeDir 'sign_test.ps1'
Set-Content -LiteralPath $target -Value "Write-Host 'FirewallCore signing smoke test OK'" -Encoding UTF8

Set-AuthenticodeSignature -FilePath $target -Certificate $bound -HashAlgorithm SHA256 | Out-Host
$sig = Get-AuthenticodeSignature -FilePath $target
$sig | Format-List Status,StatusMessage,SignerCertificate

if ($sig.Status -ne 'Valid') {
  throw "Smoke-sign failed (Status=$($sig.Status))."
}

Write-Host ''
Write-Host '[OK] Binding + signing succeeded.'
