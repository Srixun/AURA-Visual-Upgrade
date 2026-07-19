local addonName, AURA = ...

if type(AURA) ~= "table" then
    AURA = {}
end

_G.AURAVisualUpgrade = AURA
AURA.addonName = addonName
AURA.pending = {}
AURA.rows = {}
AURA.settingByID = {}
AURA.supportedSettings = {}
AURA.newestPeerVersion = nil
AURA.peerResponseCount = 0
AURA.peerResponders = {}
AURA.peerQueryReplyAt = {}

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

function AURA:IsExternalSetting(setting)
    return setting.type == "external-toggle" or setting.type == "external-choice"
end

function AURA:IsSettingSupported(setting)
    if self:IsExternalSetting(setting) then return true end
    if GetCVarInfo then
        local ok, value = pcall(GetCVarInfo, setting.cvar)
        if ok then return value ~= nil end
    end
    return self:ReadCVar(setting.cvar) ~= nil
end

local function ParseVersion(version)
    local major, minor, patch = string.match(tostring(version or ""), "^(%d+)%.(%d+)%.(%d+)$")
    if not major then return nil end
    return tonumber(major), tonumber(minor), tonumber(patch)
end

function AURA:CompareVersions(left, right)
    local leftMajor, leftMinor, leftPatch = ParseVersion(left)
    local rightMajor, rightMinor, rightPatch = ParseVersion(right)
    if not leftMajor or not rightMajor then return nil end
    if leftMajor ~= rightMajor then return leftMajor > rightMajor and 1 or -1 end
    if leftMinor ~= rightMinor then return leftMinor > rightMinor and 1 or -1 end
    if leftPatch ~= rightPatch then return leftPatch > rightPatch and 1 or -1 end
    return 0
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
    wipe(self.supportedSettings)
    for _, setting in ipairs(self.SETTINGS) do
        if self:IsSettingSupported(setting) then
            table.insert(self.supportedSettings, setting)
            self.settingByID[setting.id] = setting
            if self:IsExternalSetting(setting) then
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
    self.stagedProfile = AURAVisualUpgradeDB.lastProfile
end

function AURA:SetPending(id, value)
    self.pending[id] = value
    self.stagedProfile = "Custom"
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
    if self.UpdateProfileDisplay then
        self:UpdateProfileDisplay("Custom")
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
        if self.settingByID[id] then
            self.pending[id] = value
        end
    end
    if self.pending.frameGeneration then
        self.pending.maxFPS = 80
    end
    self.stagedProfile = profileName
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
    AURAVisualUpgradeRequest.profile = self.stagedProfile or AURAVisualUpgradeDB.lastProfile
    AURAVisualUpgradeRequest.updatedAt = time and time() or 0
    AURAVisualUpgradeRequest.pending = true
end

function AURA:InitializePeerProtocol()
    local register = RegisterAddonMessagePrefix or (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix)
    local send = SendAddonMessage or (C_ChatInfo and C_ChatInfo.SendAddonMessage)
    if not send then
        self.peerProtocolAvailable = false
        self.peerStatus = "Peer checks are unavailable on this client."
        return
    end
    self.peerProtocolAvailable = true
    if register then
        local ok, result = pcall(register, self.MESSAGE_PREFIX)
        self.peerProtocolAvailable = ok and result ~= false and (type(result) ~= "number" or result == 0)
    end
    self.peerStatus = self.peerProtocolAvailable and "No peer version check has run this session." or "The client rejected the AURA message prefix."
end

function AURA:SendPeerMessage(message, channel, target)
    local send = SendAddonMessage or (C_ChatInfo and C_ChatInfo.SendAddonMessage)
    if not send then return false end
    local ok, result = pcall(send, self.MESSAGE_PREFIX, message, channel, target)
    if not ok or result == false then return false end
    if type(result) == "number" then return result == 0 end
    return true
end

function AURA:GetPeerChannels()
    local channels = {}
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        table.insert(channels, "RAID")
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        table.insert(channels, "PARTY")
    elseif IsInGuild and IsInGuild() then
        table.insert(channels, "GUILD")
    end
    return channels
end

function AURA:RecordPeerVersion(version, sender, countResponse)
    if not ParseVersion(version) then return end
    if countResponse and sender and not self.peerResponders[sender] then
        self.peerResponders[sender] = true
        self.peerResponseCount = (self.peerResponseCount or 0) + 1
    end
    if not self.newestPeerVersion or self:CompareVersions(version, self.newestPeerVersion) == 1 then
        self.newestPeerVersion = version
        self.newestPeerSender = sender
    end

    if self.newestPeerVersion and self:CompareVersions(self.newestPeerVersion, self.VERSION) == 1 then
        self.peerStatus = string.format("Peer %s reported AURA v%s. Verify it on the official GitHub Releases page.", tostring(self.newestPeerSender or "Unknown"), self.newestPeerVersion)
    elseif countResponse then
        self.peerStatus = string.format("Received %d peer response%s; no newer version was reported.", self.peerResponseCount, self.peerResponseCount == 1 and "" or "s")
    end
    if self.UpdateUpdateDisplay then self:UpdateUpdateDisplay() end
end

