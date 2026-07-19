# Contributing

1. Target Interface `30300` and Lua 5.1 syntax.
2. Keep the addon dependency-free.
3. Do not add filesystem, registry, process, or driver claims that addon Lua cannot verify.
4. Validate changes with the workflows before creating a pull request.
5. Update the TOC version and changelog for releases.
6. Use `AURA:RegisterTheme` or `AURA:RegisterSkinProvider` for UI integrations; WoW 3.3.5 cannot load CSS.
