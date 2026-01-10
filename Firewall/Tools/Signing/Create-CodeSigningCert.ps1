<#
Create-CodeSigningCert.ps1

Purpose:
- Creates a fresh self-signed code-signing certificate
- Removes any previous Firewall signing certs
- Trusts the cert automatically (LocalMachine)
#>

# ================= AUTO-ELEVATION =================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}
# ==================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$CertName = "FirewallInstaller-CodeSigning"

Write-Host "========================================="
Write-Host " Creating Code Signing Certificate"
Write-Host "========================================="

# Remove old certs (if any)
Get-ChildItem Cert:\LocalMachine\My |
    Where-Object { $_.Subject -like "*$CertName*" } |
    ForEach-Object {
        Write-Host "[REMOVE] Old cert $($_.Thumbprint)"
        Remove-Item $_.PSPath
    }

# Create new cert
$cert = New-SelfSignedCertificate `
    -Subject "CN=$CertName" `
    -Type CodeSigning `
    -KeyUsage DigitalSignature `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -HashAlgorithm SHA256 `
    -KeyLength 4096 `
    -NotAfter (Get-Date).AddYears(5)

# Trust it
$rootStore = "Cert:\LocalMachine\Root"
Copy-Item $cert.PSPath $rootStore

Write-Host ""
Write-Host "[OK] Certificate created and trusted"
Write-Host " Thumbprint: $($cert.Thumbprint)"
Write-Host ""
