REM ==========================================================
REM STEP 1 - CORE INSTALL (baseline-aware, deterministic)
REM ==========================================================

set "BASELINE_ROOT=%ProgramData%\FirewallCore\Baselines"
set "PREINSTALL_BASELINE="
set "FWCORE_BASELINE_MODE=Capture"

REM Detect existing PREINSTALL baseline (first match wins)
for /d %%D in ("%BASELINE_ROOT%\PREINSTALL_*") do (
    set "PREINSTALL_BASELINE=%%D"
    set "FWCORE_BASELINE_MODE=No-Op"
    goto :baseline_checked
)

:baseline_checked
if /i "%FWCORE_BASELINE_MODE%"=="No-Op" (
    echo [INFO] PREINSTALL baseline already exists
    echo [INFO] BaselineMode=No-Op enforced by installer
)

REM Sanitize PowerShell module path (PS5 only, AllSigned safe)
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" ^
 -NoLogo -NoProfile -NonInteractive ^
 -ExecutionPolicy AllSigned ^
 -File "%~dp0_internal\Install-FirewallCore.ps1" ^
 -Mode LIVE ^
 -BaselineMode %FWCORE_BASELINE_MODE%

set "INSTALL_EXIT=%ERRORLEVEL%"

if %INSTALL_EXIT% NEQ 0 (
    echo [FATAL] Core install failed with exit code %INSTALL_EXIT%
    exit /b %INSTALL_EXIT%
)
