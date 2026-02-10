Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory)][string]$RootCer,
  [Parameter(Mandatory)][string]$PublisherCer,
  [switch]$AlsoTrustCurrentUser
)

function Test-InStore {
  param([Parameter(Mandatory)][string]$StorePath,[Parameter(Mandatory)][string]$Thumbprint)
  $found = Get-ChildItem -Path $StorePath -ErrorAction Stop | Where-Object Thumbprint -eq $Thumbprint | Select-Object -First 1
  return [bool]$found
}

function Ensure-ImportIfMissing {
  param([Parameter(Mandatory)][string]$StorePath,[Parameter(Mandatory)][string]$FilePath,[Parameter(Mandatory)][string]$Thumbprint)
  if (Test-InStore -StorePath $StorePath -Thumbprint $Thumbprint) {
    Write-Host ("[OK] Present: {0}" -f $StorePath)
    return
  }
  Write-Host ("[WARN] Missing: {0} -> importing (NO DELETE)" -f $StorePath)
  Import-Certificate -FilePath $FilePath -CertStoreLocation $StorePath | Out-Host
  if (-not (Test-InStore -StorePath $StorePath -Thumbprint $Thumbprint)) {
    throw ("[FAIL] Import attempted but cert still not found in {0}" -f $StorePath)
  }
  Write-Host ("[OK] Imported: {0}" -f $StorePath)
}

foreach ($p in @($RootCer,$PublisherCer)) {
  if (-not (Test-Path -LiteralPath $p)) { throw "File not found: $p" }
}

Write-Host ''
Write-Host '=== FirewallCore Trust Install (NO DELETE) ==='
Write-Host ('Time: {0}' -f (Get-Date))
Write-Host ''

$rootObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($RootCer)
$pubObj  = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PublisherCer)

Write-Host ('Root Subject : {0}' -f $rootObj.Subject)
Write-Host ('Root Thumb   : {0}' -f $rootObj.Thumbprint)
Write-Host ('Pub Subject  : {0}' -f $pubObj.Subject)
Write-Host ('Pub Thumb    : {0}' -f $pubObj.Thumbprint)
Write-Host ''

Ensure-ImportIfMissing -StorePath 'Cert:\LocalMachine\Root' -FilePath $RootCer -Thumbprint $rootObj.Thumbprint
Ensure-ImportIfMissing -StorePath 'Cert:\LocalMachine\TrustedPublisher' -FilePath $PublisherCer -Thumbprint $pubObj.Thumbprint

if ($AlsoTrustCurrentUser) {
  Ensure-ImportIfMissing -StorePath 'Cert:\CurrentUser\TrustedPublisher' -FilePath $PublisherCer -Thumbprint $pubObj.Thumbprint
}

Write-Host ''
Write-Host '=== Verification ==='
Write-Host ("LM\\Root present             : {0}" -f (Test-InStore -StorePath 'Cert:\LocalMachine\Root' -Thumbprint $rootObj.Thumbprint))
Write-Host ("LM\\TrustedPublisher present : {0}" -f (Test-InStore -StorePath 'Cert:\LocalMachine\TrustedPublisher' -Thumbprint $pubObj.Thumbprint))
if ($AlsoTrustCurrentUser) {
  Write-Host ("CU\\TrustedPublisher present : {0}" -f (Test-InStore -StorePath 'Cert:\CurrentUser\TrustedPublisher' -Thumbprint $pubObj.Thumbprint))
}
Write-Host '[DONE]'
