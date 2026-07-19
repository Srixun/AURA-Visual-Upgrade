local _, AURA = ...

local THEME
local COLORS
local THEME_FONT

local IMPACT_COLORS = {
    Low = "|cff66ff8c",
    Medium = "|cffffca52",
    High = "|cffff6262"
}

local function SetBackdrop(frame, style)
    AURA:ApplyBackdrop(frame, style)
end

local function CreateLabel(parent, text, size, color, justify)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if not label:SetFont(THEME_FONT or STANDARD_TEXT_FONT, size or 12, "") then
        label:SetFont(STANDARD_TEXT_FONT, size or 12, "")
    end
    label:SetText(text or "")
    label:SetTextColor(unpack(color or COLORS.text))
    label:SetJustifyH(justify or "LEFT")
    label:SetJustifyV("MIDDLE")
    return label
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 110, height or 28)
    button:SetText(text or "")
    button.label = button:GetFontString()
    if not button.label then
        button.label = CreateLabel(button, text, 11, COLORS.text, "CENTER")
        button.label:SetAllPoints()
    end
    button.label:SetTextColor(unpack(COLORS.text))
    AURA:ApplySkinProviders(button, "button")
    return button
end

local function CreateCloseButton(parent)
    local button = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    button:SetSize(32, 32)
    AURA:ApplySkinProviders(button, "close-button")
    return button
end

local function CreateWindowHeader(parent, text, width)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(width or 360, 64)
    header:SetPoint("TOP", 0, 12)
    local texture = header:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(THEME.textures.header)
    texture:SetAllPoints()
    local title = CreateLabel(header, text, 17, COLORS.text, "CENTER")
    title:SetPoint("CENTER", 0, THEME.layout.windowTitleY)
    title:SetSize((width or 360) - 70, 24)
    header.texture, header.title = texture, title
    AURA:ApplySkinProviders(header, "window-header")
    return title
end

local function CreateSectionHeader(parent, text, y)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", 4, y)
    header:SetPoint("TOPRIGHT", -4, y)
    header:SetHeight(28)
    local texture = header:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(THEME.textures.header)
    texture:SetPoint("CENTER")
    texture:SetSize(340, 42)
    local label = CreateLabel(header, text, 12, COLORS.gold, "CENTER")
    label:SetPoint("CENTER", 0, THEME.layout.sectionTitleY)
    label:SetSize(320, 24)
    AURA:ApplySkinProviders(header, "section-header")
    return header, label
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

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 then return math.atan(y / x) - math.pi end
    if y > 0 then return math.pi / 2 end
    if y < 0 then return -math.pi / 2 end
    return 0
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
            row.control.label:SetTextColor(unpack(COLORS.green))
        else
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
            if self.pending.frameGeneration then
                row.valueLabel:SetText(string.format("%d real  /  ~%d displayed", numeric, numeric * 2))
            else
                row.valueLabel:SetText(string.format("%d FPS cap", numeric))
            end
            row.description:SetText(setting.description)
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
    local notice = self.GetOutstandingNoticeText and self:GetOutstandingNoticeText() or ""
    self.footerStatus:SetText((message or "Ready.") .. notice)
    if red then
        self.footerStatus:SetTextColor(red, green, blue)
    else
        self.footerStatus:SetTextColor(unpack(COLORS.muted))
    end
end

function AURA:UpdateProfileDisplay(profileName)
    if not self.profileDisplay then return end
    self.profileDisplay:SetText("Staged Profile:  |cffffd100" .. tostring(profileName or "Custom") .. "|r")
end

