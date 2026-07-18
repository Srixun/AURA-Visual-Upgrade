@echo off
setlocal
title Preview AURA Visual Request
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AURAVisualSync.ps1" -Action Preview
echo.
pause
