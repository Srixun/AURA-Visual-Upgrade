@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AscensionGraphicsProfiles.ps1" -Profile DX12FrameGeneration
if errorlevel 1 goto done
echo.
echo The game profile is ready. In NVIDIA App:
echo   1. Open Graphics, then Program Settings.
echo   2. Add the selected Ascension.exe if it is not listed.
echo   3. Set Smooth Motion to On.
echo   4. Launch Ascension.
if exist "C:\Program Files\NVIDIA Corporation\NVIDIA App\CEF\NVIDIA App.exe" start "" "C:\Program Files\NVIDIA Corporation\NVIDIA App\CEF\NVIDIA App.exe"
:done
echo.
pause
