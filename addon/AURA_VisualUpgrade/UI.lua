local _, AURA = ...

local COLORS = {
    background = { 0.025, 0.045, 0.075, 0.97 },
    panel = { 0.045, 0.075, 0.115, 0.96 },
    panelLight = { 0.065, 0.105, 0.155, 0.96 },
    border = { 0.13, 0.42, 0.60, 0.9 },
    cyan = { 0.33, 0.84, 1.00 },
    text = { 0.90, 0.95, 1.00 },
    muted = { 0.55, 0.65, 0.75 },
    gold = { 0.95, 0.78, 0.32 },
    green = { 0.40, 1.00, 0.55 },
    red = { 1.00, 0.35, 0.35 }
}

local IMPACT_COLORS = {
    Low = "|cff66ff8c",
    Medium = "|cffffca52",
    High = "|cffff6262"
}

local function SetBackdrop(frame, background, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(unpack(background or COLORS.panel))
    frame:SetBackdropBorderColor(unpack(border or COLORS.border))
end

local function CreateLabel(parent, text, size, color, justify)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetFont(STANDARD_TEXT_FONT, size or 12, "")
    label:SetText(text or "")
    label:SetTextColor(unpack(color or COLORS.text))
    label:SetJustifyH(justify or "LEFT")
    label:SetJustifyV("MIDDLE")
    return label
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 110, height or 28)
    SetBackdrop(button, COLORS.panelLight, COLORS.border)
    button.label = CreateLabel(button, text, 11, COLORS.text, "CENTER")
    button.label:SetAllPoints()
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.08, 0.22, 0.31, 1)
        self:SetBackdropBorderColor(unpack(COLORS.cyan))
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.panelLight))
        self:SetBackdropBorderColor(unpack(COLORS.border))
    end)
    return button
end

local function GetChoiceIndex(setting, value)
    for index, choice in ipairs(setting.choices) do
        if tostring(choice.value) == tostring(value) then
            return index
        end
        local choiceNumber, valueNumber = tonumber(choice.value), tonumber(value)
        if choiceNumber and valueNumber and math.abs(choiceNumber - valueNumber) < 0.001 then
            return index
        end
    end
    return 1
end

local function GetChoiceLabel(setting, value)
    return setting.choices[GetChoiceIndex(setting, value)].label
end

local function ShowSettingTooltip(owner, setting)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(setting.label, 0.33, 0.84, 1)
    GameTooltip:AddLine(setting.description, 0.9, 0.95, 1, true)
    GameTooltip:AddLine(" ")
    local impact = setting.impact == "Low" and COLORS.green or (setting.impact == "Medium" and COLORS.gold or COLORS.red)
    GameTooltip:AddDoubleLine("Performance hit", setting.impact, 0.7, 0.8, 0.9, unpack(impact))
    GameTooltip:AddDoubleLine("Apply method", setting.apply, 0.7, 0.8, 0.9, 0.95, 0.78, 0.32)
    GameTooltip:Show()
end

function AURA:RefreshRow(setting)
    local row = self.rows[setting.id]
    if not row then return end
    local value = self.pending[setting.id]

    if setting.type == "toggle" or setting.type == "external-toggle" then
        row.control.label:SetText(value and "ENABLED" or "DISABLED")
        if value then
            row.control:SetBackdropColor(0.05, 0.30, 0.25, 1)
            row.control:SetBackdropBorderColor(unpack(COLORS.green))
            row.control.label:SetTextColor(unpack(COLORS.green))
        else
            row.control:SetBackdropColor(unpack(COLORS.panelLight))
            row.control:SetBackdropBorderColor(unpack(COLORS.border))
            row.control.label:SetTextColor(unpack(COLORS.muted))
        end
    elseif setting.type == "choice" or setting.type == "external-choice" then
        row.control.label:SetText(GetChoiceLabel(setting, value) .. "  >")
    elseif setting.type == "slider" then
        row.control.updating = true
        row.control:SetValue(tonumber(value) or setting.min)
        row.control.updating = false
        local numeric = tonumber(value) or 0
        if setting.id == "maxFPS" then
            row.valueLabel:SetText(string.format("%d real  /  ~%d displayed", numeric, numeric * 2))
            row.description:SetText(string.format("Smooth Motion target: %d real FPS becomes approximately %d displayed FPS.", numeric, numeric * 2))
        else
            row.valueLabel:SetText(setting.step < 1 and string.format("%.2f", numeric) or string.format("%d", numeric))
        end
    end
