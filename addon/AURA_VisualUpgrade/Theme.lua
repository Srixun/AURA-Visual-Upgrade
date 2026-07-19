local _, AURA = ...

AURA.themes = AURA.themes or {}
AURA.skinProviders = AURA.skinProviders or {}
AURA.skinProviderOrder = AURA.skinProviderOrder or {}
AURA.skinTargets = AURA.skinTargets or {}

local function CopyTable(source)
    local target = {}
    for key, value in pairs(source or {}) do
        target[key] = type(value) == "table" and CopyTable(value) or value
    end
    return target
end

local function MergeTable(target, source)
    for key, value in pairs(source or {}) do
        if type(value) == "table" and type(target[key]) == "table" then
            MergeTable(target[key], value)
        else
            target[key] = type(value) == "table" and CopyTable(value) or value
        end
    end
    return target
end

local WARCRAFT_THEME = {
    name = "Warcraft",
    font = "Friz Quadrata TT",
    colors = {
        background = { 0.055, 0.045, 0.035, 0.98 },
        panel = { 0.075, 0.065, 0.050, 0.94 },
        panelLight = { 0.14, 0.115, 0.075, 0.96 },
        border = { 0.48, 0.42, 0.31, 1 },
        windowBorder = { 1.00, 1.00, 1.00, 1 },
        rowBorder = { 0.36, 0.31, 0.23, 0.9 },
        cyan = { 1.00, 0.82, 0.00 },
        text = { 1.00, 0.96, 0.84 },
        muted = { 0.72, 0.66, 0.54 },
        gold = { 1.00, 0.82, 0.00 },
        green = { 0.20, 1.00, 0.20 },
        red = { 1.00, 0.22, 0.18 }
    },
    backdrops = {
        window = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 11, top = 11, bottom = 11 }
        },
        panel = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        },
        row = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        }
    },
    textures = {
        header = "Interface\\DialogFrame\\UI-DialogBox-Header",
        divider = "Interface\\DialogFrame\\UI-DialogBox-Divider",
        highlight = "Interface\\Buttons\\UI-Listbox-Highlight2",
        portraitBorder = "Interface\\Minimap\\MiniMap-TrackingBorder"
    },
    layout = {
        windowTitleY = 14,
        sectionTitleY = 7
    }
}

AURA.themes.Warcraft = WARCRAFT_THEME

local function IsColor(value)
    if type(value) ~= "table" then return false end
    for index = 1, 3 do if type(value[index]) ~= "number" then return false end end
    return value[4] == nil or type(value[4]) == "number"
end

local function IsBackdrop(value)
    if type(value) ~= "table" or type(value.bgFile) ~= "string" or type(value.edgeFile) ~= "string"
        or type(value.edgeSize) ~= "number" or type(value.insets) ~= "table" then return false end
    for _, side in ipairs({ "left", "right", "top", "bottom" }) do
        if type(value.insets[side]) ~= "number" then return false end
    end
    return (value.tile == nil or type(value.tile) == "boolean") and (value.tileSize == nil or type(value.tileSize) == "number")
end

function AURA:RegisterTheme(name, definition)
    if type(name) ~= "string" or name == "" or type(definition) ~= "table" then return false end
    local theme = MergeTable(CopyTable(WARCRAFT_THEME), definition)
    if type(theme.colors) ~= "table" or type(theme.backdrops) ~= "table" or type(theme.textures) ~= "table" or type(theme.layout) ~= "table" then return false end
    for _, colorName in ipairs({ "background", "panel", "panelLight", "border", "windowBorder", "rowBorder", "cyan", "text", "muted", "gold", "green", "red" }) do
        if not IsColor(theme.colors[colorName]) then return false end
    end
    if not IsBackdrop(theme.backdrops.window) or not IsBackdrop(theme.backdrops.panel) or not IsBackdrop(theme.backdrops.row) then return false end
    for _, textureName in ipairs({ "header", "divider", "highlight", "portraitBorder" }) do
        if type(theme.textures[textureName]) ~= "string" then return false end
    end
    if type(theme.layout.windowTitleY) ~= "number" or type(theme.layout.sectionTitleY) ~= "number" then return false end
    if type(theme.font) ~= "string" then return false end
    theme.name = name
    self.themes[name] = theme
    return true
