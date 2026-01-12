@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Firewall Core Installer

cd /d "%~dp0"

:: Optional first arg: DEV or LIVE (default LIVE)
set MODE=%~1
if "%MODE%"=="" set MODE=LIVE

echo [*] Running installer (Mode=%MODE%)...

powershell.exe -NoProfile -ExecutionPolicy Bypass ^
  -File "%~dp0_internal\Install-Firewall.ps1" ^
  -Mode "%MODE%"

set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo [ERROR] Install failed with exit code %EXITCODE%
  exit /b %EXITCODE%
)

:: Optional: install user notifier task if script exists (legacy)
set USER_TASK="%~dp0Firewall\Install\Install-FirewallUserNotifierTask.ps1"
if exist %USER_TASK% (
  echo [*] Installing Firewall User Notifier scheduled task...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USER_TASK%
  if errorlevel 1 (
      echo [WARN] Failed to install Firewall User Notifier task
  ) else (
      echo [OK] Firewall User Notifier task installed
  )
) else (
  echo [INFO] User notifier task script not present; skipping.
)

exit /b 0
