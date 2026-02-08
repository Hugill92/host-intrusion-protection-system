@echo off
setlocal
call "%~dp0Commands\%~nx0" %*
exit /b %ERRORLEVEL%
