@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0\.."

set LOGDIR=%ProgramData%\FirewallCore\Logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

set TS=%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set TS=%TS: =0%
set LOG=%LOGDIR%\Uninstaller_Hardened_%TS%.log

echo [INFO] Starting FirewallCore uninstaller (hardened) > "%LOG%"
echo [INFO] RepoRoot=%CD% >> "%LOG%"

set SCRIPT=
if exist "%CD%\Uninstall-FirewallCore.ps1" set SCRIPT=%CD%\Uninstall-FirewallCore.ps1
if not defined SCRIPT if exist "%CD%\FirewallInstaller\Uninstall-FirewallCore.ps1" set SCRIPT=%CD%\FirewallInstaller\Uninstall-FirewallCore.ps1
if not defined SCRIPT if exist "%CD%\Uninstall-Firewall.ps1" set SCRIPT=%CD%\Uninstall-Firewall.ps1
if not defined SCRIPT if exist "%CD%\FirewallInstaller\Uninstall-Firewall.ps1" set SCRIPT=%CD%\FirewallInstaller\Uninstall-Firewall.ps1

if not defined SCRIPT if exist "%CD%\FirewallInstaller_internal\Uninstall-FirewallCore.ps1" set SCRIPT=%CD%\FirewallInstaller_internal\Uninstall-FirewallCore.ps1
if not defined SCRIPT if exist "%CD%\FirewallInstaller\FirewallInstaller_internal\Uninstall-FirewallCore.ps1" set SCRIPT=%CD%\FirewallInstaller\FirewallInstaller_internal\Uninstall-FirewallCore.ps1

if not defined SCRIPT (
  echo [ERROR] Could not locate uninstaller script. Tried: >> "%LOG%"
  echo [ERROR]   %CD%\Uninstall-FirewallCore.ps1 >> "%LOG%"
  echo [ERROR]   %CD%\FirewallInstaller\Uninstall-FirewallCore.ps1 >> "%LOG%"
  echo [ERROR]   %CD%\Uninstall-Firewall.ps1 >> "%LOG%"
  echo [ERROR]   %CD%\FirewallInstaller\Uninstall-Firewall.ps1 >> "%LOG%"
  exit /b 2
)

echo [INFO] Script=%SCRIPT% >> "%LOG%"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy AllSigned -File "%SCRIPT%" >> "%LOG%" 2>&1
set PS_EXIT=%ERRORLEVEL%

if %PS_EXIT% GEQ 1 (
  echo [WARN] Uninstaller failed with exit code %PS_EXIT% >> "%LOG%"
) else (
  echo [OK] Uninstaller completed with exit code %PS_EXIT% >> "%LOG%"
)

exit /b %PS_EXIT%

