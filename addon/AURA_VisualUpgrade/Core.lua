local addonName, AURA = ...

if type(AURA) ~= "table" then
    AURA = {}
end

_G.AURAVisualUpgrade = AURA
AURA.addonName = addonName
AURA.pending = {}
AURA.rows = {}
AURA.settingByID = {}

local function CopyTable(source)
    local target = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            target[key] = CopyTable(value)
        else
            target[key] = value
        end
    end
    return target
end

function AURA:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff55d6ffAURA Visual Upgrade:|r " .. tostring(message))
end

function AURA:ReadCVar(name)
    local ok, value = pcall(GetCVar, name)
    if not ok then
        return nil
    end
    return value
end

function AURA:WriteCVar(name, value)
    if self:ReadCVar(name) == nil then
        return false
    end
    local ok = pcall(SetCVar, name, tostring(value))
    return ok
end

function AURA:InitializeDatabase()
    if type(AURAVisualUpgradeDB) ~= "table" then
        AURAVisualUpgradeDB = {}
    end
    if type(AURAVisualUpgradeDB.external) ~= "table" then
        AURAVisualUpgradeDB.external = {}
    end
    if type(AURAVisualUpgradeDB.minimapAngle) ~= "number" then
        AURAVisualUpgradeDB.minimapAngle = 220
    end
    if type(AURAVisualUpgradeDB.lastProfile) ~= "string" then
        AURAVisualUpgradeDB.lastProfile = "Custom"
    end
    if type(AURAVisualUpgradeRequest) ~= "table" then
        AURAVisualUpgradeRequest = { serial = 0 }
    end

    local defaults = {
        renderer = "DX12", reshade = "Balanced", reshadeMXAO = true, reshadeBounce = true,
        reshadeBloom = true, reshadeColor = true, reshadeSharpen = true,
        frameGeneration = false, staffApproval = false
    }
    for key, value in pairs(defaults) do
        if AURAVisualUpgradeDB.external[key] == nil then
            AURAVisualUpgradeDB.external[key] = value
        end
    end
end

function AURA:LoadPendingValues()
    wipe(self.pending)
    wipe(self.settingByID)
    for _, setting in ipairs(self.SETTINGS) do
        self.settingByID[setting.id] = setting
        if setting.type == "external-toggle" or setting.type == "external-choice" then
            self.pending[setting.id] = AURAVisualUpgradeDB.external[setting.id]
        else
            local current = self:ReadCVar(setting.cvar)
            if setting.type == "toggle" then
                self.pending[setting.id] = current == "1"
            elseif setting.type == "slider" then
                self.pending[setting.id] = tonumber(current) or setting.min
            else
                self.pending[setting.id] = current or setting.choices[1].value
            end
        end
    end
end

function AURA:SetPending(id, value)
    self.pending[id] = value
    AURAVisualUpgradeDB.lastProfile = "Custom"
    if id == "frameGeneration" and value then
        self.pending.maxFPS = 80
    end
    if id == "reshade" then
        local enabled = value ~= "Off"
        self.pending.reshadeMXAO = enabled
        self.pending.reshadeBounce = enabled
        self.pending.reshadeBloom = enabled
        self.pending.reshadeColor = enabled
        self.pending.reshadeSharpen = enabled
    end
    if self.RefreshAllRows then
        self:RefreshAllRows()
    end
    if self.UpdateDashboard then
        self:UpdateDashboard()
    end
    if self.UpdateFooter then
        self:UpdateFooter("Changes staged. Press Apply when ready.", 0.95, 0.78, 0.32)
    end
end

function AURA:StageProfile(profileName)
    local profile = self.PROFILES[profileName]
    if not profile then
        return
    end
    for id, value in pairs(profile) do
        self.pending[id] = value
    end
    if self.pending.frameGeneration then
        self.pending.maxFPS = 80
    end
    AURAVisualUpgradeDB.lastProfile = profileName
    if self.RefreshAllRows then
        self:RefreshAllRows()
    end
    if self.UpdateProfileDisplay then
        self:UpdateProfileDisplay(profileName)
    end
    self:UpdateFooter(profileName .. " profile staged. Press Apply to commit it.", 0.35, 0.85, 1)
end

function AURA:GetResolution()
    local resolution = self:ReadCVar("gxResolution")
    if not resolution or resolution == "" then
        local index = GetCurrentResolution and GetCurrentResolution()
        if index and GetScreenResolutions then
            resolution = ({ GetScreenResolutions() })[index]
        end
    end
    return resolution or "Unknown"
end

function AURA:StartAnalysis()
    if self.analysis then
        return
    end
    self.analysis = { started = GetTime(), total = 0, count = 0, elapsed = 0 }
    self:UpdateFooter("Analyzing live frame rate for 5 seconds...", 0.35, 0.85, 1)
end

function AURA:UpdateAnalysis(elapsed)
    if not self.analysis then
        return
    end
    local analysis = self.analysis
    analysis.elapsed = analysis.elapsed + elapsed
    if analysis.elapsed >= 0.25 then
        analysis.elapsed = 0
        analysis.total = analysis.total + (GetFramerate and GetFramerate() or 0)
        analysis.count = analysis.count + 1
    end
    if GetTime() - analysis.started < 5 then
        return
    end

    local fps = analysis.count > 0 and analysis.total / analysis.count or 0
    local width, height = string.match(self:GetResolution(), "(%d+)%D+(%d+)")
    local pixels = (tonumber(width) or 1920) * (tonumber(height) or 1080)
    local profile
    if pixels >= 10000000 then
        profile = fps >= 100 and "Quality" or (fps >= 55 and "Balanced" or "Performance")
    elseif pixels >= 7000000 then
        profile = fps >= 90 and "Quality" or (fps >= 50 and "Balanced" or "Performance")
    else
        profile = fps >= 75 and "Quality" or (fps >= 45 and "Balanced" or "Performance")
    end

    self.analysis = nil
    self:StageProfile(profile)
    self:UpdateFooter(string.format("Recommended: %s (%.0f FPS at %s). This is an estimate, not GPU detection.", profile, fps, self:GetResolution()), 0.4, 1, 0.55)
