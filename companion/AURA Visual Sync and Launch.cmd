@echo off
setlocal
title AURA Visual Sync and Launch
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AURAVisualSync.ps1" -Action Apply -Launch
if errorlevel 1 pause
