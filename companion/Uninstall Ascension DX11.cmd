@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AscensionDX11.ps1" -Action Uninstall
echo.
pause
