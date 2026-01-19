[CmdletBinding()]
param(
  [switch]$ApplyPolicy,
  [switch]$RestartToast,
  [switch]$ArchiveQueue
)
$ErrorActionPreference = "Stop"
function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Repair requires elevation (Admin)." }
}
Assert-Admin

$logDir = "C:\Firewall\Logs\Repair"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir ("Repair_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
Start-Transcript -Path $log -Force | Out-Null

try {
  Write-Host "=== FirewallCore Repair ===" -ForegroundColor Cyan
  Write-Host ("Time: {0}" -f (Get-Date))
  Write-Host ""

  $repoRoot = "C:\FirewallInstaller"
  $regTasks = Join-Path $repoRoot "Tools\Register-FirewallCoreTasks.ps1"
  if (Test-Path $regTasks) {
    Write-Host "[STEP] Register/Enable tasks (repair)..." -ForegroundColor Cyan
    & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $regTasks -Force | Out-Host
  } else {
    Write-Host "[WARN] Tools\Register-FirewallCoreTasks.ps1 not found; skipping task re-register step." -ForegroundColor Yellow
  }

  $taskNames = @(
    "Firewall Tamper Guard",
    "Firewall User Notifier",
    "Firewall-Defender-Integration",
    "FirewallCore Toast Listener",
    "FirewallCore Toast Watchdog"
  )
  Write-Host "[STEP] Ensure tasks enabled..." -ForegroundColor Cyan
  foreach ($n in $taskNames) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($t) {
      try { Enable-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue | Out-Null } catch {}
    } else {
      Write-Host ("[WARN] Task missing: {0}" -f $n) -ForegroundColor Yellow
    }
  }

  if ($ArchiveQueue) {
    $arch = Join-Path $repoRoot "Tools\Archive-NotifyQueue.ps1"
    if (Test-Path $arch) {
      Write-Host "[STEP] Archive notify queue (preflight)..." -ForegroundColor Cyan
      & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $arch | Out-Host
    } else {
      Write-Host "[WARN] Tools\Archive-NotifyQueue.ps1 not found; skipping queue archive." -ForegroundColor Yellow
    }
  }

  if ($ApplyPolicy) {
    Write-Host "[STEP] Re-apply firewall policy..." -ForegroundColor Cyan
    $apply = Join-Path $repoRoot "Install\Apply-FirewallPolicy.ps1"
    if (-not (Test-Path $apply)) { throw "Missing policy apply script: $apply" }
    $out = Join-Path $logDir "ApplyPolicy_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $apply -CaptureBundle -AllowUnverified 1> $out 2>&1
    Write-Host ("[OK] Policy apply log: {0}" -f $out) -ForegroundColor Green
  }

  if ($RestartToast) {
    Write-Host "[STEP] Restart Toast tasks..." -ForegroundColor Cyan
    foreach ($n in @("FirewallCore Toast Listener","FirewallCore Toast Watchdog")) {
      try { Stop-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue | Out-Null } catch {}
      Start-Sleep -Milliseconds 300
      try { Start-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
  }

  Write-Host ""
  Write-Host "[OK] Repair completed." -ForegroundColor Green
  Write-Host "Task health:" -ForegroundColor Cyan
  "FirewallCore Toast Listener","FirewallCore Toast Watchdog" |
    ForEach-Object { Get-ScheduledTaskInfo -TaskName $_ } |
    Select-Object TaskName, LastRunTime, LastTaskResult, NextRunTime |
    Format-Table -AutoSize
  Write-Host ""
  Write-Host ("Rule count: {0}" -f ((Get-NetFirewallRule | Measure-Object).Count)) -ForegroundColor Cyan
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
}

