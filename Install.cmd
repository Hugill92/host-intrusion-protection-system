@echo off
setlocal EnableExtensions

title Firewall Core Installer

REM Always run from repo root
cd /d "%~dp0"

REM --- Step 1: Core install (policy/baselines/tasks/etc) ---
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "_internal\Install-Firewall.ps1"
set "INSTALL_EXIT=%ERRORLEVEL%"

if not "%INSTALL_EXIT%"=="0" (
  echo [FATAL] Core install failed with exit code %INSTALL_EXIT%
  exit /b %INSTALL_EXIT%
)

REM --- Step 2: User notifier task (required) ---
echo Installing Firewall User Notifier scheduled task...

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0Firewall\Installs\Install-FirewallUserNotifierTask.ps1"
set "NOTIFY_EXIT=%ERRORLEVEL%"

if not "%NOTIFY_EXIT%"=="0" (
  echo [FATAL] Failed to install Firewall User Notifier task (exit %NOTIFY_EXIT%)
  exit /b %NOTIFY_EXIT%
) else (
  echo [OK] Firewall User Notifier task installed
)

exit /b 0
