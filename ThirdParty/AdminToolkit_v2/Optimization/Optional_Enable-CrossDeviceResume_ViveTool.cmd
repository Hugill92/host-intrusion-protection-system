@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM Optional: Enable Cross-Device Resume (Registry + ViVeTool)
REM ============================================================
REM - Writes logs into: .\Logs and .\Backups
REM - If using ViVeTool, ensure the ViveTool bundle is extracted to:
REM     .\Tools\ViveTool
REM ============================================================

REM --- Folder where THIS cmd lives ---
set WORKDIR=%~dp0
if "%WORKDIR:~-1%"=="\" set WORKDIR=%WORKDIR:~0,-1%

echo ============================================================
echo Working Folder:
echo   %WORKDIR%
echo ============================================================

if not exist "%WORKDIR%\CrossDeviceResume.ps1" (
  echo [FATAL] CrossDeviceResume.ps1 not found.
  pause
  exit /b 2
)

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
  -File "%WORKDIR%\CrossDeviceResume.ps1" ^
  -OutputDir "%WORKDIR%" ^
  -Mode Enable -UseViveTool ^
  -AlsoWriteProgramDataAudit

echo.
echo COMPLETE ✅
pause
exit /b 0
