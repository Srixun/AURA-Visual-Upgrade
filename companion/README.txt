ASCENSION MODERN GRAPHICS SETUP
===============================

EASIEST SETUP
-------------
Run "START HERE - Ascension Graphics Setup.cmd". It automatically reads the official
Ascension Launcher's cached install location, checks common locations on each
drive, labels multiple clients, and presents every renderer/profile option in
one numbered console menu. Manual folder selection is available as fallback.

This installer configures a 32-bit Ascension client to use dgVoodoo2's
Direct3D 9 to Direct3D 11 or Direct3D 12 translation wrapper. Optional ReShade
presets add depth-aware ambient occlusion, approximate bounce lighting, bloom,
color grading, and sharpening to the D3D12 output.

INSTALL
-------
1. Close every running Ascension client.
2. Run "Install Ascension DX11.cmd" for maximum compatibility, or
   "Install Ascension DX12.cmd" to test the D3D12 feature-level 12 backend.
3. Select the folder containing Ascension.exe.
4. Start Ascension normally.

The installer downloads dgVoodoo2 2.87.3 from the author's official GitHub
release and verifies its SHA-256 hash before installing anything.

SETTINGS
--------
- Output API: Direct3D 11 feature level 11.0 or Direct3D 12 feature level 12.0
- Reported video memory: 2048 MB
- dgVoodoo watermark: disabled
- Watermark removal is re-applied by graphics profiles, ReShade, and AURA sync
- Resolution and antialiasing remain controlled by Ascension
- Modern flip-discard presentation model

GRAPHICS PROFILES
-----------------
After installing the wrapper, run "Set Graphics Profile.cmd" and select:

- DX11 Balanced: most compatible, 4x MSAA, 162 FPS cap
- DX12 Balanced: recommended D3D12 test, 4x MSAA, 162 FPS cap
- DX12 Performance: 2x MSAA and reduced scene distance
- DX12 Quality: 4x MSAA, longer scene distance and improved shadows
- DX12 Frame Generation: 80 real FPS target for approximately 160 displayed FPS

At 5120x2160, 4x MSAA provides excellent edge quality with much less bandwidth
than 8x MSAA. Filtering remains application-controlled because Ascension's
textureFilteringMode 5 already requests its highest filtering level.

Profiles preserve the original dgVoodoo.conf and WTF\Config.wtf in
.graphics-profile-backup. Select Restore to put those settings back.

FRAME GENERATION
----------------
Run "Set Up Frame Generation.cmd" after closing Ascension. It applies the
DX12 Frame Generation profile and opens NVIDIA App. Add Ascension.exe under
Graphics > Program Settings and enable Smooth Motion. Smooth Motion is a
driver-level frame generator and does not require native game integration.

RESHADE
-------
The wizard's recommended option installs ReShade 6.7.3 after dgVoodoo so the
renderer chain is:

  Ascension D3D9 -> dgVoodoo D3D12 -> ReShade -> RTX GPU

Balanced uses half-rate MXAO and restrained fake bounce lighting for the best
quality/performance tradeoff. Cinematic raises AO quality, bounce lighting,
bloom, grading, and sharpening at a higher cost. Press Home for the ReShade
menu or Scroll Lock to toggle all effects for comparison.

Depth effects require single-sample rendering, so ReShade profiles change 4x
MSAA to 1x. At native 5120x2160, post-processing and sharpening provide a
better result than losing depth access. A per-client High DPI override ensures
Windows scaling does not reduce borderless rendering to 4096x1728.

The installer downloads the official unrestricted ReShade build and shader
sources from their authors, verifies pinned SHA-256 hashes, and keeps a full
.reshade-backup. Use "Uninstall ReShade.cmd" to restore the prior DXGI hook,
dgVoodoo settings, Config.wtf, shader directory, and High DPI registry value.
Only use the unrestricted multiplayer depth build with explicit Ascension
staff approval.

AURA IN-GAME ADDON
------------------
The recommended ReShade setup also installs "AURA Visual Upgrade" 0.3.0 by
Srixun under
Interface\AddOns. Use /auravis, the AV minimap button, or Interface Options to
open its in-game dashboard. The addon provides:

- Performance, Raid, Balanced, Quality, and five-second Recommended analysis
- World detail, particle, shadow, filtering, MSAA, VSync, and FPS controls
- Performance-hit and apply-method text under every setting
- Staged settings with one Apply button and a confirmed RestartGx prompt
- DX11/DX12, ReShade profile/effect, and Smooth Motion request controls
- Live real-FPS to approximate Smooth Motion displayed-FPS targets
- About and Interface Options launch buttons
- Peer-reported update awareness and capability-aware CVar controls

Community: https://Discord.gg/AuraPub - PvP'ers welcome.

The recommendation uses live FPS and resolution. WoW addons cannot identify
the physical GPU, driver, injected DLLs, or NVIDIA settings, so the result is
clearly labeled as an estimate.

EXTERNAL SYNC
-------------
Addon Lua cannot edit dgVoodoo/ReShade files or NVIDIA settings. After applying
an external request in-game, log out completely and run
"AURA Visual Sync and Launch.cmd". It reads AURA's SavedVariables, applies the
requested renderer and ReShade settings while the client is closed, and starts
Ascension. Individual MXAO, bounce-lighting, bloom, grading, and sharpening
requests are reflected in the selected ReShade preset.

The sync launcher checks GitHub Releases for an addon update before applying
external settings. Downloads must match the release SHA-256 asset. If GitHub is
offline, the verified bundled addon remains available.

Smooth Motion remains a manual NVIDIA App setting. The addon records only a
self-reported confirmation and adjusts the requested real-frame cap. The sync
refuses unrestricted ReShade unless the in-game staff-approval confirmation is
checked.

BACKUP AND UNINSTALL
--------------------
Original graphics files are copied to .dx11-wrapper-backup inside the selected
Ascension folder. Reinstalling never overwrites that first backup.

Run "Uninstall Ascension DX11.cmd" to verify and restore the original files.
The backup is retained with a timestamp after a successful uninstall.

NOTES
-----
- The Ascension launcher may repair or replace d3d9.dll during an update.
  Run this installer again afterward if the wrapper is removed.
- dgVoodooCpl.exe is installed beside Ascension.exe for advanced configuration.
- Do not manually delete .dx11-wrapper-backup before uninstalling.
- ReShade mode adds only a per-client High DPI compatibility value under HKCU;
  uninstall restores or removes that exact value. No system DirectX file is changed.

Command-line usage:
  powershell -ExecutionPolicy Bypass -File AscensionDX11.ps1 -Action Install -InstallPath "E:\Games\Ascension"
  powershell -ExecutionPolicy Bypass -File AscensionDX11.ps1 -Action Install -Renderer DX12 -InstallPath "E:\Games\Ascension"
  powershell -ExecutionPolicy Bypass -File AscensionDX11.ps1 -Action Uninstall -InstallPath "E:\Games\Ascension"
  powershell -ExecutionPolicy Bypass -File AscensionDX11.ps1 -Action Status -InstallPath "E:\Games\Ascension"
