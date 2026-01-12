<#
Patch-FirewallNotifier.ps1
Creates a repeatable patch that removes $repoRoot dependency from Invoke-FirewallNotifier.ps1
and fixes the Sounds path to use $PSScriptRoot\Sounds.

What it does:
- Stops any running notifier processes
- Patches repo + live copies (if present)
- Creates timestamped backups next to each patched file
- Optionally starts the notifier in a visible console

Run (Admin):
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Patch-FirewallNotifier.ps1 -Start

Or just patch without starting:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Patch-FirewallNotifier.ps1
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  # Repo root (where Firewall\Monitor\Invoke-FirewallNotifier.ps1 lives)
  [string]$RepoRoot = "C:\FirewallInstaller",

  # Live install root (where C:\Firewall\Monitor\Invoke-FirewallNotifier.ps1 lives)
  [string]$LiveRoot = "C:\Firewall",

  # Start notifier after patch (visible console)
  [switch]$Start,

  # Only patch repo copy (skip live)
  [switch]$RepoOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Stop-Notifier {
  Write-Host "[*] Stopping running notifier instances..." -ForegroundColor Cyan
  Get-CimInstance Win32_Process |
    Where-Object {
      ($_.Name -in @("powershell.exe","pwsh.exe")) -and
      ($_.CommandLine -like "*Invoke-FirewallNotifier.ps1*")
    } |
    ForEach-Object {
      try {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host ("    [OK] Stopped PID {0}" -f $_.ProcessId) -ForegroundColor Green
      } catch {}
    }
}

function Patch-File([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) {
    Write-Host "[SKIP] Not found: $Path" -ForegroundColor Yellow
    return $false
  }

  $ts  = Get-Date -Format "yyyyMMdd_HHmmss"
  $bak = "$Path.bak_$ts"

  if ($PSCmdlet.ShouldProcess($Path, "Backup + patch")) {
    Copy-Item -Force -LiteralPath $Path -Destination $bak

    $s = Get-Content -LiteralPath $Path -Raw -Encoding UTF8

    # Replace known bad Sounds patterns that depend on $repoRoot
    $s2 = $s
    $s2 = $s2 -replace 'Join-Path\s+\$repoRoot\s+"Firewall\\Sounds"\)', 'Join-Path $PSScriptRoot "Sounds")'
    $s2 = $s2 -replace "Join-Path\s+\`$repoRoot\s+'Firewall\\Sounds'\)", 'Join-Path $PSScriptRoot "Sounds")'
    $s2 = $s2 -replace 'Join-Path\s+\$repoRoot\s+"Firewall\\Sounds"', 'Join-Path $PSScriptRoot "Sounds"'
    $s2 = $s2 -replace "Join-Path\s+\`$repoRoot\s+'Firewall\\Sounds'", 'Join-Path $PSScriptRoot "Sounds"'

    # If script still references $repoRoot anywhere, inject a defensive block so it can never crash
    if ($s2 -match '\$repoRoot') {
      $inject = @'
# ---- PATCH: remove repoRoot dependency (injected) ----
if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
  $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
# repoRoot is NOT reliable across process boundaries; do not require it
# -----------------------------------------------------
'@

      # Insert after #requires if present, else prepend
      if ($s2 -match '(?m)^\s*#requires[^\r\n]*\r?\n') {
        $s2 = [regex]::Replace($s2, '(?m)^\s*#requires[^\r\n]*\r?\n', '$0' + $inject, 1)
      } else {
        $s2 = $inject + "`r`n" + $s2
      }
    }

    Set-Content -LiteralPath $Path -Value $s2 -Encoding UTF8 -Force

    Write-Host "[OK] Patched: $Path" -ForegroundColor Green
    Write-Host "     Backup: $bak" -ForegroundColor DarkGray

    return $true
  }

  return $false
}

function Start-Notifier([string]$NotifierPath) {
  if (!(Test-Path -LiteralPath $NotifierPath)) {
    throw "Notifier not found: $NotifierPath"
  }
  Write-Host "[*] Starting notifier (visible console): $NotifierPath" -ForegroundColor Cyan
  cmd.exe /k powershell.exe -NoProfile -ExecutionPolicy Bypass -Sta -File "`"$NotifierPath`""
}

# -------------------- MAIN --------------------

$repoNotifier = Join-Path $RepoRoot "Firewall\Monitor\Invoke-FirewallNotifier.ps1"
$liveNotifier = Join-Path $LiveRoot "Monitor\Invoke-FirewallNotifier.ps1"

Stop-Notifier

$patchedAny = $false
$patchedAny = (Patch-File $repoNotifier) -or $patchedAny

if (-not $RepoOnly) {
  $patchedAny = (Patch-File $liveNotifier) -or $patchedAny
}

# Quick verification: show remaining $repoRoot references (if any)
Write-Host ""
Write-Host "[*] Verifying repoRoot references..." -ForegroundColor Cyan
$hits = @()
$targets = @($repoNotifier)
if (-not $RepoOnly) { $targets += $liveNotifier }
foreach ($t in $targets) {
  if (Test-Path $t) {
    $hits += Select-String -Path $t -Pattern '\$repoRoot' -ErrorAction SilentlyContinue
  }
}
if ($hits.Count -gt 0) {
  Write-Host "[WARN] '$repoRoot' still appears in the notifier. Lines:" -ForegroundColor Yellow
  $hits | ForEach-Object { Write-Host ("  {0}:{1} {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()) }
} else {
  Write-Host "[OK] No '$repoRoot' references found." -ForegroundColor Green
}

if ($Start) {
  # Prefer live path if it exists, else repo path
if (Test-Path -LiteralPath $liveNotifier) {
  $toRun = $liveNotifier
} else {
  $toRun = $repoNotifier
}
Start-Notifier $toRun
} else {
  Write-Host ""
  Write-Host "[OK] Patch complete. Start later with:" -ForegroundColor Green
  Write-Host "     cmd.exe /k powershell.exe -NoProfile -ExecutionPolicy Bypass -Sta -File `"$liveNotifier`"" -ForegroundColor Gray
}