end

function AURA:RefreshAllRows()
    for _, setting in ipairs(self.supportedSettings) do
        self:RefreshRow(setting)
    end
end

function AURA:UpdateFooter(message, red, green, blue)
    if not self.footerStatus then return end
    self.footerStatus:SetText(message or "Ready.")
    if red then
        self.footerStatus:SetTextColor(red, green, blue)
    else
        self.footerStatus:SetTextColor(unpack(COLORS.muted))
    end
end

function AURA:UpdateProfileDisplay(profileName)
    if not self.profileDisplay then return end
    self.profileDisplay:SetText("STAGED PROFILE  |cff55d6ff" .. tostring(profileName or "Custom") .. "|r")
end

function AURA:UpdateDashboard()
    if not self.dashboardResolution then return end
    self.dashboardResolution:SetText(self:GetResolution())
    self.dashboardFPS:SetText(string.format("%.0f FPS", GetFramerate and GetFramerate() or 0))
    local external = AURAVisualUpgradeDB and AURAVisualUpgradeDB.external or {}
    local renderer = external.renderer or "DX12"
    local reshade = external.reshade or "Off"
    self.dashboardRequest:SetText(renderer .. " / " .. reshade)
    local frameGeneration = self.pending.frameGeneration
    local baseCap = tonumber(self.pending.maxFPS) or tonumber(self:ReadCVar("maxFPS")) or 80
    self.dashboardFrameGen:SetText(string.format("%s / ~%d target", frameGeneration and "Confirmed" or "Manual", baseCap * 2))
    self.dashboardFrameGen:SetTextColor(unpack(frameGeneration and COLORS.green or COLORS.gold))
end

function AURA:UpdateUpdateDisplay()
    local newer = self.newestPeerVersion and self:CompareVersions(self.newestPeerVersion, self.VERSION) == 1
    if self.updateButton then
        self.updateButton.label:SetText(newer and "UPDATE FOUND" or "UPDATES")
        self.updateButton.label:SetTextColor(unpack(newer and COLORS.gold or COLORS.text))
    end
    if self.minimapUpdateBadge then
        if newer then self.minimapUpdateBadge:Show() else self.minimapUpdateBadge:Hide() end
    end
    if self.updateStatus then
        self.updateStatus:SetText(self.peerStatus or "No peer version check has run this session.")
        self.updateStatus:SetTextColor(unpack(newer and COLORS.gold or COLORS.muted))
    end
    if self.updateVersion then
        self.updateVersion:SetText(newer and ("LOCAL v" .. self.VERSION .. "  |  PEER-REPORTED v" .. self.newestPeerVersion) or ("LOCAL v" .. self.VERSION))
    end
end

