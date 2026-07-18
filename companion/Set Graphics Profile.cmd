@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AscensionGraphicsProfiles.ps1"
echo.
pause