function AURA:CheckPeerVersions()
    if not self.peerProtocolAvailable then
        self.peerStatus = "Peer checks are unavailable on this client."
        if self.UpdateUpdateDisplay then self:UpdateUpdateDisplay() end
        return
    end

    local now = GetTime and GetTime() or 0
    if self.lastPeerQueryAt and now - self.lastPeerQueryAt < 15 then
        self.peerStatus = "Please wait a few seconds before checking peers again."
        if self.UpdateUpdateDisplay then self:UpdateUpdateDisplay() end
        return
    end

    local channels = self:GetPeerChannels()
    if #channels == 0 then
        self.peerStatus = "Join a guild, party, or raid to ask other AURA users for their version."
        if self.UpdateUpdateDisplay then self:UpdateUpdateDisplay() end
        return
    end

    local sent = 0
    for _, channel in ipairs(channels) do
        if self:SendPeerMessage("QUERY|" .. self.VERSION, channel) then
            sent = sent + 1
        end
    end
    self.lastPeerQueryAt = now
    self.peerResponseCount = 0
    wipe(self.peerResponders)
    self.peerStatus = sent > 0 and "Peer query sent. Responses are informational; verify releases on GitHub." or "The peer query could not be sent."
    if self.UpdateUpdateDisplay then self:UpdateUpdateDisplay() end
end

function AURA:AnnouncePeerVersion()
    if not self.peerProtocolAvailable or self.peerAnnouncementSent then return end
    local channels = self:GetPeerChannels()
    if channels[1] and self:SendPeerMessage("VERSION|" .. self.VERSION, channels[1]) then
        self.peerAnnouncementSent = true
    end
end

function AURA:HandlePeerMessage(prefix, message, _, sender)
    if prefix ~= self.MESSAGE_PREFIX or type(message) ~= "string" then return end
    local kind, version = string.match(message, "^(%u+)|(%d+%.%d+%.%d+)$")
    if (kind ~= "QUERY" and kind ~= "VERSION") or not version then return end
    local senderName = sender and string.match(sender, "^[^-]+")
    if senderName and UnitName and senderName == UnitName("player") then return end
    self:RecordPeerVersion(version, sender, kind == "VERSION")
    if kind == "QUERY" and sender and sender ~= "" then
        local now = GetTime and GetTime() or 0
        local lastReply = self.peerQueryReplyAt[sender]
        if not lastReply or now - lastReply >= 15 then
            self.peerQueryReplyAt[sender] = now
            self:SendPeerMessage("VERSION|" .. self.VERSION, "WHISPER", sender)
        end
    end
end

function AURA:ApplySettings()
    if InCombatLockdown and InCombatLockdown() then
        self:UpdateFooter("Leave combat before applying graphics changes.", 1, 0.35, 0.35)
        return
    end

    local needsGxRestart, needsRelog, needsClientRestart, externalChanged = false, false, false, false
    local failed = {}
    for _, setting in ipairs(self.supportedSettings) do
        local value = self.pending[setting.id]
        if self:IsExternalSetting(setting) then
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

    if externalChanged then
        needsClientRestart = true
    end

    if #failed > 0 then
        self:UpdateFooter("Unsupported settings: " .. table.concat(failed, ", "), 1, 0.35, 0.35)
        return
    end

    AURAVisualUpgradeDB.lastProfile = self.stagedProfile or "Custom"
    self:BuildExternalRequest()

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
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("CHAT_MSG_ADDON")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PARTY_MEMBERS_CHANGED")
        self:RegisterEvent("RAID_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_GUILD_UPDATE")
        AURA:InitializeDatabase()
        AURA:LoadPendingValues()
        AURA:InitializePeerProtocol()
        AURA:CreateUI()
        AURA:Print("Loaded. Type |cffffffff/auravis|r or click the AV minimap button.")
    elseif event == "CHAT_MSG_ADDON" then
        AURA:HandlePeerMessage(...)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        if not AURA.peerAnnouncementSent and not AURA.peerAnnouncementScheduled then
            AURA.peerAnnouncementScheduled = true
            AURA.peerAnnouncementDelay = event == "PLAYER_ENTERING_WORLD" and 8 or 2
        end
    end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    AURA:UpdateAnalysis(elapsed)
    if AURA.peerAnnouncementDelay then
        AURA.peerAnnouncementDelay = AURA.peerAnnouncementDelay - elapsed
        if AURA.peerAnnouncementDelay <= 0 then
            AURA.peerAnnouncementDelay = nil
            AURA.peerAnnouncementScheduled = false
            AURA:AnnouncePeerVersion()
        end
    end
    if AURA.UpdateDashboard then
        AURA.dashboardElapsed = (AURA.dashboardElapsed or 0) + elapsed
        if AURA.dashboardElapsed >= 1 then
            AURA.dashboardElapsed = 0
            AURA:UpdateDashboard()
        end
    end
end)

SLASH_AURAVIS1 = "/auravis"
SlashCmdList.AURAVIS = function(message)
    local command = string.lower(string.match(tostring(message or ""), "^%s*(.-)%s*$"))
    if command == "update" then
        if AURA.Show then AURA:Show() end
        if AURA.ShowUpdatePanel then AURA:ShowUpdatePanel() end
        AURA:CheckPeerVersions()
    elseif AURA.Toggle then
        AURA:Toggle()
    end
end