function AURA:CreateUpdatePanel(parent)
    local panel = CreateFrame("Frame", "AURAVisualUpgradeUpdateFrame", parent)
    panel:SetSize(540, 230)
    panel:SetPoint("CENTER")
    panel:SetFrameLevel(parent:GetFrameLevel() + 20)
    panel:EnableMouse(true)
    SetBackdrop(panel, COLORS.background, COLORS.gold)
    panel:Hide()

    local title = CreateLabel(panel, "AURA UPDATE AWARENESS", 17, COLORS.cyan)
    title:SetPoint("TOPLEFT", 20, -18)
    local close = CreateButton(panel, "X", 28, 28)
    close:SetPoint("TOPRIGHT", -14, -13)
    close:SetScript("OnClick", function() panel:Hide() end)

    self.updateVersion = CreateLabel(panel, "LOCAL v" .. self.VERSION, 10, COLORS.text)
    self.updateVersion:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    self.updateStatus = CreateLabel(panel, "No peer version check has run this session.", 11, COLORS.muted)
    self.updateStatus:SetPoint("TOPLEFT", self.updateVersion, "BOTTOMLEFT", 0, -10)
    self.updateStatus:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    self.updateStatus:SetHeight(38)
    self.updateStatus:SetJustifyV("TOP")

    local official = CreateLabel(panel, "OFFICIAL RELEASES - select the link and press Ctrl+C", 9, COLORS.gold)
    official:SetPoint("TOPLEFT", self.updateStatus, "BOTTOMLEFT", 0, -8)
    local link = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    link:SetPoint("TOPLEFT", official, "BOTTOMLEFT", 4, -7)
    link:SetSize(490, 28)
    link:SetAutoFocus(false)
    link:SetFontObject(ChatFontNormal)
    link:SetText(self.RELEASES_URL)
    link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    link:SetScript("OnMouseUp", function(self) self:SetFocus() self:HighlightText() end)

    local check = CreateButton(panel, "CHECK PEERS", 150, 28)
    check:SetPoint("BOTTOMLEFT", 20, 17)
    check:SetScript("OnClick", function() AURA:CheckPeerVersions() end)
    local selectLink = CreateButton(panel, "SELECT RELEASE LINK", 180, 28)
    selectLink:SetPoint("LEFT", check, "RIGHT", 8, 0)
    selectLink:SetScript("OnClick", function() link:SetFocus() link:HighlightText() end)
    local done = CreateButton(panel, "CLOSE", 130, 28)
    done:SetPoint("LEFT", selectLink, "RIGHT", 8, 0)
    done:SetScript("OnClick", function() panel:Hide() end)

    self.updatePanel = panel
    self.updateLink = link
    self:UpdateUpdateDisplay()
end

function AURA:ShowUpdatePanel()
    if not self.updatePanel then return end
    self:UpdateUpdateDisplay()
    self.updatePanel:Show()
    self.updatePanel:Raise()
end

