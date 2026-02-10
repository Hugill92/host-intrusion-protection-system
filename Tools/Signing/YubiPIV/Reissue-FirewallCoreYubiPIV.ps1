Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$BaseDir = (Join-Path $env:USERPROFILE 'Documents\YubiPIV'),
  [string]$Country = 'US',
  [string]$Org     = 'BrexitSecurity',
  [string]$OrgUnit = 'FirewallCore',

  [string]$MgmtKeyHex = '010203040506070801020304050607080102030405060708',

  # Pinned end date (UTC) for leaf certs
  [string]$EndDateUtc = '20290309235959Z',

  # You can override CNs here if you want
  [string]$CN9A = 'FirewallCore ClientAuth 9A',
  [string]$CN9C = 'FirewallCore Signature 9C',

  [string]$DeployDir
)

function Resolve-Exe {
  param([Parameter(Mandatory)][string]$Name,[string[]]$Candidates)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  foreach ($c in $Candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
  throw "Missing executable: $Name"
}

function To-FwdSlashPath {
  param([Parameter(Mandatory)][string]$Path)
  return ($Path -replace '\\','/')
}

function Invoke-Exe {
  param([Parameter(Mandatory)][string]$Exe,[Parameter(Mandatory)][string[]]$Args)
  Write-Host ''
  Write-Host ('> {0} {1}' -f $Exe, ($Args -join ' '))
  & $Exe @Args
  if ($LASTEXITCODE -ne 0) { throw "Command failed (exit=$LASTEXITCODE): $Exe" }
}

$ykman   = Resolve-Exe -Name 'ykman'   -Candidates @()
$openssl = Resolve-Exe -Name 'openssl' -Candidates @(
  'C:\Program Files\OpenSSL-Win64\bin\openssl.exe',
  'C:\Program Files\OpenSSL-Win32\bin\openssl.exe'
)

$caDir = Join-Path $BaseDir 'OfflineRootCA'
$caKey = Join-Path $caDir 'OfflineRootCA.key'
$caCrt = Join-Path $caDir 'OfflineRootCA.crt'
$caCer = Join-Path $caDir 'OfflineRootCA.cer'

foreach ($p in @($caKey,$caCrt)) {
  if (-not (Test-Path -LiteralPath $p)) {
    throw "Missing CA material: $p. Run New-FirewallCoreOfflineRootCA.ps1 first."
  }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$work  = Join-Path $BaseDir ("Reissue_9A9C_{0}" -f $stamp)
New-Item -ItemType Directory -Force -Path $work | Out-Null

if (-not $DeployDir) { $DeployDir = Join-Path $BaseDir 'Certs\Deploy' }
New-Item -ItemType Directory -Force -Path $DeployDir | Out-Null

$pub9a  = Join-Path $work 'pubkey_9a.pem'
$pub9c  = Join-Path $work 'pubkey_9c.pem'
$csr9a  = Join-Path $work '9a.csr.pem'
$csr9c  = Join-Path $work '9c.csr.pem'
$crt9a  = Join-Path $work '9a_signed.crt'
$crt9c  = Join-Path $work '9c_signed.crt'
$cer9a  = Join-Path $work '9a_signed.cer'
$cer9c  = Join-Path $work '9c_signed.cer'

$caState  = Join-Path $work 'CA_STATE'
$newcerts = Join-Path $caState 'newcerts'
New-Item -ItemType Directory -Force -Path $newcerts | Out-Null

$index  = Join-Path $caState 'index.txt'
$serial = Join-Path $caState 'serial'
if (-not (Test-Path -LiteralPath $index))  { Set-Content -LiteralPath $index  -Value ''     -Encoding ASCII }
if (-not (Test-Path -LiteralPath $serial)) { Set-Content -LiteralPath $serial -Value '1000' -Encoding ASCII }

$cnf = Join-Path $caState 'openssl-ca.cnf'

# NOTE: This is plain text (no nested here-string conflicts)
$cnfTemplate = @'
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = __DIR__
database          = __DIR__/index.txt
new_certs_dir     = __DIR__/newcerts
serial            = __DIR__/serial
default_md        = sha256
policy            = policy_loose
unique_subject    = no
copy_extensions   = none
default_days      = 825
x509_extensions   = v3_codesign
certificate       = __CA_CRT__
private_key       = __CA_KEY__

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ v3_clientauth ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[ v3_codesign ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
'@

$cnfText = $cnfTemplate
$cnfText = $cnfText.Replace('__DIR__',     (To-FwdSlashPath $caState))
$cnfText = $cnfText.Replace('__CA_CRT__',  (To-FwdSlashPath $caCrt))
$cnfText = $cnfText.Replace('__CA_KEY__',  (To-FwdSlashPath $caKey))
Set-Content -LiteralPath $cnf -Value $cnfText -Encoding ASCII

$subj9a = ("CN={0},OU={1},O={2},C={3}" -f $CN9A,$OrgUnit,$Org,$Country)
$subj9c = ("CN={0},OU={1},O={2},C={3}" -f $CN9C,$OrgUnit,$Org,$Country)

$startUtc = [DateTime]::UtcNow.ToString("yyyyMMddHHmmss'Z'")

Write-Host ''
Write-Host '=== YubiKey PIV Reissue (9A + 9C) ==='
Write-Host ("WorkDir   : {0}" -f $work)
Write-Host ("DeployDir : {0}" -f $DeployDir)
Write-Host ("CA CRT    : {0}" -f $caCrt)
Write-Host ("Start UTC : {0}" -f $startUtc)
Write-Host ("End UTC   : {0}" -f $EndDateUtc)
Write-Host ("9A Subject: {0}" -f $subj9a)
Write-Host ("9C Subject: {0}" -f $subj9c)
Write-Host ''

Write-Host '[STEP] 1) Generate keys IN slots (9A, 9C)'
Invoke-Exe -Exe $ykman -Args @('piv','keys','generate','--algorithm','RSA2048','--management-key',$MgmtKeyHex,'9a',$pub9a)
Invoke-Exe -Exe $ykman -Args @('piv','keys','generate','--algorithm','RSA2048','--management-key',$MgmtKeyHex,'9c',$pub9c)

Write-Host '[STEP] 2) CSRs FROM the same slot keys'
Invoke-Exe -Exe $ykman -Args @('piv','certificates','request','9a',$pub9a,$csr9a,'--subject',$subj9a)
Invoke-Exe -Exe $ykman -Args @('piv','certificates','request','9c',$pub9c,$csr9c,'--subject',$subj9c)

Write-Host '[STEP] 3) Issue leaf certs with OpenSSL CA (NOT x509 -req)'
Invoke-Exe -Exe $openssl -Args @('ca','-batch','-config',$cnf,'-startdate',$startUtc,'-enddate',$EndDateUtc,'-extensions','v3_clientauth','-in',$csr9a,'-out',$crt9a)
Invoke-Exe -Exe $openssl -Args @('ca','-batch','-config',$cnf,'-startdate',$startUtc,'-enddate',$EndDateUtc,'-extensions','v3_codesign','-in',$csr9c,'-out',$crt9c)

Write-Host '[STEP] 4) Convert to DER .cer for ykman + Windows'
Invoke-Exe -Exe $openssl -Args @('x509','-in',$crt9a,'-outform','der','-out',$cer9a)
Invoke-Exe -Exe $openssl -Args @('x509','-in',$crt9c,'-outform','der','-out',$cer9c)

Write-Host '[STEP] 5) Verify pinned NotAfter on 9C'
Invoke-Exe -Exe $openssl -Args @('x509','-in',$crt9c,'-noout','-enddate')

Write-Host '[STEP] 6) Import issued certs back into the SAME slots'
Invoke-Exe -Exe $ykman -Args @('piv','certificates','import','9a',$cer9a,'--management-key',$MgmtKeyHex)
Invoke-Exe -Exe $ykman -Args @('piv','certificates','import','9c',$cer9c,'--management-key',$MgmtKeyHex)

Write-Host '[STEP] 7) Stage deployable public certs (NO private keys)'
Copy-Item -LiteralPath $caCer -Destination (Join-Path $DeployDir 'FirewallCore_OfflineRootCA.cer') -Force
Copy-Item -LiteralPath $cer9a  -Destination (Join-Path $DeployDir 'FirewallCore_ClientAuth_9A.cer') -Force
Copy-Item -LiteralPath $cer9c  -Destination (Join-Path $DeployDir 'FirewallCore_CodeSigning_9C.cer') -Force

Write-Host ''
Write-Host '[OK] Reissue complete.'
Write-Host ('  Root CER: {0}' -f (Join-Path $DeployDir 'FirewallCore_OfflineRootCA.cer'))
Write-Host ('  9A  CER : {0}' -f (Join-Path $DeployDir 'FirewallCore_ClientAuth_9A.cer'))
Write-Host ('  9C  CER : {0}' -f (Join-Path $DeployDir 'FirewallCore_CodeSigning_9C.cer'))
Write-Host ''
Write-Host 'Next: run Bind-FirewallCore9CForSigning.ps1 -Signed9CCer <path to FirewallCore_CodeSigning_9C.cer>'
