# YubiKey PIV 9A + 9C Reissue & Windows Binding SOP (Generic / YouTube-safe)

This SOP deterministically (re)issues certificates into YubiKey PIV slots **9A** and **9C**, signs them using an **offline Root CA**, imports them back into the same slots, then performs the **Windows binding step** so **slot 9C can Authenticode-sign PowerShell scripts** (`HasPrivateKey=True`). ✅

> **Design goal:** Installer never depends on `%USERPROFILE%\Documents\YubiPIV` on end-user machines. Public certs are staged from a single canonical repo folder:  
> `C:\FirewallInstaller\Tools\Releases\Deploy\Certs`

---

## Working folder + files

### Recommended working folder (build machine only)
- `%USERPROFILE%\Documents\YubiPIV`

### Offline Root CA files (authoritative)
- `%USERPROFILE%\Documents\YubiPIV\OfflineRootCA\OfflineRootCA.crt`
- `%USERPROFILE%\Documents\YubiPIV\OfflineRootCA\OfflineRootCA.key`

### Artifacts produced (expected)
- `pubkey_9a.pem`, `pubkey_9c.pem`
- `9a.csr.pem`, `9c.csr.pem`
- `9a_signed.crt`, `9c_signed.crt`
- `9c_from_yubikey.cer`

---

## Slot policy (hard rule)

- **9A** → Client Authentication EKU (`1.3.6.1.5.5.7.3.2`)  
- **9C** → Code Signing EKU (`1.3.6.1.5.5.7.3.3`)

This prevents “certificate not suitable for code signing” and keeps intent clean per slot.

---

## Step 0 — Verify tools + key state

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$yk  = 'C:\Program Files\Yubico\YubiKey Manager CLI\ykman.exe'
$oss = 'C:\Program Files\OpenSSL-Win64\bin\openssl.exe'

foreach ($p in @($yk,$oss)) { if (-not (Test-Path -LiteralPath $p)) { throw "Missing: $p" } }

& $yk --version
& $yk piv info
& $oss version
```

---

## Step 1 — Generate keys **on-key** (9A + 9C)

> Prompts: PIN (and maybe touch) depending on your YubiKey policy.

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$yk   = 'C:\Program Files\Yubico\YubiKey Manager CLI\ykman.exe'
$base = Join-Path $env:USERPROFILE 'Documents\YubiPIV'
New-Item -ItemType Directory -Force -Path $base | Out-Null

$pub9a = Join-Path $base 'pubkey_9a.pem'
$pub9c = Join-Path $base 'pubkey_9c.pem'

# ECC P-256 (recommended). Use rsa2048 if you explicitly need RSA.
& $yk piv keys generate --algorithm eccp256 9a $pub9a
& $yk piv keys generate --algorithm eccp256 9c $pub9c

& $yk piv info
```

---

## Step 2 — Create CSRs from the same slot keys

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$yk   = 'C:\Program Files\Yubico\YubiKey Manager CLI\ykman.exe'
$oss  = 'C:\Program Files\OpenSSL-Win64\bin\openssl.exe'
$base = Join-Path $env:USERPROFILE 'Documents\YubiPIV'

$pub9a = Join-Path $base 'pubkey_9a.pem'
$pub9c = Join-Path $base 'pubkey_9c.pem'
$csr9a = Join-Path $base '9a.csr.pem'
$csr9c = Join-Path $base '9c.csr.pem'

$dn9a = 'CN=FirewallCore ClientAuth 9A,OU=FirewallCore,O=ExampleOrg,C=US'
$dn9c = 'CN=FirewallCore Signature 9C,OU=FirewallCore,O=ExampleOrg,C=US'

& $yk piv certificates request 9a $pub9a $csr9a --subject $dn9a
& $yk piv certificates request 9c $pub9c $csr9c --subject $dn9c

