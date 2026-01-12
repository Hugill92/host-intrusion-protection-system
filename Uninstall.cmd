@echo off
setlocal EnableExtensions
cd /d "%~dp0"

rem ---- Require Admin (UAC prompt) ----
net session >nul 2>&1
if %errorlevel% NEQ 0 (
  echo Requesting administrative privileges...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%ComSpec%' -ArgumentList '/c','\"\"%~f0\"\" %*' -Verb RunAs"
  exit /b
)

rem ---- Paths ----
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SCRIPT=%~dp0_internal\Uninstall-Firewall.ps1"

if not exist "%SCRIPT%" (
  echo [ERROR] Missing script: "%SCRIPT%"
  pause
  exit /b 1
)

rem ---- Logs (keep repo clean; _scratch is ignored) ----
set "LOGDIR=%~dp0_scratch\logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

for /f %%I in ('"%PSEXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "(Get-Date).ToString(''yyyyMMdd_HHmmss'')"' ) do set "TS=%%I"
if "%TS%"=="" set "TS=unknown_%RANDOM%"

set "LOG=%LOGDIR%\uninstall_%TS%.log"
set "DBG=%LOGDIR%\uninstall_%TS%_debug.txt"

echo [*] Running PowerShell uninstaller...
echo     Script: %SCRIPT%
echo     Log:    %LOG%
echo     Debug:  %DBG%

"%PSEXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SCRIPT%" -Force -IgnoreTamper -IgnoreDrift %* 1>>"%LOG%" 2>>"%DBG%"
set "RC=%errorlevel%"

if %RC% NEQ 0 (
  echo [ERROR] Uninstall failed (exit %RC%). See:
  echo   %DBG%
  pause
  exit /b %RC%
)

echo [OK] Uninstall completed.
echo Log: %LOG%
pause
exit /b 0
