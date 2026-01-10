<#
Bulk-Sign-Scripts.ps1

Purpose:
- Removes existing signatures
- Signs ALL PowerShell scripts in project
- Safe for clean VMs
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

$ProjectRoot = "C:\FirewallInstaller"
$CertName    = "FirewallInstaller-CodeSigning"

Write-Host "========================================="
Write-Host " Bulk Signing Firewall Installer Scripts"
Write-Host "========================================="

# Get cert
$cert = Get-ChildItem Cert:\LocalMachine\My |
    Where-Object { $_.Subject -like "*$CertName*" } |
    Select-Object -First 1

if (-not $cert) {
    Write-Error "Signing certificate not found. Run Create-CodeSigningCert.ps1 first."
    exit 1
}

# Collect scripts
$scripts = Get-ChildItem $ProjectRoot -Recurse `
    -Include *.ps1, *.psm1 `
    -File

foreach ($script in $scripts) {

    # Remove old signature if present
    $sig = Get-AuthenticodeSignature $script.FullName
    if ($sig.Status -ne 'NotSigned') {
        Write-Host "[CLEAR] $($script.FullName)"
        Set-AuthenticodeSignature -FilePath $script.FullName -RemoveSignature
    }

    # Sign
    Write-Host "[SIGN ] $($script.FullName)"
    Set-AuthenticodeSignature `
        -FilePath $script.FullName `
        -Certificate $cert `
        -TimestampServer "http://timestamp.digicert.com" |
        Out-Null
}

Write-Host ""
Write-Host "[OK] Bulk signing complete"
Write-Host ""