end

function AURA:BuildExternalRequest()
    AURAVisualUpgradeRequest.serial = (tonumber(AURAVisualUpgradeRequest.serial) or 0) + 1
    AURAVisualUpgradeRequest.version = self.VERSION
    AURAVisualUpgradeRequest.renderer = tostring(self.pending.renderer or "DX12")
    AURAVisualUpgradeRequest.reshade = tostring(self.pending.reshade or "Off")
    AURAVisualUpgradeRequest.reshadeMXAO = self.pending.reshadeMXAO and true or false
    AURAVisualUpgradeRequest.reshadeBounce = self.pending.reshadeBounce and true or false
    AURAVisualUpgradeRequest.reshadeBloom = self.pending.reshadeBloom and true or false
    AURAVisualUpgradeRequest.reshadeColor = self.pending.reshadeColor and true or false
    AURAVisualUpgradeRequest.reshadeSharpen = self.pending.reshadeSharpen and true or false
    AURAVisualUpgradeRequest.frameGeneration = self.pending.frameGeneration and true or false
    AURAVisualUpgradeRequest.staffApproval = self.pending.staffApproval and true or false
    AURAVisualUpgradeRequest.baseFrameCap = tonumber(self.pending.maxFPS) or 80
    AURAVisualUpgradeRequest.profile = AURAVisualUpgradeDB.lastProfile
    AURAVisualUpgradeRequest.updatedAt = time and time() or 0
    AURAVisualUpgradeRequest.pending = true
end

function AURA:ApplySettings()
    if InCombatLockdown and InCombatLockdown() then
        self:UpdateFooter("Leave combat before applying graphics changes.", 1, 0.35, 0.35)
        return
    end

    local needsGxRestart, needsRelog, needsClientRestart, externalChanged = false, false, false, false
    local failed = {}
    for _, setting in ipairs(self.SETTINGS) do
        local value = self.pending[setting.id]
        if setting.type == "external-toggle" or setting.type == "external-choice" then
            if AURAVisualUpgradeDB.external[setting.id] ~= value then
                externalChanged = true
            end
            AURAVisualUpgradeDB.external[setting.id] = value
        else
            local writeValue = setting.type == "toggle" and (value and "1" or "0") or value
            local current = self:ReadCVar(setting.cvar)
            local changed
            if setting.type == "slider" then
                changed = math.abs((tonumber(current) or 0) - (tonumber(writeValue) or 0)) > (setting.step / 2)
            else
                changed = tostring(current) ~= tostring(writeValue)
            end
            if changed then
                if not self:WriteCVar(setting.cvar, writeValue) then
                    table.insert(failed, setting.label)
                elseif setting.apply == "Graphics restart" then
                    needsGxRestart = true
                elseif setting.apply == "Relog" then
                    needsRelog = true
                elseif setting.apply == "Client restart" then
                    needsClientRestart = true
                end
            end
        end
    end

    self:BuildExternalRequest()
    if externalChanged then
        needsClientRestart = true
    end

    if #failed > 0 then
        self:UpdateFooter("Unsupported settings: " .. table.concat(failed, ", "), 1, 0.35, 0.35)
        return
    end

    local notices = {}
    if needsRelog then table.insert(notices, "relog") end
    if needsClientRestart then table.insert(notices, "client restart/external sync") end
    local suffix = #notices > 0 and (" Remaining: " .. table.concat(notices, ", ") .. ".") or ""
    self:UpdateFooter("Game settings applied." .. suffix, 0.4, 1, 0.55)

    if needsGxRestart and RestartGx then
        StaticPopup_Show("AURA_VISUAL_RESTART_GX")
    end
end

function AURA:ResetStaged()
    self:LoadPendingValues()
    if self.RefreshAllRows then self:RefreshAllRows() end
    if self.UpdateProfileDisplay then self:UpdateProfileDisplay(AURAVisualUpgradeDB.lastProfile) end
    self:UpdateFooter("Staged changes discarded.", 0.75, 0.8, 0.88)
end

StaticPopupDialogs["AURA_VISUAL_RESTART_GX"] = {
    text = "Some AURA Visual Upgrade settings require a graphics restart. Restart the graphics system now? The screen may flash briefly.",
    button1 = "Restart Graphics",
    button2 = "Later",
    OnAccept = function() RestartGx() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3
}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    AURA:InitializeDatabase()
    AURA:LoadPendingValues()
    AURA:CreateUI()
    AURA:Print("Loaded. Type |cffffffff/auravis|r or click the AV minimap button.")
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    AURA:UpdateAnalysis(elapsed)
    if AURA.UpdateDashboard then
        AURA.dashboardElapsed = (AURA.dashboardElapsed or 0) + elapsed
        if AURA.dashboardElapsed >= 1 then
            AURA.dashboardElapsed = 0
            AURA:UpdateDashboard()
        end
    end
end)

SLASH_AURAVIS1 = "/auravis"
SlashCmdList.AURAVIS = function()
    if AURA.Toggle then AURA:Toggle() end
end
