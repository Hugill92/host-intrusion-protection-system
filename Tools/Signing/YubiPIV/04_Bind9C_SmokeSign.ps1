param(
  [string]$BaseDir = (Join-Path $env:USERPROFILE 'Documents\YubiPIV'),
  [string]$Signed9CCer
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Pick-Latest([string]$Dir,[string]$Name) {
  if (-not (Test-Path -LiteralPath $Dir)) { return $null }
  $c = Get-ChildItem -LiteralPath $Dir -Filter $Name -Recurse -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($c) { return $c.FullName }
  return $null
}

if (-not $Signed9CCer) {
  $Signed9CCer = Pick-Latest -Dir (Join-Path $BaseDir 'Certs\Deploy') -Name 'FirewallCore_CodeSigning_9C.cer'
}
if (-not $Signed9CCer -or -not (Test-Path -LiteralPath $Signed9CCer)) {
  throw "Missing -Signed9CCer. Expected Deploy file: FirewallCore_CodeSigning_9C.cer"
}

Write-Host ''
Write-Host '=== Bind 9C CodeSigning Cert to YubiKey Private Key (Windows Gate) ==='
Write-Host ("9C CER: {0}" -f $Signed9CCer)
Write-Host ''

Write-Host '[STEP] Import 9C cert into CurrentUser\My'
Import-Certificate -FilePath $Signed9CCer -CertStoreLocation 'Cert:\CurrentUser\My' | Out-Host

$fileObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($Signed9CCer)
$thumb   = $fileObj.Thumbprint

$cs = Get-Item ("Cert:\CurrentUser\My\{0}" -f $thumb) -ErrorAction SilentlyContinue
if (-not $cs) { throw "Imported cert not found in CurrentUser\My by thumbprint: $thumb" }

Write-Host '[STEP] Bind via certutil repairstore (PIN + touch will be requested)'
certutil -user -repairstore My $cs.SerialNumber | Out-Host

Write-Host '[STEP] Verify HasPrivateKey=True'
$bound = Get-Item ("Cert:\CurrentUser\My\{0}" -f $thumb)
$bound | Select-Object Subject,Thumbprint,HasPrivateKey,NotAfter | Format-List
certutil -user -store My $thumb | Out-Host

if (-not $bound.HasPrivateKey) {
  throw 'HasPrivateKey=False. Replug YubiKey, Restart-Service SCardSvr, rerun this script.'
}

Write-Host '[STEP] Smoke-sign (must be Valid)'
$smokeDir = Join-Path $BaseDir 'Smoke'
New-Item -ItemType Directory -Force -Path $smokeDir | Out-Null
$target = Join-Path $smokeDir 'sign_test.ps1'
Set-Content -LiteralPath $target -Value "Write-Host 'FirewallCore signing smoke test OK'" -Encoding UTF8

Set-AuthenticodeSignature -FilePath $target -Certificate $bound -HashAlgorithm SHA256 | Out-Host
$sig = Get-AuthenticodeSignature -FilePath $target
$sig | Format-List Status,StatusMessage,SignerCertificate

if ($sig.Status -ne 'Valid') { throw "Smoke-sign failed (Status=$($sig.Status))" }

Write-Host ''
Write-Host '[OK] Binding + signing succeeded.'
