# AURA Visual Upgrade

An in-game, hardware-neutral graphics optimizer and optional external visual-upgrade companion for Project Ascension.

**Author:** Srixun

## Features

- Performance, Raid, Balanced, and Quality profiles that preserve user frame caps, textures, renderer, and ReShade
- Adaptive Optimization driven by measured rolling FPS and approximate 10th-percentile lows
- Stable, Balanced, and Quality optimizer goals with selectable 30-240 FPS targets
- A 15-second benchmark with context-aware profile recommendations
- Gradual one-setting changes, measurable-benefit checks, cooldowns, ownership-safe restoration, and explicit conflict recovery
- Live FPS, gameplay-context, target, active-change, and output-resolution reporting
- World detail, particles, weather, shadows, filtering, VSync, MSAA, and FPS controls
- Performance-hit and apply-method details for every setting
- Explicitly opted-in DX11/DX12, ReShade, individual-effect, and frame-generation requests
- Native WotLK dialog, button, slider, scroll-frame, parchment, border, and portrait styling
- Draggable AURA minimap button and Interface Options About page
- `/auravis`, `/auravis optimize`, and `/auravis benchmark` commands
- Capability-aware controls that hide unsupported client CVars
- Peer-reported in-game version awareness with an official release link

## Adaptive Safety

Adaptive Optimization measures the client instead of identifying a GPU or assuming a resolution. It waits through world transitions, respects foreground frame and VSync ceilings, avoids likely background-throttled samples, and verifies every CVar write. Keep the background cap distinct from an intentionally identical foreground target because WoW 3.3.5 exposes no reliable cross-platform focus API.

Automatic changes are limited to immediate cosmetic controls such as shadows, ground clutter, environment detail, and weather. Projected textures, view distance, spell-particle density, texture quality, MSAA, VSync, renderer selection, ReShade, and frame generation are never changed adaptively. AURA tracks only values it actually changes and will not overwrite a value changed elsewhere. Saved sessions load paused after a UI reload.

## Native Themes

The default `Warcraft` theme uses Blizzard WotLK interface textures and templates to match the game rather than presenting a flat desktop-style dashboard.

WoW 3.3.5 does not contain a browser or CSS engine, so it cannot import web CSS. Theme addons can provide the equivalent through Lua theme tables, immediate skin callbacks, and optional LibSharedMedia assets:

```lua
local AURA = _G.AURAVisualUpgrade

AURA:RegisterTheme("MyWarcraftSkin", {
    font = "Friz Quadrata TT",
    colors = {
        gold = { 1.0, 0.82, 0.0 },
        text = { 1.0, 0.96, 0.84 }
    }
})
AURA:SetTheme("MyWarcraftSkin")

AURA:RegisterSkinProvider("MySkinProvider", function(frame, kind, theme)
    -- Apply addon-specific styling for kinds such as window, button,
    -- setting-row, slider, section-header, and minimap-button.
end)
```

Declare AURA as a dependency to register a theme before `PLAYER_LOGIN`. Changing themes after the UI is built requires `/reload`; skin providers apply to existing and future AURA controls immediately.

## Installation

### Automatic

1. Download `AURA-Visual-Upgrade-Auto-Installer.zip` from the latest release.
2. Extract it.
3. Close Ascension.
4. Run `START HERE - Install AURA Visual Upgrade.cmd`.

The installer detects launcher and common install paths, verifies SHA-256 checksums, fully stages and verifies the replacement, preserves the previous addon version, and rolls back ordinary activation errors.

### Manual

Extract `AURA-Visual-Upgrade-Addon.zip` into:

```text
Ascension\Interface\AddOns
```

The resulting path must be:

```text
Ascension\Interface\AddOns\AURA_VisualUpgrade\AURA_VisualUpgrade.toc
```

## Automatic Updates

Every auto-installer run checks [GitHub Releases](https://github.com/Srixun/AURA-Visual-Upgrade/releases) for the latest version. Release downloads are installed only when they match the separately published SHA-256 asset.

Run `Check for AURA Updates.cmd` to require an online update check. The full companion's `AURA Visual Sync and Launch.cmd` also checks for addon updates before launching the game.

The in-game **Updates** panel and `/auravis update` can ask AURA users in your guild, party, or raid which version they run. Peer reports are informational and can be spoofed; verify every reported version on the official GitHub Releases page. WoW addon Lua cannot access the internet, verify GitHub, launch programs, or install files.

Use `/auravis acknowledge` to clear a persisted restart reminder after you have completed or deliberately dismissed the required restart/relog action.

## Frame Generation

The addon shows the approximate doubled displayed-FPS target while a frame-generation request is explicitly staged. Driver frame generation remains a manual or experimental companion setting; addon Lua cannot control driver APIs.

## External Companion

The optional companion applies explicitly staged DX11/DX12 and ReShade requests after the client exits. Ordinary external profiles preserve the existing frame cap and dgVoodoo VRAM setting; the frame-generation profile derives its real-FPS cap from the configured refresh rate. It downloads dgVoodoo and ReShade from their official sources and verifies pinned hashes. No third-party renderer binaries or shaders are stored in this repository.

The included ReShade profiles use the unrestricted add-on build for multiplayer depth access. This enables MXAO and bounce lighting but can conflict with server policy or anti-cheat. It is an explicit option and remains disabled unless selected by the user.

## Privacy

AURA Visual Upgrade contains no telemetry. The installer contacts only GitHub Releases and the official dependency sources documented in the scripts.

## License

MIT License. See [LICENSE](LICENSE).
