[CmdletBinding()]
param(
  [string]$Confirm
)
$ErrorActionPreference = "Stop"
function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Clean uninstall requires elevation (Admin)." }
}
Assert-Admin

Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue | Out-Null

if (-not $Confirm) {
  $Confirm = [Microsoft.VisualBasic.Interaction]::InputBox(
    "CLEAN UNINSTALL will remove FirewallCore ProgramData/logs and attempt to remove the script signing cert.`r`n`r`nType DELETE to proceed.",
    "FirewallCore Clean Uninstall",
    ""
  )
}
if ($Confirm -ne "DELETE") {
  Write-Host "[ABORT] Clean uninstall cancelled (confirmation not provided)." -ForegroundColor Yellow
  exit 2
}

$repoRoot = "C:\FirewallInstaller"
$logDir = "C:\Temp\FirewallCoreUninstall"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir ("CleanUninstall_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
Start-Transcript -Path $log -Force | Out-Null

try {
  Write-Host "=== FirewallCore Clean Uninstall ===" -ForegroundColor Cyan
  Write-Host ("Time: {0}" -f (Get-Date))
  Write-Host ""

  $unCmd = Join-Path $repoRoot "Uninstall.cmd"
  if (Test-Path $unCmd) {
    Write-Host "[STEP] Running standard uninstall first..." -ForegroundColor Cyan
    $p = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "`"$unCmd`"") -Wait -PassThru
    if ($p.ExitCode -ne 0) { Write-Host ("[WARN] Uninstall.cmd exit code: {0}" -f $p.ExitCode) -ForegroundColor Yellow }
  } else {
    Write-Host "[WARN] Uninstall.cmd not found; continuing with cleanup-only steps." -ForegroundColor Yellow
  }

  Write-Host "[STEP] Extra cleanup (ProgramData + cert + event log clear)..." -ForegroundColor Cyan

  # Remove ProgramData artifacts
  $pd = "C:\ProgramData\FirewallCore"
  if (Test-Path $pd) {
    try { Remove-Item -LiteralPath $pd -Recurse -Force -ErrorAction Stop }
    catch { Write-Host ("[WARN] Failed removing {0}: {1}" -f $pd, $_.Exception.Message) -ForegroundColor Yellow }
  }

  # Remove script-signing cert if present (Root + TrustedPublisher)
  $cand = @(
    "C:\Firewall\ScriptSigningCert.cer",
    "C:\FirewallInstaller\Install\Assets\ScriptSigningCert.cer"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($cand) {
    try {
      $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cand)
      $thumb = $cert.Thumbprint
      foreach ($storePath in @("Cert:\LocalMachine\Root","Cert:\LocalMachine\TrustedPublisher")) {
        $cpath = Join-Path $storePath $thumb
        if (Test-Path $cpath) {
          Remove-Item -LiteralPath $cpath -Force -ErrorAction SilentlyContinue
        }
      }
      Write-Host ("[OK] Removed cert thumbprint: {0}" -f $thumb) -ForegroundColor Green
    } catch {
      Write-Host ("[WARN] Cert removal failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
  } else {
    Write-Host "[WARN] ScriptSigningCert.cer not found; skipping cert removal." -ForegroundColor Yellow
  }

  # Clear FirewallCore custom log if it exists (safe; removal may require registry ops)
  try {
    wevtutil el | Select-String -SimpleMatch "FirewallCore" | Out-Null
    if ($LASTEXITCODE -eq 0) {
      try { wevtutil cl "FirewallCore" | Out-Null; Write-Host "[OK] Cleared FirewallCore event log." -ForegroundColor Green } catch {}
    }
  } catch {}

  Write-Host ""
  Write-Host "[OK] Clean uninstall complete." -ForegroundColor Green
  Write-Host ("Transcript: {0}" -f $log) -ForegroundColor Cyan
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
}

