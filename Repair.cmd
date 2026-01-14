@echo off
setlocal EnableExtensions
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0_internal\Repair-Firewall.ps1" %*
exit /b %errorlevel%

