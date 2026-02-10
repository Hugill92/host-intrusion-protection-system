param(
  [string]$BaseDir = (Join-Path $env:USERPROFILE 'Documents\YubiPIV'),
  [string]$Country = 'US',
  [string]$Org     = 'BrexitSecurity',
  [string]$OrgUnit = 'FirewallCore',
  [string]$CommonName = 'FirewallCore Offline Root CA',
  [int]$KeyBits = 4096,
  [int]$Years  = 15,
  [switch]$ForceNew
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-OpenSSL {
  $cmd = Get-Command openssl -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  foreach ($c in @(
    'C:\Program Files\OpenSSL-Win64\bin\openssl.exe',
    'C:\Program Files\OpenSSL-Win32\bin\openssl.exe'
  )) { if (Test-Path -LiteralPath $c) { return $c } }
  throw 'openssl.exe not found (install OpenSSL or add to PATH).'
}

$openssl = Resolve-OpenSSL

$caDir = Join-Path $BaseDir 'OfflineRootCA'
New-Item -ItemType Directory -Force -Path $caDir | Out-Null

$key = Join-Path $caDir 'OfflineRootCA.key'
$crt = Join-Path $caDir 'OfflineRootCA.crt'
$cer = Join-Path $caDir 'OfflineRootCA.cer'

$subj = "/C=$Country/O=$Org/OU=$OrgUnit/CN=$CommonName"
$days = [Math]::Max(365, $Years * 365)

Write-Host ''
Write-Host '=== Offline Root CA ==='
Write-Host ("Dir     : {0}" -f $caDir)
Write-Host ("Subject : {0}" -f $subj)
Write-Host ''

if ((Test-Path -LiteralPath $key) -and (Test-Path -LiteralPath $crt) -and -not $ForceNew) {
  Write-Host '[OK] Root already exists (use -ForceNew to regenerate).'
} else {
  if ($ForceNew) {
    foreach ($p in @($key,$crt,$cer)) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }
  }

  & $openssl @('req','-new','-x509','-newkey',("rsa:{0}" -f $KeyBits),'-sha256','-nodes',
               '-keyout',$key,'-out',$crt,'-days',$days,'-subj',$subj)
  if ($LASTEXITCODE -ne 0) { throw "OpenSSL req failed (exit=$LASTEXITCODE)" }

  & $openssl @('x509','-in',$crt,'-outform','der','-out',$cer)
  if ($LASTEXITCODE -ne 0) { throw "OpenSSL x509->DER failed (exit=$LASTEXITCODE)" }

  Write-Host '[OK] Root CA created.'
}

$x = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cer)
Write-Host ("Thumbprint: {0}" -f $x.Thumbprint)
Write-Host ("NotAfter  : {0:u}" -f $x.NotAfter)

Write-Host ''
Write-Host '[DONE] Keep OfflineRootCA.key private.'