end

function AURA:GetTheme()
    if self.activeTheme then return self.activeTheme end
    local name = AURAVisualUpgradeDB and AURAVisualUpgradeDB.theme or "Warcraft"
    return self.themes[name] or WARCRAFT_THEME
end

function AURA:SetTheme(name)
    if not self.themes[name] then return false end
    if type(AURAVisualUpgradeDB) ~= "table" then AURAVisualUpgradeDB = {} end
    AURAVisualUpgradeDB.theme = name
    if self.frame then self:Print("Theme changed to " .. name .. ". Reload the UI to apply it.") end
    return true
end

function AURA:ResolveMedia(kind, name, fallback)
    if type(LibStub) == "table" or type(LibStub) == "function" then
        local ok, media = pcall(LibStub, "LibSharedMedia-3.0", true)
        if ok and media and name then
            local resolved = media:Fetch(kind, name, true)
            if resolved then return resolved end
        end
    end
    return fallback
end

function AURA:ApplyBackdrop(frame, style)
    local theme = self:GetTheme()
    local backdrop = theme.backdrops[style or "panel"] or theme.backdrops.panel
    frame:SetBackdrop(backdrop)
    if style == "window" then
        if not frame.auraOpaqueBackground then
            local background = frame:CreateTexture(nil, "BACKGROUND")
            background:SetTexture("Interface\\Buttons\\WHITE8X8")
            background:SetPoint("TOPLEFT", backdrop.insets.left, -backdrop.insets.top)
            background:SetPoint("BOTTOMRIGHT", -backdrop.insets.right, backdrop.insets.bottom)
            background:SetVertexColor(theme.colors.background[1], theme.colors.background[2], theme.colors.background[3], 0.96)
            frame.auraOpaqueBackground = background
        end
        frame:SetBackdropColor(unpack(theme.colors.background))
        frame:SetBackdropBorderColor(unpack(theme.colors.windowBorder or theme.colors.border))
    elseif style == "row" then
        frame:SetBackdropColor(unpack(theme.colors.panel))
        frame:SetBackdropBorderColor(unpack(theme.colors.rowBorder or theme.colors.border))
    else
        frame:SetBackdropColor(unpack(theme.colors.panel))
        frame:SetBackdropBorderColor(unpack(theme.colors.border))
    end
end

function AURA:RegisterSkinProvider(name, callback)
    if type(name) ~= "string" or name == "" or type(callback) ~= "function" then return false end
    local previous = self.skinProviders[name]
    local added = not previous
    if added then table.insert(self.skinProviderOrder, name) end
    self.skinProviders[name] = callback
    for _, target in ipairs(self.skinTargets) do
        local ok, message = pcall(callback, target.frame, target.kind, self:GetTheme())
        if not ok then
            self.skinProviders[name] = previous
            if added then
                for index, providerName in ipairs(self.skinProviderOrder) do
                    if providerName == name then table.remove(self.skinProviderOrder, index) break end
                end
            end
            self:Print("Skin provider '" .. name .. "' failed: " .. tostring(message))
            return false
        end
    end
    return true
end

function AURA:ApplySkinProviders(frame, kind)
    table.insert(self.skinTargets, { frame = frame, kind = kind })
    for _, name in ipairs(self.skinProviderOrder) do
        local ok, message = pcall(self.skinProviders[name], frame, kind, self:GetTheme())
        if not ok then self:Print("Skin provider '" .. name .. "' failed: " .. tostring(message)) end
    end
end