function AURA:CreateSettingRow(parent, setting, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 8, y)
    row:SetPoint("TOPRIGHT", -8, y)
    row:SetHeight(76)
    SetBackdrop(row, COLORS.panel, { 0.09, 0.22, 0.31, 0.9 })

    local accent = row:CreateTexture(nil, "ARTWORK")
    accent:SetTexture("Interface\\Buttons\\WHITE8X8")
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    accent:SetVertexColor(unpack(setting.type:find("external") and COLORS.gold or COLORS.cyan))

    local title = CreateLabel(row, setting.label, 13, COLORS.text)
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetPoint("RIGHT", row, "RIGHT", -205, 0)
    title:SetHeight(18)

    local description = CreateLabel(row, setting.description, 10, COLORS.muted)
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    description:SetPoint("RIGHT", row, "RIGHT", -205, 0)
    description:SetHeight(26)
    description:SetJustifyV("TOP")
    row.description = description

    local impact = CreateLabel(row, (IMPACT_COLORS[setting.impact] or "|cffffffff") .. "Performance hit: " .. setting.impact .. "|r" .. "   |cff8fa6baApply: " .. setting.apply .. "|r", 9, COLORS.muted)
    impact:SetPoint("BOTTOMLEFT", 14, 7)
    impact:SetPoint("RIGHT", row, "RIGHT", -205, 0)
    impact:SetHeight(13)

    local function AttachTooltip(widget)
        widget:EnableMouse(true)
        widget:HookScript("OnEnter", function(self) ShowSettingTooltip(self, setting) end)
        widget:HookScript("OnLeave", function()
            GameTooltip:Hide()
            AURA:RefreshRow(setting)
        end)
    end
    AttachTooltip(row)

    if setting.type == "toggle" or setting.type == "external-toggle" then
        row.control = CreateButton(row, "", 150, 30)
        row.control:SetPoint("RIGHT", -20, 0)
        row.control:SetScript("OnClick", function()
            AURA:SetPending(setting.id, not AURA.pending[setting.id])
        end)
        AttachTooltip(row.control)
    elseif setting.type == "choice" or setting.type == "external-choice" then
        row.control = CreateButton(row, "", 150, 30)
        row.control:SetPoint("RIGHT", -20, 0)
        row.control:SetScript("OnClick", function(_, mouseButton)
            local index = GetChoiceIndex(setting, AURA.pending[setting.id])
            if mouseButton == "RightButton" then
                index = index - 1
                if index < 1 then index = #setting.choices end
            else
                index = index + 1
                if index > #setting.choices then index = 1 end
            end
            AURA:SetPending(setting.id, setting.choices[index].value)
        end)
        row.control:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        AttachTooltip(row.control)
    elseif setting.type == "slider" then
        local sliderName = "AURAVisualUpgradeSlider_" .. setting.id
        row.control = CreateFrame("Slider", sliderName, row, "OptionsSliderTemplate")
        row.control:SetPoint("RIGHT", -38, 0)
        row.control:SetWidth(145)
        row.control:SetHeight(16)
        row.control:SetOrientation("HORIZONTAL")
        row.control:SetMinMaxValues(setting.min, setting.max)
        row.control:SetValueStep(setting.step)
        if _G[sliderName .. "Low"] then _G[sliderName .. "Low"]:Hide() end
        if _G[sliderName .. "High"] then _G[sliderName .. "High"]:Hide() end
        if _G[sliderName .. "Text"] then _G[sliderName .. "Text"]:Hide() end
        row.control:SetScript("OnValueChanged", function(self, value)
            if self.updating then return end
            local rounded = math.floor((value / setting.step) + 0.5) * setting.step
            AURA:SetPending(setting.id, rounded)
        end)
        row.valueLabel = CreateLabel(row, "", 11, COLORS.cyan, "CENTER")
        row.valueLabel:SetPoint("BOTTOM", row.control, "TOP", 0, 5)
        row.valueLabel:SetSize(setting.id == "maxFPS" and 190 or 80, 16)
        AttachTooltip(row.control)
    end

    self.rows[setting.id] = row
    self:RefreshRow(setting)
    return row
end