function AURA:UpdateDashboard()
    if not self.dashboardResolution then return end
    if self.frame and not self.frame:IsShown() then return end
    self.dashboardResolution:SetText(self:GetResolution())
    self.dashboardFPS:SetText(string.format("%.0f FPS", GetFramerate and GetFramerate() or 0))
    local external = AURAVisualUpgradeDB and AURAVisualUpgradeDB.external or {}
    local externalEnabled = self.pending.externalSyncEnabled
    if externalEnabled == nil then externalEnabled = external.externalSyncEnabled end
    local renderer = self.pending.renderer or external.renderer or "DX12"
    local reshade = self.pending.reshade or external.reshade or "Off"
    self.dashboardRequest:SetText(externalEnabled and (renderer .. " / " .. reshade) or "No external changes")
    local optimizer = self.optimizer or {}
    self.dashboardOptimizer:SetText(string.format("%s / %d FPS", optimizer.enabled and "Active" or "Paused", self:GetEffectiveTargetFPS()))
    self.dashboardOptimizer:SetTextColor(unpack(optimizer.enabled and COLORS.green or COLORS.muted))
end

function AURA:UpdateOptimizerDisplay()
    if not self.optimizerTargetButton or not self.optimizer then return end
    if not self.optimizerPanel or not self.optimizerPanel:IsShown() then return end
    self.optimizerTargetButton.label:SetText(string.format("Target  %d FPS  >", self.optimizer.targetFPS or 60))
    self.optimizerGoalButton.label:SetText((self.optimizer.goal or "Balanced") .. "  >")
    local waitingForCombat = self.optimizer.blocked == "Waiting to revert a protected test change after combat."
    self.optimizerState:SetText(waitingForCombat and "Waiting to Revert After Combat"
        or (self.optimizer.blocked and "Adaptive State Requires Restoration"
        or (self.optimizer.enabled and "Adaptive Optimization Active" or "Adaptive Optimization Paused"))
    )
    self.optimizerState:SetTextColor(unpack(self.optimizer.enabled and COLORS.green or COLORS.gold))
    self.optimizerContext:SetText(self:GetOptimizerContext())
    self.optimizerEffectiveTarget:SetText(string.format("%d FPS", self:GetEffectiveTargetFPS()))
    if #self.optimizerSamples < 20 and self.optimizer.enabled then
        self.optimizerAverageLabel:SetText("Warming up")
        self.optimizerLowLabel:SetText("Warming up")
    else
        self.optimizerAverageLabel:SetText(string.format("%.0f FPS", self.optimizerAverage or 0))
        self.optimizerLowLabel:SetText(string.format("%.0f FPS", self.optimizerLow or 0))
    end
    self.optimizerChangesLabel:SetText(tostring(#self.optimizer.changes))
    self.optimizerAction:SetText(self.optimizer.lastAction or "No adaptive changes have been made.")
    if waitingForCombat then
        self.optimizerToggleButton.label:SetText("Waiting for Combat")
    elseif self.optimizer.blocked then
        self.optimizerToggleButton.label:SetText("Resolve State")
    elseif self.optimizer.enabled then
        self.optimizerToggleButton.label:SetText("Pause Adaptive")
    elseif next(self.optimizer.snapshot) then
        self.optimizerToggleButton.label:SetText("Resume Adaptive")
    else
        self.optimizerToggleButton.label:SetText("Start Adaptive")
    end
    local benchmark = self.optimizer.lastBenchmark or {}
    if benchmark.average then
        self.optimizerBenchmark:SetText(string.format("Last benchmark: %.0f average / %.0f low at a %d FPS target (%s).", benchmark.average, benchmark.low or 0, benchmark.target or 0, benchmark.context or "Unknown"))
    else
        self.optimizerBenchmark:SetText("No benchmark has been completed yet.")
    end
end

function AURA:CreateOptimizerPanel(parent)
    local panel = CreateFrame("Frame", "AURAVisualUpgradeOptimizerFrame", parent)
    panel:SetSize(620, 420)
    panel:SetPoint("CENTER")
    panel:SetFrameLevel(parent:GetFrameLevel() + 20)
    panel:EnableMouse(true)
    SetBackdrop(panel, "window")
    self:ApplySkinProviders(panel, "window")
    panel:Hide()

    local title = CreateWindowHeader(panel, "Adaptive Optimization", 360)
    local close = CreateCloseButton(panel)
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() panel:Hide() end)
    local description = CreateLabel(panel, "Hardware-neutral tuning based only on measured frame stability. External graphics and restart-required settings are never changed.", 10, COLORS.muted)
    description:SetPoint("TOPLEFT", 24, -50)
    description:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    description:SetHeight(32)
    description:SetJustifyV("TOP")

    self.optimizerState = CreateLabel(panel, "", 11, COLORS.gold)
    self.optimizerState:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -8)
    self.optimizerTargetButton = CreateButton(panel, "", 180, 30)
    self.optimizerTargetButton:SetPoint("TOPLEFT", self.optimizerState, "BOTTOMLEFT", 0, -10)
    self.optimizerTargetButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.optimizerTargetButton:SetScript("OnClick", function(_, mouseButton) AURA:CycleOptimizerTarget(mouseButton == "RightButton" and -1 or 1) end)
    self.optimizerGoalButton = CreateButton(panel, "", 180, 30)
    self.optimizerGoalButton:SetPoint("LEFT", self.optimizerTargetButton, "RIGHT", 10, 0)
    self.optimizerGoalButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.optimizerGoalButton:SetScript("OnClick", function(_, mouseButton) AURA:CycleOptimizerGoal(mouseButton == "RightButton" and -1 or 1) end)

    local telemetry = CreateFrame("Frame", nil, panel)
    telemetry:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -146)
    telemetry:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -146)
    telemetry:SetHeight(78)
    SetBackdrop(telemetry, "panel")
    self:ApplySkinProviders(telemetry, "panel")
    local items = {
        { "Context", "optimizerContext", 12 },
        { "Effective Target", "optimizerEffectiveTarget", 155 },
        { "Rolling Average", "optimizerAverageLabel", 310 },
        { "Approx. Low", "optimizerLowLabel", 455 }
    }
    for _, item in ipairs(items) do
        local heading = CreateLabel(telemetry, item[1], 8, COLORS.muted)
        heading:SetPoint("TOPLEFT", item[3], -12)
        local value = CreateLabel(telemetry, "--", 12, COLORS.text)
        value:SetPoint("TOPLEFT", item[3], -34)
        self[item[2]] = value
    end
    local changesHeading = CreateLabel(telemetry, "Active Changes", 8, COLORS.muted)
    changesHeading:SetPoint("BOTTOMLEFT", 12, 7)
    self.optimizerChangesLabel = CreateLabel(telemetry, "0", 10, COLORS.gold)
    self.optimizerChangesLabel:SetPoint("LEFT", changesHeading, "RIGHT", 8, 0)

    local actionHeading = CreateLabel(panel, "Last Adaptive Action", 9, COLORS.gold)
    actionHeading:SetPoint("TOPLEFT", telemetry, "BOTTOMLEFT", 0, -14)
    self.optimizerAction = CreateLabel(panel, "", 10, COLORS.text)
    self.optimizerAction:SetPoint("TOPLEFT", actionHeading, "BOTTOMLEFT", 0, -5)
    self.optimizerAction:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    self.optimizerAction:SetHeight(32)
    self.optimizerAction:SetJustifyV("TOP")
    self.optimizerBenchmark = CreateLabel(panel, "", 10, COLORS.muted)
    self.optimizerBenchmark:SetPoint("TOPLEFT", self.optimizerAction, "BOTTOMLEFT", 0, -8)
    self.optimizerBenchmark:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    self.optimizerBenchmark:SetHeight(28)

    self.optimizerToggleButton = CreateButton(panel, "Start Adaptive", 140, 30)
    self.optimizerToggleButton:SetPoint("BOTTOMLEFT", 18, 18)
    self.optimizerToggleButton:SetScript("OnClick", function()
        if AURA.optimizer.blocked == "Waiting to revert a protected test change after combat." then
            AURA:UpdateFooter(AURA.optimizer.blocked, 1, 0.65, 0.3)
        elseif AURA.optimizer.blocked then
            AURA:RestoreOptimizerBaseline()
        elseif AURA.optimizer.enabled then
            AURA:PauseOptimizer()
        else
            AURA:StartOptimizer()
        end
    end)
    local benchmarkButton = CreateButton(panel, "Run 15s Benchmark", 140, 30)
    benchmarkButton:SetPoint("LEFT", self.optimizerToggleButton, "RIGHT", 6, 0)
    benchmarkButton:SetScript("OnClick", function() AURA:StartAnalysis() end)
    local restoreButton = CreateButton(panel, "Restore Baseline", 140, 30)
    restoreButton:SetPoint("LEFT", benchmarkButton, "RIGHT", 6, 0)
    restoreButton:SetScript("OnClick", function() AURA:RestoreOptimizerBaseline() end)
    local relinquishButton = CreateButton(panel, "Relinquish", 140, 30)
    relinquishButton:SetPoint("LEFT", restoreButton, "RIGHT", 6, 0)
    relinquishButton:SetScript("OnClick", function() StaticPopup_Show("AURA_VISUAL_RELINQUISH") end)

    self.optimizerPanel = panel
    panel:SetScript("OnShow", function() AURA:UpdateOptimizerDisplay() end)
