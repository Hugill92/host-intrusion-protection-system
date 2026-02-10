param(
  [string]$BaseDir = (Join-Path $env:USERPROFILE 'Documents\YubiPIV'),
  [string]$Country = 'US',
  [string]$Org     = 'BrexitSecurity',
  [string]$OrgUnit = 'FirewallCore',

  [string]$EndDateUtc = '20290309235959Z',
  [string]$CN9A = 'FirewallCore ClientAuth 9A',
  [string]$CN9C = 'FirewallCore Signature 9C'
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
  throw 'openssl.exe not found.'
}

function Fwd([string]$p) { return ($p -replace '\\','/') }

function Run {
  param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string[]]$Args
  )
  Write-Host ''
  Write-Host ('> {0} {1}' -f $Exe, ($Args -join ' '))
  & $Exe @Args
  if ($LASTEXITCODE -ne 0) { throw "Command failed (exit=$LASTEXITCODE): $Exe" }
}

# Hard-pin ykman to the known-good CLI
$ykman = 'C:\Program Files\Yubico\YubiKey Manager CLI\ykman.exe'
if (-not (Test-Path -LiteralPath $ykman)) { throw "ykman.exe not found at: $ykman" }

$openssl = Resolve-OpenSSL

# CA material
$caDir = Join-Path $BaseDir 'OfflineRootCA'
$caKey = Join-Path $caDir 'OfflineRootCA.key'
$caCrt = Join-Path $caDir 'OfflineRootCA.crt'
$caCer = Join-Path $caDir 'OfflineRootCA.cer'
foreach ($p in @($caKey,$caCrt,$caCer)) {
  if (-not (Test-Path -LiteralPath $p)) { throw "Missing CA file: $p (run 02_New-OfflineRootCA.ps1)" }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$work  = Join-Path $BaseDir ("Reissue_ECCP256_9A9C_{0}" -f $stamp)
New-Item -ItemType Directory -Force -Path $work | Out-Null

$deploy = Join-Path $BaseDir 'Certs\Deploy'
New-Item -ItemType Directory -Force -Path $deploy | Out-Null

$pub9a = Join-Path $work 'pubkey_9a.pem'
$pub9c = Join-Path $work 'pubkey_9c.pem'
$csr9a = Join-Path $work '9a.csr.pem'
$csr9c = Join-Path $work '9c.csr.pem'
$crt9a = Join-Path $work '9a_signed.crt'
$crt9c = Join-Path $work '9c_signed.crt'
$cer9a = Join-Path $work '9a_signed.cer'
$cer9c = Join-Path $work '9c_signed.cer'

$dn9a = ('CN={0},OU={1},O={2},C={3}' -f $CN9A,$OrgUnit,$Org,$Country)
$dn9c = ('CN={0},OU={1},O={2},C={3}' -f $CN9C,$OrgUnit,$Org,$Country)

$startUtc = [DateTime]::UtcNow.ToString("yyyyMMddHHmmss'Z'")

Write-Host ''
Write-Host '=== Reissue 9A + 9C (ECC P-256) ==='
Write-Host ("WorkDir   : {0}" -f $work)
Write-Host ("DeployDir : {0}" -f $deploy)
Write-Host ("Start UTC : {0}" -f $startUtc)
Write-Host ("End   UTC : {0}" -f $EndDateUtc)
Write-Host ("DN 9A     : {0}" -f $dn9a)
Write-Host ("DN 9C     : {0}" -f $dn9c)
Write-Host ''

Write-Host '[STEP 1] Generate keys in slots (PIN + touch expected)'
Run -Exe $ykman -Args @('piv','keys','generate','--algorithm','ECCP256','--pin-policy','ONCE','--touch-policy','ALWAYS','9a',$pub9a)
Run -Exe $ykman -Args @('piv','keys','generate','--algorithm','ECCP256','--pin-policy','ALWAYS','--touch-policy','ALWAYS','9c',$pub9c)

Write-Host '[STEP 2] Create CSRs from same slot keys'
Run -Exe $ykman -Args @('piv','certificates','request','9a',$pub9a,$csr9a,'--subject',$dn9a)
Run -Exe $ykman -Args @('piv','certificates','request','9c',$pub9c,$csr9c,'--subject',$dn9c)

Write-Host '[STEP 3] Issue leaf certs with OpenSSL CA'
$caState = Join-Path $work 'CA_STATE'
$newcerts = Join-Path $caState 'newcerts'
New-Item -ItemType Directory -Force -Path $newcerts | Out-Null
$index  = Join-Path $caState 'index.txt'
$serial = Join-Path $caState 'serial'
if (-not (Test-Path -LiteralPath $index))  { Set-Content -LiteralPath $index  -Value '' -Encoding ASCII }
if (-not (Test-Path -LiteralPath $serial)) { Set-Content -LiteralPath $serial -Value '1000' -Encoding ASCII }

$cnf = Join-Path $caState 'openssl-ca.cnf'
$dirF = Fwd $caState
$crtF = Fwd $caCrt
$keyF = Fwd $caKey

$cnfLines = @(
  '[ ca ]',
  'default_ca = CA_default',
  '',
  '[ CA_default ]',
  "dir               = $dirF",
  "database          = $dirF/index.txt",
  "new_certs_dir     = $dirF/newcerts",
  "serial            = $dirF/serial",
  'default_md        = sha256',
  'policy            = policy_loose',
  'unique_subject    = no',
  'copy_extensions   = none',
  "certificate       = $crtF",
  "private_key       = $keyF",
  '',
  '[ policy_loose ]',
  'countryName             = optional',
  'stateOrProvinceName     = optional',
  'localityName            = optional',
  'organizationName        = optional',
  'organizationalUnitName  = optional',
  'commonName              = supplied',
  'emailAddress            = optional',
  '',
  '[ v3_clientauth ]',
  'basicConstraints = CA:FALSE',
  'keyUsage = critical, digitalSignature, keyAgreement',
  'extendedKeyUsage = clientAuth',
  'subjectKeyIdentifier = hash',
  'authorityKeyIdentifier = keyid,issuer',
  '',
  '[ v3_codesign ]',
  'basicConstraints = CA:FALSE',
  'keyUsage = critical, digitalSignature',
  'extendedKeyUsage = codeSigning',
  'subjectKeyIdentifier = hash',
  'authorityKeyIdentifier = keyid,issuer'
)
Set-Content -LiteralPath $cnf -Value $cnfLines -Encoding ASCII

Run -Exe $openssl -Args @('ca','-batch','-config',$cnf,'-startdate',$startUtc,'-enddate',$EndDateUtc,'-extensions','v3_clientauth','-in',$csr9a,'-out',$crt9a)
Run -Exe $openssl -Args @('ca','-batch','-config',$cnf,'-startdate',$startUtc,'-enddate',$EndDateUtc,'-extensions','v3_codesign','-in',$csr9c,'-out',$crt9c)

Write-Host '[STEP 4] Convert to DER .cer'
Run -Exe $openssl -Args @('x509','-in',$crt9a,'-outform','der','-out',$cer9a)
Run -Exe $openssl -Args @('x509','-in',$crt9c,'-outform','der','-out',$cer9c)

Write-Host '[STEP 5] Import issued certs into SAME slots (PIN + touch expected)'
Run -Exe $ykman -Args @('piv','certificates','import','9a',$cer9a)
Run -Exe $ykman -Args @('piv','certificates','import','9c',$cer9c)

Write-Host '[STEP 6] Stage deployable public certs'
Copy-Item -LiteralPath $caCer -Destination (Join-Path $deploy 'FirewallCore_OfflineRootCA.cer') -Force
Copy-Item -LiteralPath $cer9a -Destination (Join-Path $deploy 'FirewallCore_ClientAuth_9A.cer') -Force
Copy-Item -LiteralPath $cer9c -Destination (Join-Path $deploy 'FirewallCore_CodeSigning_9C.cer') -Force

Write-Host ''
Write-Host '[OK] ECCP256 Reissue complete.'
Write-Host ('WorkDir : {0}' -f $work)
Write-Host ('Deploy  : {0}' -f $deploy)
Write-Host 'Next: run 04_Bind9C_SmokeSign.ps1'
