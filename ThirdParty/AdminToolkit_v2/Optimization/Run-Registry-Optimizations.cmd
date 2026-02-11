@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: =====================================================
:: Registry Optimization Launcher (Apply Only)
:: =====================================================
:: Use this when you want ONLY to apply (no verification step).
:: Output is written into: .\Logs and .\Backups (same folder as this cmd).
:: =====================================================

:: --- Admin check ---
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo [ERROR] This script must be run as Administrator.
  pause
  exit /b 1
)

:: --- Paths ---
set SCRIPT_DIR=%~dp0
if "%SCRIPT_DIR:~-1%"=="\" set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

set PS_SCRIPT=%SCRIPT_DIR%\Registry_Optimizations.ps1

if not exist "%PS_SCRIPT%" (
  echo [ERROR] Registry optimization script not found:
  echo %PS_SCRIPT%
  pause
  exit /b 2
)

:: --- Logging ---
set LOGDIR=%SCRIPT_DIR%\Logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

set TS=%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set TS=%TS: =0%
set LOGFILE=%LOGDIR%\RegistryOpt_Console_%TS%.log

echo =============================================== > "%LOGFILE%"
echo Registry Optimization (Apply Only) >> "%LOGFILE%"
echo Time: %DATE% %TIME% >> "%LOGFILE%"
echo WorkingDir: %SCRIPT_DIR% >> "%LOGFILE%"
echo =============================================== >> "%LOGFILE%"

echo Running registry optimizations...
echo.

powershell.exe ^
  -NoLogo ^
  -NoProfile ^
  -NonInteractive ^
  -ExecutionPolicy Bypass ^
  -File "%PS_SCRIPT%" ^
  -OutputDir "%SCRIPT_DIR%" ^
  -AlsoWriteProgramDataAudit ^
  %* >> "%LOGFILE%" 2>&1

set RC=%ERRORLEVEL%

echo =============================================== >> "%LOGFILE%"
echo Finished with ExitCode=%RC% >> "%LOGFILE%"
echo =============================================== >> "%LOGFILE%"

echo.
echo Registry optimization complete.
echo Log: %LOGFILE%
echo.

pause
exit /b %RC%