# Optional: show CSR subjects
& $oss req -in $csr9a -noout -subject
& $oss req -in $csr9c -noout -subject
```

---

## Step 3 — Create OpenSSL CA_STATE + sign CSRs (must use `openssl ca`)

### Why this matters
OpenSSL `ca` requires an `index.txt` database file. If `index.txt` contains **CRLF bytes** (0D 0A), you can get:
- `Problem with index file ... (could not load/parse file)`

**Fix:** ensure `index.txt` is **0 bytes**.

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$oss  = 'C:\Program Files\OpenSSL-Win64\bin\openssl.exe'
$base = Join-Path $env:USERPROFILE 'Documents\YubiPIV'

$caDir = Join-Path $base 'OfflineRootCA'
$caKey = Join-Path $caDir 'OfflineRootCA.key'
$caCrt = Join-Path $caDir 'OfflineRootCA.crt'
foreach ($p in @($caKey,$caCrt)) { if (-not (Test-Path -LiteralPath $p)) { throw "Missing CA file: $p" } }

$work     = Join-Path $base ('CA_STATE_{0}' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$newcerts = Join-Path $work 'newcerts'
New-Item -ItemType Directory -Force -Path $newcerts | Out-Null

$idx  = Join-Path $work 'index.txt'
$idxa = Join-Path $work 'index.txt.attr'
$ser  = Join-Path $work 'serial'

# index.txt MUST be 0 bytes (NOT CRLF)
[System.IO.File]::WriteAllBytes($idx, [byte[]]@())
[System.IO.File]::WriteAllText($ser,  "1000`n", [System.Text.Encoding]::ASCII)
[System.IO.File]::WriteAllText($idxa, "unique_subject = no`n", [System.Text.Encoding]::ASCII)

function Fwd([string]$p){ $p -replace '\\','/' }

$cnf = Join-Path $work 'openssl-ca.cnf'
$cnfText = @"
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = $(Fwd $work)
database          = $(Fwd (Join-Path $work 'index.txt'))
new_certs_dir     = $(Fwd $newcerts)
serial            = $(Fwd (Join-Path $work 'serial'))
default_md        = sha256
policy            = policy_loose
unique_subject    = no
copy_extensions   = none
certificate       = $(Fwd $caCrt)
private_key       = $(Fwd $caKey)

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
"@
Set-Content -LiteralPath $cnf -Value $cnfText -Encoding ASCII

$csr9a = Join-Path $base '9a.csr.pem'
$csr9c = Join-Path $base '9c.csr.pem'
$crt9a = Join-Path $base '9a_signed.crt'
$crt9c = Join-Path $base '9c_signed.crt'

$startUtc = [DateTime]::UtcNow.ToString("yyyyMMddHHmmss'Z'")
$endUtc   = '20290309235959Z'

& $oss ca -batch -config $cnf -startdate $startUtc -enddate $endUtc -extensions v3_clientauth -in $csr9a -out $crt9a
& $oss ca -batch -config $cnf -startdate $startUtc -enddate $endUtc -extensions v3_codesign   -in $csr9c -out $crt9c

& $oss x509 -in $crt9a -noout -subject -enddate
& $oss x509 -in $crt9c -noout -subject -enddate

"`n[OK] CA_STATE: $work"
"`n[OK] CNF:      $cnf"
```

---

## Step 4 — Import signed certs into YubiKey slots

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$yk   = 'C:\Program Files\Yubico\YubiKey Manager CLI\ykman.exe'
$base = Join-Path $env:USERPROFILE 'Documents\YubiPIV'

$crt9a = Join-Path $base '9a_signed.crt'
$crt9c = Join-Path $base '9c_signed.crt'
foreach ($p in @($crt9a,$crt9c)) { if (-not (Test-Path -LiteralPath $p)) { throw "Missing: $p" } }

& $yk piv certificates import 9a $crt9a
& $yk piv certificates import 9c $crt9c

& $yk piv info
```

---

## Step 5 — Trust the Offline Root CA in Windows

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$base  = Join-Path $env:USERPROFILE 'Documents\YubiPIV'
$caCrt = Join-Path $base 'OfflineRootCA\OfflineRootCA.crt'
if (-not (Test-Path -LiteralPath $caCrt)) { throw "Missing: $caCrt" }

Import-Certificate -FilePath $caCrt -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
Import-Certificate -FilePath $caCrt -CertStoreLocation Cert:\CurrentUser\Root  | Out-Null