function AURA:CreateMinimapButton()
    local button = CreateFrame("Button", "AURAVisualUpgradeMinimapButton", Minimap)
    button:SetSize(34, 34)
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -7, -3)
    button:SetFrameStrata("MEDIUM")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\AURA_VisualUpgrade\\Textures\\AURA_MinimapIcon")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0, 1, 0, 1)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\AddOns\\AURA_VisualUpgrade\\Textures\\AURA_MinimapIcon")
    highlight:SetAllPoints(icon)
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.35)

    local updateBadge = button:CreateTexture(nil, "OVERLAY")
    updateBadge:SetTexture("Interface\\Buttons\\WHITE8X8")
    updateBadge:SetSize(9, 9)
    updateBadge:SetPoint("TOPRIGHT", -1, -1)
    updateBadge:SetVertexColor(unpack(COLORS.gold))
    updateBadge:Hide()

    button:SetScript("OnClick", function() AURA:Toggle() end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("AURA Visual Upgrade", 0.33, 0.84, 1)
        GameTooltip:AddLine("Open graphics profiles and visual-upgrade controls.", 0.9, 0.95, 1, true)
        GameTooltip:AddLine("/auravis", 0.95, 0.78, 0.32)
        if AURA.newestPeerVersion and AURA:CompareVersions(AURA.newestPeerVersion, AURA.VERSION) == 1 then
            GameTooltip:AddLine("Peer-reported update: v" .. AURA.newestPeerVersion, 0.95, 0.78, 0.32)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.minimapButton = button
    self.minimapUpdateBadge = updateBadge
end

function AURA:CreateInterfaceOptionsEntry()
    local panel = CreateFrame("Frame", "AURAVisualUpgradeOptionsPanel", UIParent)
    panel.name = "AURA Visual Upgrade"

    local eyebrow = CreateLabel(panel, "ABOUT", 9, COLORS.gold)
    eyebrow:SetPoint("TOPLEFT", 18, -16)
    local title = CreateLabel(panel, "AURA Visual Upgrade", 20, COLORS.cyan)
    title:SetPoint("TOPLEFT", eyebrow, "BOTTOMLEFT", 0, -5)
    local metadata = CreateLabel(panel, "Version " .. AURA.VERSION .. "  |  Author: Srixun", 11, COLORS.text)
    metadata:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    local note = CreateLabel(panel, "AURA Visual Upgrade provides staged graphics profiles, live performance guidance, and external visual-upgrade requests.", 12, COLORS.muted)
    note:SetPoint("TOPLEFT", metadata, "BOTTOMLEFT", 0, -18)
    note:SetPoint("RIGHT", -24, 0)
    note:SetHeight(40)
    note:SetJustifyV("TOP")

    local commandTitle = CreateLabel(panel, "CHAT COMMAND", 9, COLORS.gold)
    commandTitle:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -18)
    local command = CreateLabel(panel, "/auravis", 17, COLORS.cyan)
    command:SetPoint("TOPLEFT", commandTitle, "BOTTOMLEFT", 0, -5)
    local commandHelp = CreateLabel(panel, "Type /auravis in chat to open or close the AURA Visuals configuration menu from anywhere in-game.", 11, COLORS.muted)
    commandHelp:SetPoint("TOPLEFT", command, "BOTTOMLEFT", 0, -5)
    commandHelp:SetPoint("RIGHT", -24, 0)
    commandHelp:SetHeight(32)
    commandHelp:SetJustifyV("TOP")

    local accessTitle = CreateLabel(panel, "OTHER ACCESS", 9, COLORS.gold)
    accessTitle:SetPoint("TOPLEFT", commandHelp, "BOTTOMLEFT", 0, -15)
    local access = CreateLabel(panel, "Use the AV minimap button, this AddOns menu page, or /auravis. Settings remain staged until Apply is pressed.", 11, COLORS.muted)
    access:SetPoint("TOPLEFT", accessTitle, "BOTTOMLEFT", 0, -5)
    access:SetPoint("RIGHT", -24, 0)
    access:SetHeight(38)
    access:SetJustifyV("TOP")

    local communityTitle = CreateLabel(panel, "COMMUNITY", 9, COLORS.gold)
    communityTitle:SetPoint("TOPLEFT", access, "BOTTOMLEFT", 0, -15)
    local discord = CreateLabel(panel, "https://Discord.gg/AuraPub", 14, COLORS.cyan)
    discord:SetPoint("TOPLEFT", communityTitle, "BOTTOMLEFT", 0, -5)
    local welcome = CreateLabel(panel, "PvP'ers welcome", 11, COLORS.text)
    welcome:SetPoint("TOPLEFT", discord, "BOTTOMLEFT", 0, -5)

    local open = CreateButton(panel, "OPEN AURA VISUALS MENU", 240, 34)
    open:SetPoint("TOPLEFT", welcome, "BOTTOMLEFT", 0, -20)
    open:SetScript("OnClick", function() AURA:Show() end)
    InterfaceOptions_AddCategory(panel)
    self.optionsPanel = panel
end