end

function AURA:ShowOptimizerPanel()
    if not self.optimizerPanel then return end
    if self.updatePanel then self.updatePanel:Hide() end
    self.optimizerPanel:Show()
    self:UpdateOptimizerDisplay()
    self.optimizerPanel:Raise()
end

function AURA:UpdateUpdateDisplay()
    local newer = self.newestPeerVersion and self:CompareVersions(self.newestPeerVersion, self.VERSION) == 1
    if self.updateButton then
        self.updateButton.label:SetText(newer and "Update Found" or "Updates")
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
        self.updateVersion:SetText(newer and ("Local v" .. self.VERSION .. "  |  Peer-reported v" .. self.newestPeerVersion) or ("Local v" .. self.VERSION))
    end
end

function AURA:CreateUpdatePanel(parent)
    local panel = CreateFrame("Frame", "AURAVisualUpgradeUpdateFrame", parent)
    panel:SetSize(540, 230)
    panel:SetPoint("CENTER")
    panel:SetFrameLevel(parent:GetFrameLevel() + 20)
    panel:EnableMouse(true)
    SetBackdrop(panel, "window")
    self:ApplySkinProviders(panel, "window")
    panel:Hide()

    local title = CreateWindowHeader(panel, "AURA Update Awareness", 330)
    local close = CreateCloseButton(panel)
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() panel:Hide() end)

    self.updateVersion = CreateLabel(panel, "Local v" .. self.VERSION, 10, COLORS.text)
    self.updateVersion:SetPoint("TOPLEFT", 24, -50)
    self.updateStatus = CreateLabel(panel, "No peer version check has run this session.", 11, COLORS.muted)
    self.updateStatus:SetPoint("TOPLEFT", self.updateVersion, "BOTTOMLEFT", 0, -10)
    self.updateStatus:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    self.updateStatus:SetHeight(38)
    self.updateStatus:SetJustifyV("TOP")

    local official = CreateLabel(panel, "Official Releases - select the link and press Ctrl+C", 9, COLORS.gold)
    official:SetPoint("TOPLEFT", self.updateStatus, "BOTTOMLEFT", 0, -8)
    local link = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    link:SetPoint("TOPLEFT", official, "BOTTOMLEFT", 4, -7)
    link:SetSize(490, 28)
    link:SetAutoFocus(false)
    link:SetFontObject(ChatFontNormal)
    link:SetText(self.RELEASES_URL)
    link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    link:SetScript("OnMouseUp", function(self) self:SetFocus() self:HighlightText() end)

    local check = CreateButton(panel, "Check Peers", 150, 28)
    check:SetPoint("BOTTOMLEFT", 20, 17)
    check:SetScript("OnClick", function() AURA:CheckPeerVersions() end)
    local selectLink = CreateButton(panel, "Select Release Link", 180, 28)
    selectLink:SetPoint("LEFT", check, "RIGHT", 8, 0)
    selectLink:SetScript("OnClick", function() link:SetFocus() link:HighlightText() end)
    local done = CreateButton(panel, "Close", 130, 28)
    done:SetPoint("LEFT", selectLink, "RIGHT", 8, 0)
    done:SetScript("OnClick", function() panel:Hide() end)

    self.updatePanel = panel
    self.updateLink = link
    self:UpdateUpdateDisplay()
