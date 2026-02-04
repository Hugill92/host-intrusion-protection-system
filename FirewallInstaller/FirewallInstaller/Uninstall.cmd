@echo off
setlocal

REM FirewallCore Uninstall (Default)
REM Hidden launch contract: powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden

set "ROOT=%~dp0"
set "PS=powershell.exe"
set "SCRIPT=%ROOT%Tools\Uninstall\Uninstall-FirewallCore.ps1"

"%PS%" -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy AllSigned -File "%SCRIPT%" -Mode Default
set "RC=%ERRORLEVEL%"
exit /b %RC%
