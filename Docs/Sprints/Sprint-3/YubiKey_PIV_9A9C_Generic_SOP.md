# YubiKey PIV 9A + 9C Reissue & Windows Binding SOP (Generic)

## Goal ✅
Create/refresh YubiKey PIV keys and certificates in:
- **Slot 9A (AUTHENTICATION)** → **Client Authentication EKU**
- **Slot 9C (SIGNATURE)** → **Code Signing EKU**
Then ensure Windows can use the **9C** certificate for **Authenticode** by binding it so:
- `HasPrivateKey=True` in `Cert:\CurrentUser\My`

This SOP is designed to be repeatable and to avoid common failure modes:
- `WARNING: Failed to read stored management key`
- `PIN verification failed`
- OpenSSL `ca` errors: index database parse failures
- `certutil -repairstore` “success” but `HasPrivateKey=False` until stale leaf duplicates are removed

---

## Prereqs 🔧

### Tools
- YubiKey Manager CLI (`ykman.exe`)
- OpenSSL (`openssl.exe`) with `openssl ca` available
- Windows PowerShell or PowerShell 7

### Recommended working folder
- `%USERPROFILE%\Documents\YubiPIV`

### Offline Root CA (authoritative)
Provide an Offline Root CA keypair:
- `%USERPROFILE%\Documents\YubiPIV\OfflineRootCA\OfflineRootCA.crt`
- `%USERPROFILE%\Documents\YubiPIV\OfflineRootCA\OfflineRootCA.key`

### Expected artifacts (outputs)
- `pubkey_9a.pem`, `pubkey_9c.pem`
- `9a.csr.pem`, `9c.csr.pem`
- `9a_signed.crt`, `9c_signed.crt`
- `9c_from_yubikey.cer`

---

## Slot policy (important) 🧠
- **9A**: Client Authentication EKU → `1.3.6.1.5.5.7.3.2`
- **9C**: Code Signing EKU → `1.3.6.1.5.5.7.3.3`

This separation prevents “certificate not suitable for code signing”.

---

## Step 0 — Verify tooling + device state ✅

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

## Step 1 — Generate keys ON the YubiKey (9A + 9C) 🔑

> You will be prompted for the PIV PIN. Touch may be required depending on policy.

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$yk   = 'C:\Program Files\Yubico\YubiKey Manager CLI\ykman.exe'
$base = Join-Path $env:USERPROFILE 'Documents\YubiPIV'
New-Item -ItemType Directory -Force -Path $base | Out-Null

$pub9a = Join-Path $base 'pubkey_9a.pem'
$pub9c = Join-Path $base 'pubkey_9c.pem'

# ECC P-256 recommended. Use rsa2048 only if you explicitly need RSA.
& $yk piv keys generate --algorithm eccp256 9a $pub9a
& $yk piv keys generate --algorithm eccp256 9c $pub9c

& $yk piv info
```

---

## Step 2 — Create CSRs from the SAME slot keys 🧾

Use neutral subjects. Replace placeholders if desired.

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

$dn9a = 'CN=YubiKey PIV ClientAuth 9A,OU=Security,O=ExampleOrg,C=US'
$dn9c = 'CN=YubiKey PIV CodeSign 9C,OU=Security,O=ExampleOrg,C=US'

& $yk piv certificates request 9a $pub9a $csr9a --subject $dn9a
& $yk piv certificates request 9c $pub9c $csr9c --subject $dn9c

# Optional: show CSR subjects
& $oss req -in $csr9a -noout -subject
& $oss req -in $csr9c -noout -subject
```

---

## Step 3 — Create CA_STATE + Sign CSRs (OpenSSL `ca`) 🏗️

### Critical detail: `index.txt` MUST be 0 bytes
If `index.txt` contains CRLF (0D 0A), OpenSSL may fail with:
- `Problem with index file ... (could not load/parse file)`

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

# index.txt MUST be 0 bytes (not CRLF)
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

# Example validity window (adjust as needed)
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