end

function AURA:ShowUpdatePanel()
    if not self.updatePanel then return end
    if self.optimizerPanel then self.optimizerPanel:Hide() end
    self:UpdateUpdateDisplay()
    self.updatePanel:Show()
    self.updatePanel:Raise()
end

function AURA:CreateSettingRow(parent, setting, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 8, y)
    row:SetPoint("TOPRIGHT", -8, y)
    row:SetHeight(76)
    SetBackdrop(row, "row")
    self:ApplySkinProviders(row, "setting-row")

    local accent = row:CreateTexture(nil, "ARTWORK")
    accent:SetTexture(THEME.textures.highlight)
    accent:SetPoint("TOPLEFT", 4, -4)
    accent:SetPoint("BOTTOMRIGHT", -4, 4)
    accent:SetVertexColor(unpack(setting.type:find("external") and COLORS.gold or COLORS.text))
    accent:SetAlpha(0.06)

    local title = CreateLabel(row, setting.label, 13, COLORS.gold)
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
            if tostring(AURA.pending[setting.id]) == tostring(rounded) then return end
            AURA:SetPending(setting.id, rounded)
        end)
        row.valueLabel = CreateLabel(row, "", 11, COLORS.cyan, "CENTER")
        row.valueLabel:SetPoint("BOTTOM", row.control, "TOP", 0, 5)
        row.valueLabel:SetSize(setting.id == "maxFPS" and 190 or 80, 16)
        AttachTooltip(row.control)
        self:ApplySkinProviders(row.control, "slider")
    end

    self.rows[setting.id] = row
    self:RefreshRow(setting)
    return row
