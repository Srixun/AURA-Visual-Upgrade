@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AscensionReShade.ps1" -Action Install -Preset Cinematic
echo.
pause
