Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

function Resolve-Exe {
  param([Parameter(Mandatory)][string]$Name,[string[]]$Candidates)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  foreach ($c in $Candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
  throw "Missing executable: $Name"
}

$openssl = Resolve-Exe -Name 'openssl' -Candidates @(
  'C:\Program Files\OpenSSL-Win64\bin\openssl.exe',
  'C:\Program Files\OpenSSL-Win32\bin\openssl.exe'
)

$caDir = Join-Path $BaseDir 'OfflineRootCA'
New-Item -ItemType Directory -Force -Path $caDir | Out-Null

$key = Join-Path $caDir 'OfflineRootCA.key'
$crt = Join-Path $caDir 'OfflineRootCA.crt'
$cer = Join-Path $caDir 'OfflineRootCA.cer'

$subj = "/C=$Country/O=$Org/OU=$OrgUnit/CN=$CommonName"

Write-Host ''
Write-Host '=== Offline Root CA (create if missing) ==='
Write-Host ("BaseDir : {0}" -f $BaseDir)
Write-Host ("CA Dir  : {0}" -f $caDir)
Write-Host ("Subject : {0}" -f $subj)
Write-Host ''

if ((Test-Path -LiteralPath $key) -and (Test-Path -LiteralPath $crt) -and -not $ForceNew) {
  Write-Host '[OK] Root CA already exists (use -ForceNew to regenerate).'
} else {
  if ($ForceNew -and (Test-Path -LiteralPath $key)) { Remove-Item -LiteralPath $key -Force }
  if ($ForceNew -and (Test-Path -LiteralPath $crt)) { Remove-Item -LiteralPath $crt -Force }
  if ($ForceNew -and (Test-Path -LiteralPath $cer)) { Remove-Item -LiteralPath $cer -Force }

  $days = [Math]::Max(365, $Years * 365)

  Write-Host '[INFO] Generating Root CA key + self-signed cert via OpenSSL...'
  $args = @(
    'req','-new','-x509','-newkey',("rsa:{0}" -f $KeyBits),'-sha256','-nodes',
    '-keyout',$key,'-out',$crt,'-days',$days,'-subj',$subj
  )
  & $openssl @args
  if ($LASTEXITCODE -ne 0) { throw "OpenSSL req failed (exit=$LASTEXITCODE)" }

  Write-Host '[INFO] Converting Root CA to DER .cer for Windows stores...'
  & $openssl 'x509' '-in' $crt '-outform' 'der' '-out' $cer
  if ($LASTEXITCODE -ne 0) { throw "OpenSSL x509 convert failed (exit=$LASTEXITCODE)" }

  Write-Host '[OK] Root CA created:'
  Write-Host ("  Key: {0}" -f $key)
  Write-Host ("  CRT: {0}" -f $crt)
  Write-Host ("  CER: {0}" -f $cer)
}

try {
  $x = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cer)
  Write-Host ''
  Write-Host ("Thumbprint: {0}" -f $x.Thumbprint)
  Write-Host ("NotAfter  : {0}" -f $x.NotAfter)
} catch {
  Write-Host '[WARN] Could not load .cer into X509Certificate2 (non-fatal).'
}

Write-Host ''
Write-Host '[DONE] Root CA ready. Keep OfflineRootCA.key private.'
