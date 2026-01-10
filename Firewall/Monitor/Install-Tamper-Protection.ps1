# Install-Tamper-Protection.ps1
# Installs/updates the scheduled task that runs Firewall-Tamper-Check.ps1 as SYSTEM.

param(
  [ValidateSet("DEV","LIVE")]
  [string]$Mode = "LIVE",

  [string]$FirewallRoot = "C:\FirewallInstaller\Firewall",

  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$TaskName   = "Firewall Tamper Guard"
$ScriptPath = Join-Path $FirewallRoot "Monitor\Firewall-Tamper-Check.ps1"

if (-not (Test-Path $ScriptPath)) {
  throw "Tamper check script missing: $ScriptPath"
}

$argString = @(
  "-NoProfile",
  "-ExecutionPolicy","Bypass",
  "-File","`"$ScriptPath`"",
  "-Mode",$Mode
) -join " "

$Action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argString
$Trigger   = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew

if ($Force) {
  try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}
}

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null

Write-Host "[OK] Installed scheduled task: $TaskName"
Write-Host "     Mode:  + $Mode"
Write-Host "     Script: $ScriptPath"
