# AURA Visual Upgrade

An in-game graphics dashboard and optional external visual-upgrade companion for Project Ascension.

**Author:** Srixun

**Community:** https://Discord.gg/AuraPub

**PvP'ers welcome.**

## Features

- Performance, Balanced, Quality, and five-second Recommended profiles
- Live FPS and output-resolution analysis
- Dynamic Smooth Motion targets, such as 60 real FPS to approximately 120 displayed FPS
- World detail, particles, weather, shadows, filtering, VSync, MSAA, and FPS controls
- Performance-hit and apply-method details for every setting
- DX11/DX12, ReShade, individual effect, and frame-generation requests
- Custom AURA minimap button and Interface Options About page
- `/auravis` chat command to open or close the configuration dashboard

## Installation

### Automatic

1. Download `AURA-Visual-Upgrade-Auto-Installer.zip` from the latest release.
2. Extract it.
3. Close Ascension.
4. Run `START HERE - Install AURA Visual Upgrade.cmd`.

The installer detects launcher and common install paths, verifies SHA-256 checksums, preserves the previous addon version, and installs atomically.

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

WoW addon Lua cannot access the internet or launch programs, so update checks cannot run from the in-game addon itself.

## Frame Generation

The addon dynamically shows the approximate doubled displayed-FPS target while Real Frame Cap is adjusted. NVIDIA Smooth Motion remains a manual or explicitly experimental driver-profile setting; addon Lua cannot control NVAPI.

## External Companion

The optional companion applies staged DX11/DX12 and ReShade requests after the client exits. It downloads dgVoodoo and ReShade from their official sources and verifies pinned hashes. No third-party renderer binaries or shaders are stored in this repository.

Unrestricted ReShade requests require the user to confirm that they have server approval.

## Privacy

AURA Visual Upgrade contains no telemetry. The installer contacts only GitHub Releases and the official dependency sources documented in the scripts.

## License

MIT License. See [LICENSE](LICENSE).
