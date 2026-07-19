# Changelog

## 0.4.0 - 2026-07-18

- Added hardware-neutral Adaptive Optimization using rolling FPS and approximate 10th-percentile lows.
- Added selectable optimizer targets and Stable, Balanced, and Quality behavior goals.
- Added a 15-second context-aware benchmark and Performance, Raid, Balanced, or Quality recommendation.
- Added verified one-setting reductions, cooldowns, post-change benefit checks, conservative recovery probes, and retained baseline restoration.
- Added world-transition warm-up, VSync/frame-cap awareness, likely background-throttle filtering, per-CVar ownership, and external-change detection.
- Kept projected textures, view distance, spell-particle density, frame caps, textures, restart-required settings, renderer, ReShade, and frame generation outside automatic control.
- Removed fixed frame-cap, renderer, ReShade, and hardware assumptions from game profiles.
- Added a draggable minimap button with a persisted position.
- Rebuilt the dashboard with native WotLK dialog, button, close-button, slider, scroll-frame, parchment, border, and portrait assets.
- Added modular Lua themes, ordered skin providers, and optional LibSharedMedia resolution for third-party UI integrations.
- Made companion external sync an explicit opt-in and changed ordinary companion profiles to preserve existing frame-cap and VRAM values.
- Fixed MSAA changes being reported as failed while Ascension was waiting for a graphics restart to update the live CVar.
- Replaced the ReShade approval confirmation with an explicit unrestricted-depth option and a policy/anti-cheat risk explanation.

## 0.3.0 - 2026-07-18

- Added peer-reported version awareness through native addon messages.
- Added an update badge, manual peer check, and selectable official Releases link.
- Added a Raid graphics profile.
- Added capability-aware controls for Ascension-specific and standard safe graphics CVars.
- Hide unsupported CVar controls and keep `gxFixLag` out of every profile.

## 0.2.0 - 2026-07-18

- Updated author metadata to Srixun.
- Added dynamic real-FPS and Smooth Motion displayed-FPS targets.
- Added the fitted circular AURA minimap icon.
- Added the main dashboard About button and expanded Interface Options page.
- Added `/auravis` guidance and AURA community information.
- Added the standalone auto-installer with backups and integrity verification.
- Added GitHub Releases update checks with SHA-256 validation.

## 0.1.0 - 2026-07-18

- Initial public-preview implementation.
- Added graphics profiles, staged CVar controls, and external request bridge.
