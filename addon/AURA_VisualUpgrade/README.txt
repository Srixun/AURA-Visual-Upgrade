AURA VISUAL UPGRADE 0.4.0
=========================

Author: Srixun

Community: https://Discord.gg/AuraPub
PvP'ers welcome

Open the dashboard with /auravis, the draggable AV minimap button, or Interface Options.
The About page in Interface Options contains an Open AURA Visuals Menu button.

Type /auravis in chat to toggle the configuration dashboard from anywhere
in-game. It does not immediately change graphics settings; settings remain
staged until Apply is pressed.

Use /auravis acknowledge after completing or deliberately dismissing a
persisted graphics-restart, relog, or client-restart reminder.

WHAT IT CONTROLS
----------------
- Game CVars for world detail, particles, weather, shadows, filtering, VSync,
  triple buffering, MSAA, and real-frame caps.
- Performance, Raid, Balanced, and Quality profiles.
- Hardware-neutral Adaptive Optimization with selectable FPS targets and
  Stable, Balanced, or Quality goals.
- A 15-second benchmark based on measured FPS stability and gameplay context.
- Staged, explicitly opted-in DX11/DX12, ReShade, individual post-processing,
  and Smooth Motion requests for the external AURA companion.
- Capability-aware Ascension controls. Unsupported CVars are hidden instead of
  being applied or reported as errors.

ADAPTIVE SAFETY
---------------
Adaptive Optimization changes no more than one immediate cosmetic setting at a
time, waits before evaluating again, and keeps a change only when measured frame
stability improves. It waits through zoning, respects frame and VSync ceilings,
tracks only settings it actually changes, and retains failed restores for retry.
Keep the background cap distinct from an identical foreground target because
the 3.3.5 client exposes no reliable cross-platform window-focus API.

Projected textures, view distance, spell-particle density, frame caps, texture quality, MSAA,
VSync, restart-required controls, renderer selection, ReShade, and frame
generation are never changed adaptively. A saved baseline can be restored, and
saved optimizer sessions load paused after a UI reload.

NATIVE THEMING
--------------
The Warcraft theme uses Blizzard WotLK dialog, parchment, border, portrait,
button, close-button, slider, and scroll-frame assets. WoW 3.3.5 has no browser
or CSS engine, so theme addons integrate with AURA:RegisterTheme,
AURA:RegisterSkinProvider, and optional LibSharedMedia assets instead of CSS.

UPDATE AWARENESS
----------------
The Updates button and /auravis update ask AURA users in your guild, party, or
raid which addon version they run. Reports are informational and can be spoofed;
always verify and install updates from the selectable official GitHub Releases
link. Addon Lua cannot contact GitHub or install files itself.

APPLY METHODS
-------------
Every setting lists its performance hit and apply method. Immediate settings
change when Apply is pressed. Graphics-restart settings offer one confirmed
RestartGx operation. Other settings clearly request a relog, full client
restart, external sync, or manual NVIDIA setting.

EXTERNAL LIMITATIONS
--------------------
World of Warcraft addon Lua cannot inspect the physical GPU, loaded DLLs,
Windows registry, ReShade, dgVoodoo, or driver applications. It also cannot
execute an external program. Optimization is based on measured client FPS, not
GPU detection.

After applying an external request, log out completely and run
"AURA Visual Sync and Launch.cmd" from the companion graphics package. The
companion reads this addon's SavedVariables and applies the request while the
game is closed.

NVIDIA Smooth Motion cannot be enabled through a supported command-line API.
The in-game option records only your confirmation and stages the selected
real-frame cap. Enable Smooth Motion manually for Ascension.exe in NVIDIA App.

SAFETY
------
Enable Unrestricted ReShade requests the add-on build with multiplayer depth
access for MXAO and bounce lighting. This can conflict with server policy or
anti-cheat, so it remains disabled unless you explicitly select it.

Install only through trusted package sources. Never download paid or modified
ReShade shaders from unofficial mirrors.
