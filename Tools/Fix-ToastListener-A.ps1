[CmdletBinding()]
param(
  [string]$ListenerPath = "C:\Firewall\User\FirewallToastListener.ps1",
  [string]$RunnerPath   = "C:\Firewall\User\FirewallToastListener-Runner.ps1",
  [switch]$Restart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Backup-File([string]$p) {
  if (!(Test-Path -LiteralPath $p)) { throw "Missing file: $p" }
  $bak = "{0}.bak_{1}" -f $p, (Get-Date -Format "yyyyMMdd_HHmmss")
  Copy-Item -LiteralPath $p -Destination $bak -Force
  return $bak
}

function Stop-ToastProcs {
  Get-CimInstance Win32_Process |
    Where-Object { $_.CommandLine -match 'FirewallToastListener(\-Runner)?\.ps1' } |
    ForEach-Object {
      try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {}
    }
}

if ($Restart) {
  Write-Host "[*] Stopping runner/listener processes..." -ForegroundColor Yellow
  Stop-ToastProcs
  Start-Sleep -Seconds 1
}

Write-Host "[*] Backing up listener..." -ForegroundColor Yellow
$bak1 = Backup-File $ListenerPath
Write-Host "[OK] Backup: $bak1" -ForegroundColor Green

$src  = Get-Content -LiteralPath $ListenerPath -Raw
$orig = $src

# Fix LaunchDialog quoting:
# "-PayloadPath", "`"$pathToJson`""
# -> "-PayloadPath", $pathToJson
$src = [regex]::Replace(
  $src,
  '(?im)(\s*"-PayloadPath"\s*,\s*)"`"\$pathToJson`""',
  '${1}$pathToJson'
)

# Ensure $QueueFolder is initialized (StrictMode-safe)
if ($src -notmatch '(?m)^\s*\$QueueFolder\s*=') {
  $re = [regex]'(?m)^(?<indent>\s*)\$QueueRoot\s*=\s*(?<rhs>.+)$'
  if ($re.IsMatch($src)) {
    $src = $re.Replace(
      $src,
      '${indent}$QueueRoot = ${rhs}' + "`r`n" + '${indent}$QueueFolder = Join-Path $QueueRoot "Pending"',
      1
    )
  } else {
    $src = '$QueueFolder = Join-Path $QueueRoot "Pending"' + "`r`n" + $src
  }
}

if ($src -eq $orig) {
  Write-Host "[SKIP] No changes detected (listener already patched?)" -ForegroundColor Yellow
} else {
  Set-Content -LiteralPath $ListenerPath -Value $src -Encoding UTF8
  Write-Host "[OK] Patched listener: $ListenerPath" -ForegroundColor Green
}

if ($Restart) {
  if (!(Test-Path -LiteralPath $RunnerPath)) { throw "Missing runner: $RunnerPath" }

  Write-Host "[*] Starting runner..." -ForegroundColor Yellow
  Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
    "-NoLogo","-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
    "-File", "`"$RunnerPath`""
  )

  Write-Host "[OK] Runner started." -ForegroundColor Green
}
