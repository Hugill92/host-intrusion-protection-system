param(
  [Parameter(Mandatory)][string[]]$Scopes,
  [int]$TtlMinutes = 15,
  [ValidateSet('DPAPI_HMAC','YubiKeyPIV')][string]$Method = 'DPAPI_HMAC'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Admin gate (issuance should require admin)
$wi = [Security.Principal.WindowsIdentity]::GetCurrent()
$wp = New-Object Security.Principal.WindowsPrincipal($wi)
if (-not $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Admin required to issue secure token."
}

$runId = [guid]::NewGuid().ToString()
$now   = (Get-Date).ToUniversalTime()
$exp   = $now.AddMinutes($TtlMinutes)

$machineGuid = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name 'MachineGuid' -ErrorAction Stop).MachineGuid
$nonceBytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($nonceBytes)
$nonce = [Convert]::ToBase64String($nonceBytes)

$payload = [ordered]@{
  schema     = 'MaintenanceToken.v1'
  runId      = $runId
  issuedUtc  = $now.ToString('o')
  expiresUtc = $exp.ToString('o')
  scopes     = @($Scopes)
  machine    = @{ machineGuid = $machineGuid; hostname = $env:COMPUTERNAME }
  principal  = @{ userSid = $wi.User.Value; username = $wi.Name; isAdmin = $true }
  attestation= @{ unlockMethod = $Method; certThumbprint = $null; keyId = $null }
  nonce      = $nonce
}

# NOTE: ConvertTo-Json output is not canonical across implementations; Phase A should normalize before signing.
$payloadJson = ($payload | ConvertTo-Json -Depth 6 -Compress)

# Signature placeholder:
# Phase A: compute HMAC-SHA256(payloadJsonNormalized) using DPAPI-protected key.
# Phase B: call signed helper to sign payload using YubiKey PIV.
$sigAlg = 'HMAC-SHA256'
$signature = '<TODO>'
$keyId = '<TODO>'

$envelope = [ordered]@{
  payload   = ($payloadJson | ConvertFrom-Json)
  sigAlg    = $sigAlg
  signature = $signature
  keyId     = $keyId
}

$tokenDir  = 'C:\ProgramData\FirewallCore\Security\Tokens'
$tokenPath = Join-Path $tokenDir 'Maintenance.token.json'
New-Item -ItemType Directory -Path $tokenDir -Force | Out-Null

# TODO: ACL harden $tokenDir and $tokenPath (SYSTEM + Admins only)
# TODO: EVTX log: SecurityToken.Issue.Result

($envelope | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $tokenPath -Encoding UTF8

Write-Host ("[OK] Token issued: {0} (expires {1} UTC)" -f $tokenPath, $exp.ToString('o'))
Write-Host ("[OK] Scopes: {0}" -f ($Scopes -join ', '))
