@echo off
title Firewall Core Installer

cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_internal\Install-Firewall.ps1"

echo Installing Firewall User Notifier scheduled task...

powershell.exe -NoProfile -ExecutionPolicy Bypass ^
  -File "C:\FirewallInstaller\Firewall\Install\Install-FirewallUserNotifierTask.ps1"

if errorlevel 1 (
    echo [WARN] Failed to install Firewall User Notifier task
) else (
    echo [OK] Firewall User Notifier task installed
)


exit /b %ERRORLEVEL%
