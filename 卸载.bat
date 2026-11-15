@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Action Uninstall
if errorlevel 1 (pause & exit /b 1)
pause