end

function AURA:UpdateMinimapButtonPosition()
    if not self.minimapButton then return end
    local angle = math.rad(AURAVisualUpgradeDB.minimapAngle or 220)
    local radius = (math.max(Minimap:GetWidth(), Minimap:GetHeight()) / 2) + 8
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function AURA:UpdateMinimapButtonFromCursor()
    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then return end
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    AURAVisualUpgradeDB.minimapAngle = math.deg(Atan2(cursorY - centerY, cursorX - centerX))
    self:UpdateMinimapButtonPosition()
end

function AURA:CreateMinimapButton()
    local button = CreateFrame("Button", "AURAVisualUpgradeMinimapButton", Minimap)
    button:SetSize(34, 34)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\AURA_VisualUpgrade\\Textures\\AURA_FullLogo")
    icon:SetSize(30, 30)
    icon:SetPoint("CENTER")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetSize(32, 32)
    highlight:SetPoint("CENTER")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.35)

    local updateBadge = button:CreateTexture(nil, "OVERLAY")
    updateBadge:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    updateBadge:SetBlendMode("ADD")
    updateBadge:SetSize(17, 17)
    updateBadge:SetPoint("TOPRIGHT", 1, 1)
    updateBadge:Hide()

    button:SetScript("OnClick", function() AURA:Toggle() end)
    local function StopDragging(self)
        if not self.dragging then return end
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        AURA:UpdateMinimapButtonFromCursor()
    end
    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function() AURA:UpdateMinimapButtonFromCursor() end)
    end)
    button:SetScript("OnDragStop", StopDragging)
    button:SetScript("OnMouseUp", StopDragging)
    button:SetScript("OnHide", StopDragging)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("AURA Visual Upgrade", 0.33, 0.84, 1)
        GameTooltip:AddLine("Open graphics profiles and visual-upgrade controls.", 0.9, 0.95, 1, true)
        GameTooltip:AddLine("Drag to reposition around the minimap.", 0.9, 0.95, 1, true)
        GameTooltip:AddLine("/auravis", 0.95, 0.78, 0.32)
        if AURA.newestPeerVersion and AURA:CompareVersions(AURA.newestPeerVersion, AURA.VERSION) == 1 then
            GameTooltip:AddLine("Peer-reported update: v" .. AURA.newestPeerVersion, 0.95, 0.78, 0.32)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.minimapButton = button
    self.minimapUpdateBadge = updateBadge
    self:UpdateMinimapButtonPosition()
    self:ApplySkinProviders(button, "minimap-button")
