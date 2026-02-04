@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Always run under cmd.exe (avoid PowerShell interpretation)
pushd "%~dp0.."

set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "LOGDIR=%ProgramData%\FirewallCore\Logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

REM ---- Locale-proof timestamp (no temp file, no echo-parsing hazards) ----
set "TS="
for /f "usebackq delims=" %%T in (`"%PS51%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Get-Date -Format yyyyMMdd_HHmmss"`) do set "TS=%%T"
if not defined TS set "TS=UNKNOWN_TS"

set "LOG=%LOGDIR%\Installer_Hardened_%TS%.log"

echo [INFO] Starting FirewallCore installer (hardened) > "%LOG%"
echo [INFO] RepoRoot=%CD%>> "%LOG%"
echo [INFO] PS51=%PS51%>> "%LOG%"

REM ---- Deterministic discovery (no PowerShell, no weird quoting) ----
set "SCRIPT="

if exist "%CD%\_internal\Install-FirewallCore.ps1" set "SCRIPT=%CD%\_internal\Install-FirewallCore.ps1"
if not defined SCRIPT if exist "%CD%\FirewallInstaller_internal\Install-FirewallCore.ps1" set "SCRIPT=%CD%\FirewallInstaller_internal\Install-FirewallCore.ps1"
if not defined SCRIPT if exist "%CD%\FirewallInstaller\FirewallInstaller_internal\Install-FirewallCore.ps1" set "SCRIPT=%CD%\FirewallInstaller\FirewallInstaller_internal\Install-FirewallCore.ps1"
if not defined SCRIPT if exist "%CD%\Install-FirewallCore.ps1" set "SCRIPT=%CD%\Install-FirewallCore.ps1"

REM Fallback: first match anywhere under repo root
if not defined SCRIPT (
  for /f "usebackq delims=" %%I in (`dir /b /s "Install-FirewallCore.ps1" 2^>nul`) do (
    set "SCRIPT=%%I"
    goto :FOUND
  )
)

:FOUND
if not defined SCRIPT (
  echo [ERROR] Could not locate installer script via discovery.>> "%LOG%"
  popd
  exit /b 2
)

echo [INFO] Script=%SCRIPT%>> "%LOG%"

"%PS51%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "%SCRIPT%" >> "%LOG%" 2>&1
set "PS_EXIT=%ERRORLEVEL%"

if %PS_EXIT% GEQ 1 (
  echo [WARN] Installer failed with exit code %PS_EXIT%>> "%LOG%"
) else (
  echo [OK] Installer completed with exit code %PS_EXIT%>> "%LOG%"
)

popd
exit /b %PS_EXIT%
