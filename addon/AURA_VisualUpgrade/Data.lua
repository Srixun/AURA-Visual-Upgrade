local _, AURA = ...

AURA.VERSION = "0.3.0"
AURA.MESSAGE_PREFIX = "AURAVIS"
AURA.RELEASES_URL = "https://github.com/Srixun/AURA-Visual-Upgrade/releases/latest"
AURA.SETTINGS = {
    {
        id = "projectedTextures", category = "WORLD DETAIL", type = "toggle", cvar = "projectedTextures",
        label = "Projected Textures", impact = "Low", apply = "Immediate",
        description = "Shows spell circles, ground effects, and projected world textures. Recommended for encounter clarity."
    },
    {
        id = "specular", category = "WORLD DETAIL", type = "toggle", cvar = "specular",
        label = "Specular Lighting", impact = "Low", apply = "Relog",
        description = "Adds reflective highlights to armor, water, and world materials. Requires a logout and relog."
    },
    {
        id = "ffxGlow", category = "WORLD DETAIL", type = "toggle", cvar = "ffxGlow",
        label = "Full-Screen Glow", impact = "Low", apply = "Immediate",
        description = "Enables the game's bloom and glow pass. ReShade bloom remains independently configurable."
    },
    {
        id = "particleDensity", category = "WORLD DETAIL", type = "choice", cvar = "particleDensity",
        label = "Particle Density", impact = "Medium", apply = "Immediate",
        description = "Controls spell, weather, and ambient particle density.",
        choices = {
            { label = "Low", value = "0.2" }, { label = "Balanced", value = "0.5" }, { label = "High", value = "1" }
        }
    },
    {
        id = "particleDensityRaid", category = "WORLD DETAIL", type = "choice", cvar = "particleDensity_raid",
        label = "Raid Particle Density", impact = "High", apply = "Immediate",
        description = "Limits raid-specific spell particles while preserving the general particle setting. Shown only on supported Ascension clients.",
        choices = {
            { label = "Low", value = "0.2" }, { label = "Balanced", value = "0.4" }, { label = "High", value = "1" }
        }
    },
    {
        id = "weatherDensity", category = "WORLD DETAIL", type = "choice", cvar = "weatherDensity",
        label = "Weather Density", impact = "Low", apply = "Immediate",
        description = "Controls rain, snow, and sandstorm density.",
        choices = {
            { label = "Off", value = "0" }, { label = "Low", value = "1" }, { label = "High", value = "3" }
        }
    },
    {
        id = "farclip", category = "WORLD DETAIL", type = "slider", cvar = "farclip",
        label = "View Distance", impact = "High", apply = "Immediate",
        description = "Sets how far terrain and distant objects remain visible.", min = 400, max = 1400, step = 50
    },
    {
        id = "environmentDetail", category = "WORLD DETAIL", type = "slider", cvar = "environmentDetail",
        label = "Environment Detail", impact = "Medium", apply = "Immediate",
        description = "Controls distant world-object detail and draw complexity.", min = 0.5, max = 2, step = 0.25
    },
    {
        id = "groundEffectDensity", category = "WORLD DETAIL", type = "slider", cvar = "groundEffectDensity",
        label = "Ground Clutter Density", impact = "High", apply = "Immediate",
        description = "Controls the amount of grass and small decorative ground objects.", min = 16, max = 128, step = 8
    },
    {
        id = "groundEffectDist", category = "WORLD DETAIL", type = "slider", cvar = "groundEffectDist",
        label = "Ground Clutter Distance", impact = "Medium", apply = "Immediate",
        description = "Sets how far grass and decorative ground objects are drawn.", min = 40, max = 200, step = 10
    },
    {
        id = "shadowLevel", category = "WORLD DETAIL", type = "choice", cvar = "shadowLevel",
        label = "Shadow Level", impact = "High", apply = "Immediate",
        description = "Controls Ascension's dynamic shadow quality. High can be expensive in crowded areas.",
        choices = {
            { label = "Off", value = "0" }, { label = "Low", value = "1" }, { label = "High", value = "2" }
        }
    },
    {
        id = "extShadowQuality", category = "WORLD DETAIL", type = "slider", cvar = "extShadowQuality",
        label = "Extended Shadow Quality", impact = "High", apply = "Immediate",
        description = "Controls Ascension's extended shadow detail from disabled to maximum. Shown only on supported clients.",
        min = 0, max = 5, step = 1
    },
    {
        id = "textureFilteringMode", category = "DISPLAY", type = "choice", cvar = "textureFilteringMode",
        label = "Texture Filtering", impact = "Low", apply = "Client restart",
        description = "Improves texture clarity at oblique angles. Modern GPUs should use the highest setting.",
        choices = {
            { label = "4x", value = "3" }, { label = "8x", value = "4" }, { label = "Highest", value = "5" }
        }
    },
    {
        id = "componentTextureLevel", category = "DISPLAY", type = "slider", cvar = "componentTextureLevel",
        label = "Model Texture Detail", impact = "Medium", apply = "Client restart",
        description = "Controls Ascension's model and component texture detail from minimum to maximum. Shown only on supported clients.",
        min = 0, max = 9, step = 1
    },
    {
        id = "baseMip", category = "DISPLAY", type = "choice", cvar = "baseMip",
        label = "World Texture Resolution", impact = "Medium", apply = "Client restart",
        description = "Selects world texture resolution. Lower-detail modes save video memory on constrained systems.",
        choices = {
            { label = "High", value = "0" }, { label = "Medium", value = "1" }, { label = "Low", value = "2" }
        }
    },
    {
        id = "ffxDeath", category = "DISPLAY", type = "toggle", cvar = "ffxDeath",
        label = "Death Screen Effect", impact = "Low", apply = "Immediate",
        description = "Enables the full-screen visual effect used while your character is dead."
    },
    {
        id = "gxVSync", category = "DISPLAY", type = "toggle", cvar = "gxVSync",
        label = "Vertical Sync", impact = "Low", apply = "Graphics restart",
        description = "Synchronizes output to the display. Leave off when using VRR unless tearing is visible."
    },
    {
        id = "gxTripleBuffer", category = "DISPLAY", type = "toggle", cvar = "gxTripleBuffer",
        label = "Triple Buffering", impact = "Low", apply = "Graphics restart",
        description = "Improves VSync frame pacing at a small VRAM and latency cost."
    },
    {
        id = "gxCursor", category = "DISPLAY", type = "toggle", cvar = "gxCursor",
        label = "Hardware Cursor", impact = "Low", apply = "Graphics restart",
        description = "Uses the GPU cursor path when available. Disable only when diagnosing cursor rendering problems."
    },
    {
        id = "gxMultisample", category = "DISPLAY", type = "choice", cvar = "gxMultisample",
        label = "Multisample Antialiasing", impact = "High", apply = "Graphics restart",
        description = "Smooths geometry edges. Use 1x when ReShade depth effects are enabled or depth access may fail.",
        choices = {
            { label = "1x / ReShade", value = "1" }, { label = "2x", value = "2" }, { label = "4x", value = "4" }, { label = "8x", value = "8" }
        }
    },
    {
        id = "maxFPS", category = "DISPLAY", type = "slider", cvar = "maxFPS",
        label = "Real Frame Cap", impact = "Low", apply = "Immediate",
        description = "Caps real rendered frames. The Smooth Motion displayed-FPS target updates as this slider moves.", min = 30, max = 240, step = 1
    },
    {
        id = "maxFPSBk", category = "DISPLAY", type = "slider", cvar = "maxFPSBk",
        label = "Background Frame Cap", impact = "Low", apply = "Immediate",
        description = "Limits rendering while Ascension is in the background to reduce power use and heat.", min = 5, max = 120, step = 5
    },
    {
        id = "gxFixLag", category = "TROUBLESHOOTING", type = "toggle", cvar = "gxFixLag",
        label = "Reduce Input Lag", impact = "Low", apply = "Graphics restart",
        description = "Troubleshooting option that changes frame synchronization. It is never changed by an AURA profile."
    },
    {
        id = "renderer", category = "AURA EXTERNAL UPGRADE", type = "external-choice",
        label = "Renderer Backend", impact = "Low", apply = "External sync + client restart",
        description = "Requests the dgVoodoo translation backend. Addon Lua cannot modify renderer DLLs itself.",
        choices = {
            { label = "DirectX 11", value = "DX11" }, { label = "DirectX 12", value = "DX12" }
        }
    },
    {
        id = "reshade", category = "AURA EXTERNAL UPGRADE", type = "external-choice",
        label = "ReShade Profile", impact = "Medium", apply = "External sync + client restart",
        description = "Requests Off, Balanced, or Cinematic post-processing. Requires the AURA companion installer.",
        choices = {
            { label = "Off", value = "Off" }, { label = "Balanced", value = "Balanced" }, { label = "Cinematic", value = "Cinematic" }
        }
    },
    {
        id = "reshadeMXAO", category = "AURA EXTERNAL UPGRADE", type = "external-toggle",
        label = "Ambient Occlusion (MXAO)", impact = "Medium", apply = "External sync + client restart",
        description = "Adds depth-aware contact shadows and object grounding through ReShade."
    },
    {
        id = "reshadeBounce", category = "AURA EXTERNAL UPGRADE", type = "external-toggle",
        label = "Bounce Lighting", impact = "Medium", apply = "External sync + client restart",
        description = "Adds restrained screen-space color bounce and broad indirect-light approximation."
    },
    {
        id = "reshadeBloom", category = "AURA EXTERNAL UPGRADE", type = "external-toggle",
        label = "Bloom", impact = "Low", apply = "External sync + client restart",
        description = "Adds controlled highlights around bright effects using iMMERSE Solaris."
    },
    {
        id = "reshadeColor", category = "AURA EXTERNAL UPGRADE", type = "external-toggle",
        label = "Color Grading", impact = "Low", apply = "External sync + client restart",
        description = "Adds subtle contrast, vibrance, highlight, and shadow shaping."
    },
    {
        id = "reshadeSharpen", category = "AURA EXTERNAL UPGRADE", type = "external-toggle",
        label = "Image Sharpening", impact = "Low", apply = "External sync + client restart",
        description = "Restores fine detail after scaling and post-processing without aggressive halos."
    },
    {
        id = "frameGeneration", category = "AURA EXTERNAL UPGRADE", type = "external-toggle",
        label = "NVIDIA Smooth Motion Confirmed", impact = "Low", apply = "Manual NVIDIA setting",
        description = "Self-reported status only. Enable Smooth Motion for Ascension.exe in NVIDIA App; addons cannot control NVAPI."
    },
    {
        id = "staffApproval", category = "AURA EXTERNAL UPGRADE", type = "external-toggle",
        label = "Unrestricted ReShade Approved", impact = "Low", apply = "Safety confirmation",
        description = "Confirms you have server approval before requesting multiplayer depth access. This does not grant permission."
    }
}

