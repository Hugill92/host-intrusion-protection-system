@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: =====================================================
:: Windows System Repair (DISM + SFC)
:: Supports Online and Offline Images
:: Outputs JSON for automation / Admin Panel
:: =====================================================

:: ---------------- ADMIN CHECK ----------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Must be run as Administrator.
    pause
    exit /b 1
)

:: ---------------- PARAMETERS ----------------
:: Optional offline image path:
:: System-Repair.cmd "D:\MountedImage"

set IMAGE_PATH=%~1
set MODE=Online

if defined IMAGE_PATH (
    if not exist "%IMAGE_PATH%\Windows" (
        echo ERROR: Invalid offline image path.
        echo Path must contain \Windows directory.
        pause
        exit /b 2
    )
    set MODE=Offline
)

:: ---------------- LOG PATHS ----------------
set LOGROOT=%SystemRoot%\Logs\SystemRepair
if not exist "%LOGROOT%" mkdir "%LOGROOT%"

set TS=%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set TS=%TS: =0%

set LOGFILE=%LOGROOT%\Repair_%TS%.log
set JSONFILE=%LOGROOT%\Repair_%TS%.json

:: ---------------- START LOG ----------------
echo ===================================================== > "%LOGFILE%"
echo System Repair Started >> "%LOGFILE%"
echo Mode: %MODE% >> "%LOGFILE%"
echo Time: %DATE% %TIME% >> "%LOGFILE%"
echo ===================================================== >> "%LOGFILE%"

:: ---------------- DISM ----------------
echo Running DISM (%MODE%)...
echo [DISM START] >> "%LOGFILE%"

if "%MODE%"=="Online" (
    DISM /Online /Cleanup-Image /RestoreHealth >> "%LOGFILE%" 2>&1
) else (
    DISM /Image:"%IMAGE_PATH%" /Cleanup-Image /RestoreHealth >> "%LOGFILE%" 2>&1
)

set DISM_RC=%ERRORLEVEL%
echo [DISM END] ExitCode=%DISM_RC% >> "%LOGFILE%"

:: ---------------- SFC ----------------
echo Running SFC...
echo [SFC START] >> "%LOGFILE%"

if "%MODE%"=="Online" (
    sfc /scannow >> "%LOGFILE%" 2>&1
) else (
    sfc /scannow /offbootdir=%IMAGE_PATH%\ /offwindir=%IMAGE_PATH%\Windows >> "%LOGFILE%" 2>&1
)

set SFC_RC=%ERRORLEVEL%
echo [SFC END] ExitCode=%SFC_RC% >> "%LOGFILE%"

:: ---------------- RESULT ----------------
set RESULT=Success
if not "%DISM_RC%"=="0" set RESULT=DISM_Error
if not "%SFC_RC%"=="0" set RESULT=SFC_Error

:: ---------------- JSON OUTPUT ----------------
(
echo {
echo   "tool": "SystemRepair",
echo   "mode": "%MODE%",
echo   "timestamp": "%DATE% %TIME%",
echo   "imagePath": "%IMAGE_PATH%",
echo   "dismExitCode": %DISM_RC%,
echo   "sfcExitCode": %SFC_RC%,
echo   "result": "%RESULT%",
echo   "logFile": "%LOGFILE%"
echo }
) > "%JSONFILE%"

:: ---------------- FINAL ----------------
echo ===================================================== >> "%LOGFILE%"
echo Repair Finished >> "%LOGFILE%"
echo Result: %RESULT% >> "%LOGFILE%"
echo ===================================================== >> "%LOGFILE%"

echo.
echo === Repair Complete ===
echo Mode: %MODE%
echo Result: %RESULT%
echo Log:  %LOGFILE%
echo JSON: %JSONFILE%
echo.

pause
exit /b 0
