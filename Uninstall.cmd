@echo off@echo off
:: Auto-elevate to admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Now running elevated
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "_internal\Install-Firewall.ps1"
pause


:: ---- Require Admin ----
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please run this uninstaller as Administrator.
    pause
    exit /b 1
)

set ROOT=%~dp0
set PS=%ROOT%_internal\Uninstall-Firewall.ps1
set LOG=%ROOT%uninstall-debug.txt

if not exist "%PS%" (
    echo [ERROR] Missing Uninstall-Firewall.ps1
    pause
    exit /b 1
)

echo.
echo Choose uninstall mode:
echo   [1] Safe uninstall (keep signing certs for reinstall)
echo   [2] Full/Clean uninstall (remove certs, restore defaults)
echo.

set /p MODE=Enter choice (1 or 2): 

if "%MODE%"=="1" (
    set FLAG=-KeepCerts
) else if "%MODE%"=="2" (
    set FLAG=-RemoveCerts
) else (
    echo Invalid choice.
    pause
    exit /b 1
)

echo [*] Running PowerShell uninstaller...
powershell.exe -NoProfile -ExecutionPolicy Bypass ^
  -File "%PS%" %FLAG% ^
  *> "%LOG%" 2>&1

if %errorlevel% neq 0 (
    echo [ERROR] Uninstall failed. See uninstall-debug.txt
    pause
    exit /b 1
)

echo [OK] Firewall Core removed successfully.
echo Log: %LOG%
pause
exit /b 0
