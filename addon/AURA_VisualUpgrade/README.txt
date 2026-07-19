AURA VISUAL UPGRADE 0.3.0
=========================

Author: Srixun

Community: https://Discord.gg/AuraPub
PvP'ers welcome

Open the dashboard with /auravis, the AV minimap button, or Interface Options.
The About page in Interface Options contains an Open AURA Visuals Menu button.

Type /auravis in chat to toggle the configuration dashboard from anywhere
in-game. It does not immediately change graphics settings; settings remain
staged until Apply is pressed.

WHAT IT CONTROLS
----------------
- Game CVars for world detail, particles, weather, shadows, filtering, VSync,
  triple buffering, MSAA, and real-frame caps.
- Performance, Raid, Balanced, and Quality profiles.
- A five-second Recommended estimate based on live FPS and output resolution.
- Staged DX11/DX12, ReShade, individual post-processing, and Smooth Motion
  requests for the external AURA companion.
- Dynamic Smooth Motion targets on Real Frame Cap. For example, 60 real FPS
  displays approximately 120 FPS, while 90 real FPS displays approximately 180.
- Capability-aware Ascension controls. Unsupported CVars are hidden instead of
  being applied or reported as errors.

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
Windows registry, ReShade, dgVoodoo, or NVIDIA App. It also cannot execute an
external program. The Recommended result is therefore an estimate, not GPU
detection.

After applying an external request, log out completely and run
"AURA Visual Sync and Launch.cmd" from the companion graphics package. The
companion reads this addon's SavedVariables and applies the request while the
game is closed.

NVIDIA Smooth Motion cannot be enabled through a supported command-line API.
The in-game option records only your confirmation and stages the selected
real-frame cap. Enable Smooth Motion manually for Ascension.exe in NVIDIA App.

SAFETY
------
The unrestricted ReShade request requires an explicit confirmation that you
have Ascension staff approval. The checkbox records your statement; it does
not grant or verify permission.

Install only through trusted package sources. Never download paid or modified
ReShade shaders from unofficial mirrors.