Restart-Service SCardSvr -Force
certutil -scinfo | Out-Host
```

> `certutil -scinfo` can be noisy (revocation checks, provider messages). The **real gate** is Step 6: `HasPrivateKey=True`.

---

## Step 6 — Bind slot 9C leaf for Authenticode (the real gate ✅)

If `certutil -repairstore` says success but `HasPrivateKey=False`, **remove stale duplicates** of the 9C leaf from `Cert:\CurrentUser\My`, re-import, then re-run.

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$yk   = 'C:\Program Files\Yubico\YubiKey Manager CLI\ykman.exe'
$base = Join-Path $env:USERPROFILE 'Documents\YubiPIV'
$leaf9c = Join-Path $base '9c_from_yubikey.cer'

# Export 9C leaf from device
& $yk piv certificates export 9c $leaf9c

# Remove duplicates (stale copies can block correct binding)
$existing = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -like '*CN=FirewallCore Signature 9C*' }
foreach ($c in $existing) {
  Remove-Item -LiteralPath ("Cert:\CurrentUser\My\{0}" -f $c.Thumbprint) -Force
}

# Import fresh 9C leaf
Import-Certificate -FilePath $leaf9c -CertStoreLocation Cert:\CurrentUser\My | Out-Null

$cert = Get-ChildItem Cert:\CurrentUser\My |
  Where-Object { $_.Subject -like '*CN=FirewallCore Signature 9C*' } |
  Sort-Object NotBefore -Descending |
  Select-Object -First 1

if (-not $cert) { throw '9C leaf not found in CurrentUser\My after import.' }

# Bind using SERIAL (not thumbprint)
Restart-Service SCardSvr -Force
certutil -user -repairstore My $cert.SerialNumber | Out-Host

$cert2 = Get-ChildItem Cert:\CurrentUser\My | Where-Object Thumbprint -eq $cert.Thumbprint | Select-Object -First 1
"[VERIFY] 9C HasPrivateKey = $($cert2.HasPrivateKey)"
if (-not $cert2.HasPrivateKey) { throw 'Binding failed: HasPrivateKey is still False.' }
```

---

## Step 7 — Authenticode smoke test

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$test = Join-Path $env:TEMP 'SignSmoke.ps1'
"Write-Output 'sign-smoke ok'" | Set-Content -LiteralPath $test -Encoding UTF8

$cert = Get-ChildItem Cert:\CurrentUser\My |
  Where-Object { $_.Subject -like '*CN=FirewallCore Signature 9C*' } |
  Sort-Object NotBefore -Descending |
  Select-Object -First 1

if (-not $cert) { throw 'Missing 9C cert in CurrentUser\My' }
if (-not $cert.HasPrivateKey) { throw '9C not bound: HasPrivateKey=False' }

Set-AuthenticodeSignature -FilePath $test -Certificate $cert -HashAlgorithm SHA256 | Out-Host
Get-AuthenticodeSignature -FilePath $test | Format-List *
```

Expected:
- `Status : Valid`

---

## Public cert staging model (installer-friendly)

### Canonical repo source (only source the installer copies from)
- `C:\FirewallInstaller\Tools\Releases\Deploy\Certs`

### Canonical filenames (public certs only)
- `OfflineRootCA.crt`
- `FirewallCore_CodeSigning_EKU_9C.cer`
- `FirewallCore_ClientAuth_EKU_9A.cer` *(optional, only if you ship client-auth leaf)*

### Runtime mirrors (installer copies Deploy\Certs → these)
- `C:\FirewallInstaller\Tools\Releases\Certs` *(repo convenience)*
- `C:\ProgramData\FirewallCore\Tools\Releases\Certs` *(runtime)*
- `C:\Firewall\Tools\Releases\Certs` *(runtime)*

> Private keys never leave the YubiKey; these are **public certs only**.

---

## Notes on PIN prompts (practical)

- YubiKey policy may show `PIN required for use: ONCE` — but some signing stacks still prompt per operation.
- Best mitigation: **sign in one batch run** (single PowerShell process) instead of hundreds of separate invocations.
- If you must reduce prompts further, use a signer that loads the cert once and signs a whole list in a single run.

---

## Success criteria (hard gates ✅)

- `ykman piv info` shows slots 9A + 9C populated with correct Subject/Issuer and validity
- Offline Root CA trusted in **LocalMachine\Root** and **CurrentUser\Root**
- 9C leaf exists in **Cert:\CurrentUser\My** with `HasPrivateKey=True`
- `Set-AuthenticodeSignature` succeeds and reports `Status : Valid`
