@echo off
REM ==========================================================
REM FirewallCore Installer Entrypoint (CMD-safe)
REM ==========================================================

REM /d disables AutoRun; keep cmd logic minimal
cmd /d /c "%~dp0_internal\Install-FirewallCore.ps1_launcher.cmd"
exit /b %ERRORLEVEL%
