@echo off
setlocal
title AURA Visual Upgrade Status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AURAVisualUpgrade.ps1" -Action Status
echo.
pause
