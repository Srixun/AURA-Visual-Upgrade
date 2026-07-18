@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AscensionReShade.ps1" -Action Uninstall
echo.
pause
