@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM Registry Optimization – FULL RUN + Cross-Device Resume Disable (Apply + Verify + Log Bundle)
REM ============================================================
REM - Must be run as Administrator
REM - Writes logs/backups into this folder: .\Logs and .\Backups
REM - Also writes an audit copy to: C:\ProgramData\RegistryOptimizations
REM ============================================================

REM --- Admin check ---
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo [ERROR] Run as Administrator.
  pause
  exit /b 1
)

REM --- Folder where THIS cmd lives ---
set WORKDIR=%~dp0
if "%WORKDIR:~-1%"=="\" set WORKDIR=%WORKDIR:~0,-1%

echo ============================================================
echo Working Folder:
echo   %WORKDIR%
echo ============================================================

REM --- Validate required files ---
if not exist "%WORKDIR%\Registry_Optimizations.ps1" (
  echo [FATAL] Registry_Optimizations.ps1 not found.
  pause
  exit /b 2
)

if not exist "%WORKDIR%\Verify-RegistryOptimizations.ps1" (
  echo [FATAL] Verify-RegistryOptimizations.ps1 not found.
  pause
  exit /b 3
)

echo.
echo [1/2] Applying registry optimizations...
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
  -File "%WORKDIR%\Registry_Optimizations.ps1" ^
  -OutputDir "%WORKDIR%" ^
  -IncludeCrossDeviceResume -AlsoWriteProgramDataAudit

if %errorlevel% neq 0 (
  echo [ERROR] Apply failed.
  pause
  exit /b 4
)

echo.
echo [2/2] Verifying registry optimizations...
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
  -File "%WORKDIR%\Verify-RegistryOptimizations.ps1" ^
  -DesktopFolder "%WORKDIR%"

echo.
echo ============================================================
echo COMPLETE ✅
echo.
echo Send-back bundle (this folder):
echo   - %WORKDIR%\Logs\RegistryOptimization_*.*
echo   - %WORKDIR%\RegistryOptimization_Verification_*.log
echo   - %WORKDIR%\Backups\*.reg
echo.
echo Audit copy (optional / local):
echo   - C:\ProgramData\RegistryOptimizations
echo ============================================================
pause
exit /b 0
