@echo off
set "PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SCRIPT=%~dp0Install-FirewallCore.ps1"

"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned ^
  -File "%SCRIPT%" -Mode LIVE

exit /b %ERRORLEVEL%
