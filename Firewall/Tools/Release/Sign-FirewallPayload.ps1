<#
Signs all signable payload scripts under a root folder.
- Signs: .ps1, .psm1, .psd1
- Does NOT sign: .cmd/.bat (not reliably Authenticode-signed for your use case)
- Requires a Code Signing cert with a private key.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$Root = "C:\Firewall",

  # Optional: pin to a thumbprint if you want deterministic signing
  [string]$Thumbprint = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function STEP($m){ Write-Host "[*] $m" }
function OK($m){ Write-Host "[OK] $m" }
function WARN($m){ Write-Warning $m }

function Get-CodeSignCert {
  param([string]$Thumbprint)

  $stores = @("Cert:\CurrentUser\My","Cert:\LocalMachine\My")
  $cands = foreach ($s in $stores) {
    Get-ChildItem $s -ErrorAction SilentlyContinue
  }

  if ($Thumbprint) {
    $cert = $cands | Where-Object { $_.Thumbprint -eq $Thumbprint -and $_.HasPrivateKey }
    if (-not $cert) { throw "No cert with private key found for thumbprint $Thumbprint" }
    return $cert | Select-Object -First 1
  }

  $cert = $cands | Where-Object {
    $_.HasPrivateKey -and
    ($_.EnhancedKeyUsageList.FriendlyName -contains "Code Signing")
  } | Sort-Object NotAfter -Descending | Select-Object -First 1

  if (-not $cert) { throw "No Code Signing cert with private key found in CurrentUser\My or LocalMachine\My" }
  return $cert
}

STEP "Signing payload under: $Root"
$cert = Get-CodeSignCert -Thumbprint $Thumbprint
OK ("Using cert: {0} ({1}) Expires={2}" -f $cert.Subject, $cert.Thumbprint, $cert.NotAfter)

$targets = Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
  Where-Object { $_.Extension -in ".ps1",".psm1",".psd1" }

STEP ("Found {0} files to sign" -f $targets.Count)

$failed = @()
foreach ($f in $targets) {
  try {
    # Skip already-valid signatures if you want: comment out if you want to re-sign every time
    $sig = Get-AuthenticodeSignature -FilePath $f.FullName
    if ($sig.Status -eq "Valid") {
      continue
    }

    Set-AuthenticodeSignature -FilePath $f.FullName -Certificate $cert -TimestampServer "http://timestamp.digicert.com" | Out-Null
  } catch {
    $failed += $f.FullName
    WARN ("Failed to sign: {0} :: {1}" -f $f.FullName, $_.Exception.Message)
  }
}

if ($failed.Count -gt 0) {
  throw ("Signing failed for {0} files. Fix and re-run." -f $failed.Count)
}

OK "Signing complete"
