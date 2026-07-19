ASCENSION MODERN GRAPHICS SETUP
===============================

Companion version 0.4.0 by Srixun

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
- Reported video memory: preserves an existing dgVoodoo value; otherwise uses the official package default
- dgVoodoo watermark: disabled
- Watermark removal is re-applied by graphics profiles, ReShade, and AURA sync
- Resolution and antialiasing remain controlled by Ascension
- Modern flip-discard presentation model

GRAPHICS PROFILES
-----------------
After installing the wrapper, run "Set Graphics Profile.cmd" and select:

- DX11 Balanced: recommended and most compatible, 4x MSAA
- DX12 Balanced: optional D3D12 test, 4x MSAA
- DX12 Performance: 2x MSAA and reduced scene distance
- DX12 Quality: 4x MSAA, longer scene distance and improved shadows
- DX12 Frame Generation: NVIDIA-only real-FPS cap derived from the configured refresh rate

Ordinary profiles preserve the existing frame cap, texture filtering, and
dgVoodoo VRAM value. Renderer and MSAA changes occur only when the selected
external profile explicitly requests them.

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
The optional ReShade setup installs ReShade 6.7.3 after dgVoodoo so the
renderer chain is:

  Ascension D3D9 -> dgVoodoo D3D12 -> ReShade

Balanced uses half-rate MXAO and restrained fake bounce lighting for the best
quality/performance tradeoff. Cinematic raises AO quality, bounce lighting,
bloom, grading, and sharpening at a higher cost. Press Home for the ReShade
menu or Scroll Lock to toggle all effects for comparison.

Depth effects require single-sample rendering, so ReShade changes MSAA to 1x.
It does not change the frame cap. A per-client High DPI override is available
only through the explicit script option; it is not enabled by default.

The installer downloads the official unrestricted ReShade build and shader
sources from their authors, verifies pinned SHA-256 hashes, and keeps a full
.reshade-backup. Use "Uninstall ReShade.cmd" to restore the prior DXGI hook,
dgVoodoo settings, Config.wtf, shader directory, and High DPI registry value.
Unrestricted multiplayer depth access enables MXAO and bounce lighting but can
conflict with server policy or anti-cheat. It is disabled unless explicitly
selected by the user.

AURA IN-GAME ADDON
------------------
The wizard's ReShade options also install "AURA Visual Upgrade" 0.4.0 by
Srixun under
Interface\AddOns. Use /auravis, the AV minimap button, or Interface Options to
open its in-game dashboard. The addon provides:

- Performance, Raid, Balanced, and Quality profiles plus a 15-second benchmark
- Hardware-neutral Adaptive Optimization with measured average and low FPS
- World detail, particle, shadow, filtering, MSAA, VSync, and FPS controls
- Performance-hit and apply-method text under every setting
- Staged settings with one Apply button and a confirmed RestartGx prompt
- DX11/DX12, ReShade profile/effect, and Smooth Motion request controls
- Live real-FPS to approximate Smooth Motion displayed-FPS targets
- About and Interface Options launch buttons
- Peer-reported update awareness and capability-aware CVar controls

Community: https://Discord.gg/AuraPub - PvP'ers welcome.

The recommendation uses measured FPS stability and gameplay context. WoW addons cannot identify
the physical GPU, driver, injected DLLs, or NVIDIA settings, so the result is
clearly labeled as an estimate.

EXTERNAL SYNC
-------------
Addon Lua cannot edit dgVoodoo/ReShade files or NVIDIA settings. After applying
an external request in-game, log out completely and run
"AURA Visual Sync and Launch.cmd". It reads AURA's SavedVariables, applies the
explicitly requested renderer and ReShade settings while the client is closed, and starts
Ascension. Individual MXAO, bounce-lighting, bloom, grading, and sharpening
requests are reflected in the selected ReShade preset.

The sync launcher checks GitHub Releases for an addon update before applying
external settings. Downloads must match the release SHA-256 asset. If GitHub is
offline, the verified bundled addon remains available.

Smooth Motion remains a manual NVIDIA App setting. The addon records only a
self-reported confirmation; sync preserves the current frame cap. The sync
uses unrestricted ReShade only when Enable Unrestricted ReShade is checked
in-game.

BACKUP AND UNINSTALL
--------------------
Original graphics files are copied to .dx11-wrapper-backup inside the selected
Ascension folder. Reinstalling never overwrites that first backup.

Run "Uninstall Ascension DX11.cmd" to verify and restore the original files.
The backup is retained with a timestamp after a successful uninstall.

NOTES
-----
- The Ascension launcher may repair or replace d3d9.dll during an update.
  If it does, uninstall ReShade first, then rerun the wrapper installer so it
  can archive the old-generation backup and capture a fresh client baseline.
- ReShade backups created before v0.4 have no completion manifest. Review the
  backup contents and pass -MigrateLegacyBackup once to accept a legacy backup.
- dgVoodooCpl.exe is installed beside Ascension.exe for advanced configuration.
- Do not manually delete .dx11-wrapper-backup before uninstalling.
- The optional High DPI compatibility value is applied only when explicitly requested;
  uninstall restores or removes that exact value. No system DirectX file is changed.

Command-line usage:
  powershell -ExecutionPolicy Bypass -File AscensionDX11.ps1 -Action Install -InstallPath "E:\Games\Ascension"
  powershell -ExecutionPolicy Bypass -File AscensionDX11.ps1 -Action Install -Renderer DX12 -InstallPath "E:\Games\Ascension"
  powershell -ExecutionPolicy Bypass -File AscensionDX11.ps1 -Action Uninstall -InstallPath "E:\Games\Ascension"
  powershell -ExecutionPolicy Bypass -File AscensionDX11.ps1 -Action Status -InstallPath "E:\Games\Ascension"