## Step 4 — Import signed certs into YubiKey slots 📥

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

## Step 5 — Trust the Offline Root CA in Windows 🛡️

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

Note: `certutil -scinfo` can remain noisy (revocation checks, provider messages). The real gate is Step 6.

---

## Step 6 — Bind 9C for Authenticode (the real gate) 🎯

**This is the fix that works when `repairstore` says success but `HasPrivateKey` stays false:**
1) Remove stale duplicates of the 9C leaf from `CurrentUser\My`  
2) Re-import leaf exported directly from slot 9C  
3) Restart `SCardSvr`  
4) Run `certutil -user -repairstore My <SerialNumber>`  
5) Verify `HasPrivateKey=True`

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$yk   = 'C:\Program Files\Yubico\YubiKey Manager CLI\ykman.exe'
$base = Join-Path $env:USERPROFILE 'Documents\YubiPIV'
$leaf9c = Join-Path $base '9c_from_yubikey.cer'

# Export leaf from slot 9C (authoritative)
& $yk piv certificates export 9c $leaf9c

# Remove duplicates that can block correct binding
$existing = Get-ChildItem Cert:\CurrentUser\My |
  Where-Object { $_.Subject -like '*CodeSign 9C*' -or $_.Subject -like '*Signature 9C*' -or $_.Subject -like '* 9C*' }

foreach ($c in $existing) {
  Remove-Item -LiteralPath ("Cert:\CurrentUser\My\{0}" -f $c.Thumbprint) -Force
}

# Re-import fresh
Import-Certificate -FilePath $leaf9c -CertStoreLocation Cert:\CurrentUser\My | Out-Null

# Select newest leaf (best effort)
$cert = Get-ChildItem Cert:\CurrentUser\My | Sort-Object NotBefore -Descending | Select-Object -First 1
if (-not $cert) { throw '9C leaf not found in CurrentUser\My after import.' }

Restart-Service SCardSvr -Force

# IMPORTANT: repairstore uses SerialNumber (not Thumbprint)
certutil -user -repairstore My $cert.SerialNumber | Out-Host

# Verify
$cert2 = Get-ChildItem Cert:\CurrentUser\My | Where-Object Thumbprint -eq $cert.Thumbprint | Select-Object -First 1
"[VERIFY] 9C HasPrivateKey = $($cert2.HasPrivateKey)"
if (-not $cert2.HasPrivateKey) { throw 'Binding failed: HasPrivateKey is still False.' }
```

---

## Step 7 — Authenticode smoke test 🧪

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$test = Join-Path $env:TEMP 'SignSmoke.ps1'
"Write-Output 'sign-smoke ok'" | Set-Content -LiteralPath $test -Encoding UTF8

# Select your 9C leaf by subject (edit pattern to match your DN)
$cert = Get-ChildItem Cert:\CurrentUser\My |
  Where-Object { $_.Subject -like '*CodeSign 9C*' -or $_.Subject -like '*Signature 9C*' } |
  Sort-Object NotBefore -Descending |
  Select-Object -First 1

if (-not $cert) { throw 'Missing 9C cert in CurrentUser\My' }
if (-not $cert.HasPrivateKey) { throw '9C not bound: HasPrivateKey=False' }

Set-AuthenticodeSignature -FilePath $test -Certificate $cert -HashAlgorithm SHA256 | Out-Host
Get-AuthenticodeSignature -FilePath $test | Format-List *

# Expected:
# Status : Valid
```

---

## Hard success criteria ✅
- `ykman piv info` shows **both slots populated** with correct DN/issuer and expected validity.
- Offline Root CA is trusted in:
  - `Cert:\LocalMachine\Root`
  - `Cert:\CurrentUser\Root`
- The 9C certificate in `Cert:\CurrentUser\My` reports:
  - `HasPrivateKey=True`
- `Set-AuthenticodeSignature` succeeds and `Get-AuthenticodeSignature` returns:
  - `Status : Valid`
