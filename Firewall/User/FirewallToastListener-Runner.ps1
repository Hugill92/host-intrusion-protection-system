# FirewallToastListener-Runner.ps1 - single-instance supervisor (prevents spawn storms)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$CoreRoot = Join-Path $env:ProgramData "FirewallCore"
$LogDir   = Join-Path $CoreRoot "Logs"
$null = New-Item -ItemType Directory -Path $LogDir -Force
$RunnerLog = Join-Path $LogDir "ToastListener-Runner.log"

function Log([string]$msg) {
  $ts = (Get-Date).ToUniversalTime().ToString("o")
  "$ts [RUNNER] $msg" | Add-Content -LiteralPath $RunnerLog -Encoding UTF8
}

# Mutex prevents multiple runners per user session
$mutexName = "Global\FirewallCore.ToastListener.Runner"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
  Log "Runner already active. Exiting."
  return
}

$listener = "C:\Firewall\User\FirewallToastListener.ps1"
Log "Starting listener: $listener"

# Start ONE listener in hidden window
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
  "-NoLogo","-NoProfile","-STA","-ExecutionPolicy","Bypass",
  "-File", "`"$listener`""
)

# Keep runner alive so mutex holds; no respawn loop here.
while ($true) { Start-Sleep -Seconds 30 }