AURA.PROFILES = {
    Performance = {
        projectedTextures = true, specular = true, ffxGlow = true, ffxDeath = true, particleDensity = "0.2", particleDensityRaid = "0.2", weatherDensity = "1",
        farclip = 700, environmentDetail = 1.25, groundEffectDensity = 48, groundEffectDist = 100, shadowLevel = "0", extShadowQuality = 0,
        textureFilteringMode = "5", componentTextureLevel = 9, baseMip = "0", gxVSync = false, gxTripleBuffer = true, gxCursor = true,
        gxMultisample = "2", maxFPS = 162, maxFPSBk = 30,
        renderer = "DX12", reshade = "Off", reshadeMXAO = false, reshadeBounce = false, reshadeBloom = false,
        reshadeColor = false, reshadeSharpen = false
    },
    Raid = {
        projectedTextures = true, specular = true, ffxGlow = true, ffxDeath = false, particleDensity = "0.5", particleDensityRaid = "0.4", weatherDensity = "1",
        farclip = 700, environmentDetail = 1.25, groundEffectDensity = 32, groundEffectDist = 80, shadowLevel = "0", extShadowQuality = 0,
        textureFilteringMode = "5", componentTextureLevel = 9, baseMip = "0", gxVSync = false, gxTripleBuffer = true, gxCursor = true,
        gxMultisample = "1", maxFPS = 162, maxFPSBk = 30,
        renderer = "DX12", reshade = "Off", reshadeMXAO = false, reshadeBounce = false, reshadeBloom = false,
        reshadeColor = false, reshadeSharpen = true
    },
    Balanced = {
        projectedTextures = true, specular = true, ffxGlow = true, ffxDeath = true, particleDensity = "0.5", particleDensityRaid = "0.4", weatherDensity = "3",
        farclip = 837, environmentDetail = 1.5, groundEffectDensity = 64, groundEffectDist = 140, shadowLevel = "0", extShadowQuality = 2,
        textureFilteringMode = "5", componentTextureLevel = 9, baseMip = "0", gxVSync = false, gxTripleBuffer = true, gxCursor = true,
        gxMultisample = "1", maxFPS = 162, maxFPSBk = 30,
        renderer = "DX12", reshade = "Balanced", reshadeMXAO = true, reshadeBounce = true, reshadeBloom = true,
        reshadeColor = true, reshadeSharpen = true
    },
    Quality = {
        projectedTextures = true, specular = true, ffxGlow = true, ffxDeath = true, particleDensity = "1", particleDensityRaid = "1", weatherDensity = "3",
        farclip = 1100, environmentDetail = 2, groundEffectDensity = 96, groundEffectDist = 180, shadowLevel = "2", extShadowQuality = 5,
        textureFilteringMode = "5", componentTextureLevel = 9, baseMip = "0", gxVSync = false, gxTripleBuffer = true, gxCursor = true,
        gxMultisample = "1", maxFPS = 162, maxFPSBk = 30,
        renderer = "DX12", reshade = "Cinematic", reshadeMXAO = true, reshadeBounce = true, reshadeBloom = true,
        reshadeColor = true, reshadeSharpen = true
    }
}
