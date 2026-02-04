$ErrorActionPreference = "Stop"
try {
  & "C:\FirewallInstaller\_internal\Install-FirewallCore.ps1" -Mode DEV
} catch {
  Write-Host "=== ERROR ===" -ForegroundColor Red
  Write-Host $_.Exception.GetType().FullName -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Host "=== POSITION ===" -ForegroundColor Red
  Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor Yellow
  Write-Host "=== STACK ===" -ForegroundColor Red
  Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
  exit 1
}