function AURA:CreateUI()
    local frame = CreateFrame("Frame", "AURAVisualUpgradeFrame", UIParent)
    frame:SetSize(780, 680)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function()
        if AURA.updatePanel then AURA.updatePanel:Hide() end
    end)
    SetBackdrop(frame, COLORS.background, COLORS.border)
    frame:Hide()

    local topAccent = frame:CreateTexture(nil, "ARTWORK")
    topAccent:SetTexture("Interface\\Buttons\\WHITE8X8")
    topAccent:SetPoint("TOPLEFT", 1, -1)
    topAccent:SetPoint("TOPRIGHT", -1, -1)
    topAccent:SetHeight(4)
    topAccent:SetVertexColor(unpack(COLORS.cyan))

    local title = CreateLabel(frame, "AURA", 24, COLORS.cyan)
    title:SetPoint("TOPLEFT", 22, -18)
    local subtitle = CreateLabel(frame, "VISUAL UPGRADE", 13, COLORS.text)
    subtitle:SetPoint("LEFT", title, "RIGHT", 9, -2)
    local version = CreateLabel(frame, "v" .. self.VERSION .. "  by Srixun", 10, COLORS.muted, "RIGHT")
    version:SetPoint("TOPRIGHT", -244, -26)

    local updates = CreateButton(frame, "UPDATES", 105, 24)
    updates:SetPoint("TOPRIGHT", -126, -18)
    updates:SetScript("OnClick", function() AURA:ShowUpdatePanel() end)
    self.updateButton = updates

    local about = CreateButton(frame, "ABOUT", 68, 24)
    about:SetPoint("TOPRIGHT", -50, -18)
    about:SetScript("OnClick", function() AURA:OpenAbout() end)

    local close = CreateButton(frame, "X", 28, 28)
    close:SetPoint("TOPRIGHT", -16, -15)
    close:SetScript("OnClick", function() frame:Hide() end)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetPoint("TOPLEFT", 18, -58)
    divider:SetPoint("TOPRIGHT", -18, -58)
    divider:SetHeight(1)
    divider:SetVertexColor(0.13, 0.42, 0.60, 0.65)

    local dashboard = CreateFrame("Frame", nil, frame)
    dashboard:SetPoint("TOPLEFT", 18, -70)
    dashboard:SetPoint("TOPRIGHT", -18, -70)
    dashboard:SetHeight(66)
    SetBackdrop(dashboard, COLORS.panel, { 0.09, 0.22, 0.31, 0.9 })

    local dashboardItems = {
        { "OUTPUT", "dashboardResolution", 14 },
        { "LIVE PERFORMANCE", "dashboardFPS", 200 },
        { "EXTERNAL REQUEST", "dashboardRequest", 390 },
        { "FRAME GENERATION", "dashboardFrameGen", 590 }
    }
    for _, item in ipairs(dashboardItems) do
        local heading = CreateLabel(dashboard, item[1], 8, COLORS.muted)
        heading:SetPoint("TOPLEFT", item[3], -12)
        local value = CreateLabel(dashboard, "--", 13, COLORS.text)
        value:SetPoint("TOPLEFT", item[3], -31)
        self[item[2]] = value
    end

    local profileBar = CreateFrame("Frame", nil, frame)
    profileBar:SetPoint("TOPLEFT", 18, -146)
    profileBar:SetPoint("TOPRIGHT", -18, -146)
    profileBar:SetHeight(72)
    SetBackdrop(profileBar, COLORS.panel, { 0.09, 0.22, 0.31, 0.9 })

    self.profileDisplay = CreateLabel(profileBar, "", 9, COLORS.muted)
    self.profileDisplay:SetPoint("TOPLEFT", 12, -8)
    self:UpdateProfileDisplay(AURAVisualUpgradeDB.lastProfile)

    local recommended = CreateButton(profileBar, "ANALYZE & RECOMMEND", 170, 30)
    recommended:SetPoint("BOTTOMLEFT", 12, 9)
    recommended:SetScript("OnClick", function() AURA:StartAnalysis() end)

    local performance = CreateButton(profileBar, "PERFORMANCE", 125, 30)
    performance:SetPoint("LEFT", recommended, "RIGHT", 8, 0)
    performance:SetScript("OnClick", function() AURA:StageProfile("Performance") end)

    local raid = CreateButton(profileBar, "RAID", 125, 30)
    raid:SetPoint("LEFT", performance, "RIGHT", 8, 0)
    raid:SetScript("OnClick", function() AURA:StageProfile("Raid") end)

    local balanced = CreateButton(profileBar, "BALANCED", 125, 30)
    balanced:SetPoint("LEFT", raid, "RIGHT", 8, 0)
    balanced:SetScript("OnClick", function() AURA:StageProfile("Balanced") end)

    local quality = CreateButton(profileBar, "QUALITY", 125, 30)
    quality:SetPoint("LEFT", balanced, "RIGHT", 8, 0)
    quality:SetScript("OnClick", function() AURA:StageProfile("Quality") end)

    local scroll = CreateFrame("ScrollFrame", "AURAVisualUpgradeScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -228)
    scroll:SetPoint("BOTTOMRIGHT", -36, 64)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(708)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local bar = _G[self:GetName() .. "ScrollBar"]
        local minimum, maximum = bar:GetMinMaxValues()
        local nextValue = math.max(minimum, math.min(maximum, bar:GetValue() - delta * 42))
        bar:SetValue(nextValue)
    end)

    local y = -4
    local currentCategory
    for _, setting in ipairs(self.supportedSettings) do
        if setting.category ~= currentCategory then
            currentCategory = setting.category
            local category = CreateLabel(content, currentCategory, 10, currentCategory == "AURA EXTERNAL UPGRADE" and COLORS.gold or COLORS.cyan)
            category:SetPoint("TOPLEFT", 10, y - 8)
            category:SetHeight(20)
            if currentCategory == "AURA EXTERNAL UPGRADE" then
                local categoryNote = CreateLabel(content, "Saved as a request; requires the companion sync or a manual NVIDIA change.", 9, COLORS.muted)
                categoryNote:SetPoint("TOPRIGHT", -12, y - 9)
            end
            y = y - 34
        end
        self:CreateSettingRow(content, setting, y)
        y = y - 84
    end
    content:SetHeight(math.abs(y) + 12)

    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", 18, 14)
    footer:SetPoint("BOTTOMRIGHT", -18, 14)
    footer:SetHeight(40)
    SetBackdrop(footer, COLORS.panel, { 0.09, 0.22, 0.31, 0.9 })

    self.footerStatus = CreateLabel(footer, "Ready.", 10, COLORS.muted)
    self.footerStatus:SetPoint("LEFT", 12, 0)
    self.footerStatus:SetPoint("RIGHT", footer, "RIGHT", -260, 0)
    self.footerStatus:SetHeight(30)

    local reset = CreateButton(footer, "RESET STAGED", 112, 26)
    reset:SetPoint("RIGHT", -132, 0)
    reset:SetScript("OnClick", function() AURA:ResetStaged() end)
    local apply = CreateButton(footer, "APPLY", 112, 26)
    apply:SetPoint("RIGHT", -10, 0)
    apply:SetScript("OnClick", function() AURA:ApplySettings() end)
    apply:SetBackdropColor(0.05, 0.30, 0.25, 1)
    apply:SetBackdropBorderColor(unpack(COLORS.green))

    frame:SetScript("OnShow", function()
        AURA:LoadPendingValues()
        AURA:RefreshAllRows()
        AURA:UpdateDashboard()
        AURA:UpdateProfileDisplay(AURA.stagedProfile)
        AURA:UpdateUpdateDisplay()
        AURA:UpdateFooter("Settings are staged until Apply is pressed.", 0.55, 0.65, 0.75)
    end)

    self.frame = frame
    self.scrollFrame = scroll
    self:CreateMinimapButton()
    self:CreateInterfaceOptionsEntry()
    self:CreateUpdatePanel(frame)
    self:UpdateDashboard()
    table.insert(UISpecialFrames, frame:GetName())
end

function AURA:Show()
    if not self.frame then return end
    self.frame:Show()
    self.frame:Raise()
end

function AURA:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Show()
    end
end

function AURA:OpenAbout()
    if self.frame then self.frame:Hide() end
    if self.optionsPanel and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    elseif self.optionsPanel then
        self.optionsPanel:Show()
    end
end