end

function AURA:CreateInterfaceOptionsEntry()
    local panel = CreateFrame("Frame", "AURAVisualUpgradeOptionsPanel", UIParent)
    panel.name = "AURA Visual Upgrade"

    local eyebrow = CreateLabel(panel, "About", 9, COLORS.gold)
    eyebrow:SetPoint("TOPLEFT", 18, -16)
    local title = CreateLabel(panel, "AURA Visual Upgrade", 20, COLORS.gold)
    title:SetPoint("TOPLEFT", eyebrow, "BOTTOMLEFT", 0, -5)
    local metadata = CreateLabel(panel, "Version " .. AURA.VERSION .. "  |  Author: Srixun", 11, COLORS.text)
    metadata:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    local note = CreateLabel(panel, "AURA Visual Upgrade provides staged graphics profiles, live performance guidance, and external visual-upgrade requests.", 12, COLORS.muted)
    note:SetPoint("TOPLEFT", metadata, "BOTTOMLEFT", 0, -18)
    note:SetPoint("RIGHT", -24, 0)
    note:SetHeight(40)
    note:SetJustifyV("TOP")

    local commandTitle = CreateLabel(panel, "Chat Command", 9, COLORS.gold)
    commandTitle:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -18)
    local command = CreateLabel(panel, "/auravis", 17, COLORS.cyan)
    command:SetPoint("TOPLEFT", commandTitle, "BOTTOMLEFT", 0, -5)
    local commandHelp = CreateLabel(panel, "Use /auravis to open the dashboard, /auravis optimize for Adaptive Optimization, or /auravis benchmark to run a measured recommendation.", 11, COLORS.muted)
    commandHelp:SetPoint("TOPLEFT", command, "BOTTOMLEFT", 0, -5)
    commandHelp:SetPoint("RIGHT", -24, 0)
    commandHelp:SetHeight(32)
    commandHelp:SetJustifyV("TOP")

    local accessTitle = CreateLabel(panel, "Other Access", 9, COLORS.gold)
    accessTitle:SetPoint("TOPLEFT", commandHelp, "BOTTOMLEFT", 0, -15)
    local access = CreateLabel(panel, "Use the AV minimap button, this AddOns menu page, or /auravis. Settings remain staged until Apply is pressed.", 11, COLORS.muted)
    access:SetPoint("TOPLEFT", accessTitle, "BOTTOMLEFT", 0, -5)
    access:SetPoint("RIGHT", -24, 0)
    access:SetHeight(38)
    access:SetJustifyV("TOP")

    local communityTitle = CreateLabel(panel, "Community", 9, COLORS.gold)
    communityTitle:SetPoint("TOPLEFT", access, "BOTTOMLEFT", 0, -15)
    local discord = CreateLabel(panel, "https://Discord.gg/AuraPub", 14, COLORS.cyan)
    discord:SetPoint("TOPLEFT", communityTitle, "BOTTOMLEFT", 0, -5)
    local welcome = CreateLabel(panel, "PvP'ers welcome", 11, COLORS.text)
    welcome:SetPoint("TOPLEFT", discord, "BOTTOMLEFT", 0, -5)

    local open = CreateButton(panel, "Open AURA Visuals Menu", 240, 34)
    open:SetPoint("TOPLEFT", welcome, "BOTTOMLEFT", 0, -20)
    open:SetScript("OnClick", function() AURA:Show() end)
    InterfaceOptions_AddCategory(panel)
    self.optionsPanel = panel
end

function AURA:CreateUI()
    THEME = self:GetTheme()
    self.activeTheme = THEME
    COLORS = THEME.colors
    THEME_FONT = self:ResolveMedia("font", THEME.font, STANDARD_TEXT_FONT)
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
        if AURA.optimizerPanel then AURA.optimizerPanel:Hide() end
        if AURA.RefreshUpdateDriver then AURA:RefreshUpdateDriver() end
    end)
    SetBackdrop(frame, "window")
    self:ApplySkinProviders(frame, "window")
    frame:Hide()

    local title = CreateWindowHeader(frame, "AURA Visual Upgrade", 390)

    local portrait = CreateFrame("Frame", nil, frame)
    portrait:SetSize(52, 52)
    portrait:SetPoint("TOPLEFT", 10, -7)
    local portraitIcon = portrait:CreateTexture(nil, "ARTWORK")
    portraitIcon:SetTexture("Interface\\AddOns\\AURA_VisualUpgrade\\Textures\\AURA_FullLogo")
    portraitIcon:SetAllPoints()

    local version = CreateLabel(frame, "v" .. self.VERSION .. "  by Srixun", 10, COLORS.muted)
    version:SetPoint("TOPLEFT", 70, -39)

    local optimizer = CreateButton(frame, "Optimizer", 105, 24)
    optimizer:SetPoint("TOPRIGHT", -238, -40)
    optimizer:SetScript("OnClick", function() AURA:ShowOptimizerPanel() end)

    local updates = CreateButton(frame, "Updates", 105, 24)
    updates:SetPoint("TOPRIGHT", -126, -40)
    updates:SetScript("OnClick", function() AURA:ShowUpdatePanel() end)
    self.updateButton = updates

    local about = CreateButton(frame, "About", 68, 24)
    about:SetPoint("TOPRIGHT", -50, -40)
    about:SetScript("OnClick", function() AURA:OpenAbout() end)

    local close = CreateCloseButton(frame)
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() frame:Hide() end)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(THEME.textures.divider)
    divider:SetPoint("TOPLEFT", 18, -66)
    divider:SetPoint("TOPRIGHT", -18, -66)
    divider:SetHeight(8)
    divider:SetTexCoord(0, 0.75390625, 0, 0.5)
    divider:SetVertexColor(unpack(COLORS.border))

    local dashboard = CreateFrame("Frame", nil, frame)
    dashboard:SetPoint("TOPLEFT", 18, -76)
    dashboard:SetPoint("TOPRIGHT", -18, -76)
    dashboard:SetHeight(66)
    SetBackdrop(dashboard, "panel")
    self:ApplySkinProviders(dashboard, "panel")

    local dashboardItems = {
        { "Output", "dashboardResolution", 14 },
        { "Live Performance", "dashboardFPS", 200 },
        { "External Request", "dashboardRequest", 390 },
        { "Adaptive Target", "dashboardOptimizer", 590 }
    }
    for _, item in ipairs(dashboardItems) do
        local heading = CreateLabel(dashboard, item[1], 9, COLORS.gold)
        heading:SetPoint("TOPLEFT", item[3], -12)
        local value = CreateLabel(dashboard, "--", 13, COLORS.text)
        value:SetPoint("TOPLEFT", item[3], -31)
        self[item[2]] = value
    end

    local profileBar = CreateFrame("Frame", nil, frame)
    profileBar:SetPoint("TOPLEFT", 18, -152)
    profileBar:SetPoint("TOPRIGHT", -18, -152)
    profileBar:SetHeight(72)
    SetBackdrop(profileBar, "panel")
    self:ApplySkinProviders(profileBar, "panel")

    self.profileDisplay = CreateLabel(profileBar, "", 9, COLORS.muted)
    self.profileDisplay:SetPoint("TOPLEFT", 12, -8)
    self:UpdateProfileDisplay(AURAVisualUpgradeDB.lastProfile)

    local recommended = CreateButton(profileBar, "Benchmark & Recommend", 170, 30)
    recommended:SetPoint("BOTTOMLEFT", 12, 9)
    recommended:SetScript("OnClick", function() AURA:StartAnalysis() end)

    local performance = CreateButton(profileBar, "Performance", 125, 30)
    performance:SetPoint("LEFT", recommended, "RIGHT", 8, 0)
    performance:SetScript("OnClick", function() AURA:StageProfile("Performance") end)

    local raid = CreateButton(profileBar, "Raid", 125, 30)
    raid:SetPoint("LEFT", performance, "RIGHT", 8, 0)
    raid:SetScript("OnClick", function() AURA:StageProfile("Raid") end)

    local balanced = CreateButton(profileBar, "Balanced", 125, 30)
    balanced:SetPoint("LEFT", raid, "RIGHT", 8, 0)
    balanced:SetScript("OnClick", function() AURA:StageProfile("Balanced") end)

    local quality = CreateButton(profileBar, "Quality", 125, 30)
    quality:SetPoint("LEFT", balanced, "RIGHT", 8, 0)
    quality:SetScript("OnClick", function() AURA:StageProfile("Quality") end)

    local scrollInset = CreateFrame("Frame", nil, frame)
    scrollInset:SetPoint("TOPLEFT", 18, -234)
    scrollInset:SetPoint("BOTTOMRIGHT", -18, 64)
    SetBackdrop(scrollInset, "panel")
    self:ApplySkinProviders(scrollInset, "panel")

    local scroll = CreateFrame("ScrollFrame", "AURAVisualUpgradeScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -234)
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
    self:ApplySkinProviders(scroll, "scroll-frame")

    local y = -4
    local currentCategory
    for _, setting in ipairs(self.supportedSettings) do
        if setting.category ~= currentCategory then
            currentCategory = setting.category
            local _, category = CreateSectionHeader(content, currentCategory, y - 4)
            if currentCategory == "AURA External Upgrade" then
                local categoryNote = CreateLabel(content, "Saved as a request; requires the companion sync or a manual NVIDIA change.", 9, COLORS.muted)
                categoryNote:SetPoint("TOPRIGHT", -12, y - 28)
                y = y - 14
            end
            y = y - 38
        end
        self:CreateSettingRow(content, setting, y)
        y = y - 84
    end
    content:SetHeight(math.abs(y) + 12)

    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", 18, 14)
    footer:SetPoint("BOTTOMRIGHT", -18, 14)
    footer:SetHeight(40)
    SetBackdrop(footer, "panel")
    self:ApplySkinProviders(footer, "panel")

    self.footerStatus = CreateLabel(footer, "Ready.", 10, COLORS.muted)
    self.footerStatus:SetPoint("LEFT", 12, 0)
    self.footerStatus:SetPoint("RIGHT", footer, "RIGHT", -260, 0)
    self.footerStatus:SetHeight(30)

    local reset = CreateButton(footer, "Reset Staged", 112, 26)
    reset:SetPoint("RIGHT", -132, 0)
    reset:SetScript("OnClick", function() AURA:ResetStaged() end)
    local apply = CreateButton(footer, "Apply", 112, 26)
    apply:SetPoint("RIGHT", -10, 0)
    apply:SetScript("OnClick", function() AURA:ApplySettings() end)

    frame:SetScript("OnShow", function()
        AURA:RefreshPendingLiveValues()
        AURA:RefreshAllRows()
        AURA:UpdateDashboard()
        AURA:UpdateProfileDisplay(AURA.stagedProfile)
        AURA:UpdateUpdateDisplay()
        AURA:UpdateOptimizerDisplay()
        if next(AURA.manuallyStaged) then
            AURA:UpdateFooter("Changes are staged. Press Apply or Reset Staged.", 0.95, 0.78, 0.32)
        else
            AURA:UpdateFooter("Settings are staged until Apply is pressed.", 0.55, 0.65, 0.75)
        end
        if AURA.RefreshUpdateDriver then AURA:RefreshUpdateDriver() end
    end)

    self.frame = frame
    self.scrollFrame = scroll
    self:CreateMinimapButton()
    self:CreateInterfaceOptionsEntry()
    self:CreateUpdatePanel(frame)
    self:CreateOptimizerPanel(frame)
    self:UpdateDashboard()
    self:UpdateWindowScale()
    table.insert(UISpecialFrames, frame:GetName())
end

function AURA:UpdateWindowScale()
    if not self.frame or not UIParent then return end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then return end
    local scale = math.min(1, (width - 32) / 780, (height - 32) / 692)
    self.frame:SetScale(math.max(0.5, scale))
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
