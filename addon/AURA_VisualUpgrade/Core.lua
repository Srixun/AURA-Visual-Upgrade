local addonName, AURA = ...

if type(AURA) ~= "table" then
    AURA = {}
end

_G.AURAVisualUpgrade = AURA
AURA.addonName = addonName
AURA.pending = {}
AURA.manuallyStaged = {}
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

local function ValuesEqual(left, right)
    local leftNumber, rightNumber = tonumber(left), tonumber(right)
    if leftNumber and rightNumber then
        return math.abs(leftNumber - rightNumber) < 0.001
    end
    return tostring(left) == tostring(right)
end

local function FindNextLowerValue(values, current, minimum)
    local currentNumber = tonumber(current)
    if not currentNumber then return nil end
    for _, value in ipairs(values) do
        local valueNumber = tonumber(value)
        if valueNumber and valueNumber < currentNumber - 0.001 and (not minimum or valueNumber >= minimum) then
            return value
        end
    end
    return nil
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

function AURA:WriteCVar(name, value, deferredReadback)
    if self:ReadCVar(name) == nil then
        return false
    end
    local ok, result = pcall(SetCVar, name, tostring(value))
    if not ok or result == false then return false end
    local actual = self:ReadCVar(name)
    return actual ~= nil and (ValuesEqual(actual, value) or deferredReadback == true)
end

function AURA:IsExternalSetting(setting)
    return setting.type == "external-toggle" or setting.type == "external-choice"
end

function AURA:IsSettingSupported(setting)
    if self:IsExternalSetting(setting) then return true end
    if GetCVarInfo then
        local ok, value, _, _, _, locked, secure, readOnly = pcall(GetCVarInfo, setting.cvar)
        if ok then
            setting.secure = secure == true
            setting.readOnly = locked == true or readOnly == true
            return value ~= nil and not setting.readOnly
        end
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
    if type(AURAVisualUpgradeDB.theme) ~= "string" then
        AURAVisualUpgradeDB.theme = "Warcraft"
    end
    if type(AURAVisualUpgradeDB.optimizer) ~= "table" then
        AURAVisualUpgradeDB.optimizer = {}
    end
    if type(AURAVisualUpgradeRequest) ~= "table" then
        AURAVisualUpgradeRequest = { serial = 0 }
    end

    if AURAVisualUpgradeDB.external.unrestrictedReShade == nil and AURAVisualUpgradeDB.external.staffApproval ~= nil then
        AURAVisualUpgradeDB.external.unrestrictedReShade = AURAVisualUpgradeDB.external.staffApproval and true or false
    end
    AURAVisualUpgradeDB.external.staffApproval = nil
    local defaults = {
        externalSyncEnabled = false, renderer = "DX12", reshade = "Balanced", reshadeMXAO = true, reshadeBounce = true,
        reshadeBloom = true, reshadeColor = true, reshadeSharpen = true,
        frameGeneration = false, unrestrictedReShade = false
    }
    for key, value in pairs(defaults) do
        if AURAVisualUpgradeDB.external[key] == nil then
            AURAVisualUpgradeDB.external[key] = value
        end
    end

    local optimizer = AURAVisualUpgradeDB.optimizer
    optimizer.enabled = false
    if type(optimizer.targetFPS) ~= "number" then optimizer.targetFPS = 60 end
    if type(optimizer.goal) ~= "string" or not self.OPTIMIZER_RULES[optimizer.goal] then optimizer.goal = "Balanced" end
    if type(optimizer.snapshot) ~= "table" then optimizer.snapshot = {} end
    if type(optimizer.expected) ~= "table" then optimizer.expected = {} end
    if type(optimizer.changes) ~= "table" then optimizer.changes = {} end
    if type(optimizer.lastBenchmark) ~= "table" then optimizer.lastBenchmark = {} end
    if optimizer.lastBenchmark.average ~= nil and (type(optimizer.lastBenchmark.average) ~= "number"
        or type(optimizer.lastBenchmark.low) ~= "number" or type(optimizer.lastBenchmark.target) ~= "number"
        or type(optimizer.lastBenchmark.context) ~= "string") then optimizer.lastBenchmark = {} end
    self.optimizer = optimizer
    self.optimizerSamples = {}
    self.backgroundCapSamples = {}
    self.optimizerSkipped = {}
    self.optimizerPendingEvaluation = nil
    if type(AURAVisualUpgradeDB.outstandingNotices) ~= "table" then
        AURAVisualUpgradeDB.outstandingNotices = { gx = false, relog = false, client = false }
    end
    self.outstandingNotices = AURAVisualUpgradeDB.outstandingNotices
    for _, key in ipairs({ "gx", "relog", "client" }) do
        if type(self.outstandingNotices[key]) ~= "boolean" then self.outstandingNotices[key] = false end
    end
end

function AURA:RefreshPendingLiveValues()
    if next(self.manuallyStaged) then return end
    for _, setting in ipairs(self.supportedSettings) do
        if self:IsExternalSetting(setting) then
            self.pending[setting.id] = AURAVisualUpgradeDB.external[setting.id]
        else
            local current = self:ReadCVar(setting.cvar)
            if current ~= nil then
                if setting.type == "toggle" then self.pending[setting.id] = current == "1"
                elseif setting.type == "slider" then self.pending[setting.id] = tonumber(current) or self.pending[setting.id]
                else self.pending[setting.id] = current end
            end
        end
    end
    self.stagedProfile = AURAVisualUpgradeDB.lastProfile
end

function AURA:GetOutstandingNoticeText()
    local notices = {}
    if self.outstandingNotices.gx then table.insert(notices, "graphics restart") end
    if self.outstandingNotices.relog then table.insert(notices, "relog") end
    if self.outstandingNotices.client then table.insert(notices, "client restart/external sync") end
    return #notices > 0 and (" Pending: " .. table.concat(notices, ", ") .. ".") or ""
end

function AURA:AcknowledgeOutstandingNotices()
    self.outstandingNotices.gx = false
    self.outstandingNotices.relog = false
    self.outstandingNotices.client = false
    self:UpdateFooter("Pending restart notices acknowledged.", 0.75, 0.8, 0.88)
end

function AURA:LoadPendingValues()
    wipe(self.pending)
    wipe(self.manuallyStaged)
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

function AURA:PrepareManualStaging()
    if self.analysis then
        self.analysis = nil
        if self.RefreshUpdateDriver then self:RefreshUpdateDriver() end
    end
    if self.optimizer and self.optimizer.enabled then
        if not self:PauseOptimizer(true) then return false end
        self.optimizer.lastAction = "Paused for manual staged changes."
    end
    return true
end

function AURA:SetPending(id, value)
    if ValuesEqual(self.pending[id], value) then return end
    if not self:PrepareManualStaging() then return end
    self.pending[id] = value
    self.manuallyStaged[id] = true
    self.stagedProfile = "Custom"
    if id == "reshade" then
        local enabled = value ~= "Off"
        self.pending.reshadeMXAO = enabled
        self.pending.reshadeBounce = enabled
        self.pending.reshadeBloom = enabled
        self.pending.reshadeColor = enabled
        self.pending.reshadeSharpen = enabled
        for _, childID in ipairs({ "reshadeMXAO", "reshadeBounce", "reshadeBloom", "reshadeColor", "reshadeSharpen" }) do
            self.manuallyStaged[childID] = true
            if self.RefreshRow and self.settingByID[childID] then self:RefreshRow(self.settingByID[childID]) end
        end
    end
    if self.RefreshRow and self.settingByID[id] then self:RefreshRow(self.settingByID[id]) end
    if id == "frameGeneration" and self.RefreshRow and self.settingByID.maxFPS then self:RefreshRow(self.settingByID.maxFPS) end
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
    if not self:PrepareManualStaging() then return end
    for id, value in pairs(profile) do
        if self.settingByID[id] then
            self.pending[id] = value
            self.manuallyStaged[id] = true
        end
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

function AURA:CalculatePerformanceStats(samples, limit)
    if type(samples) ~= "table" or #samples == 0 then return 0, 0 end
    local first = math.max(1, #samples - (tonumber(limit) or #samples) + 1)
    local total, sorted = 0, {}
    for index = first, #samples do
        total = total + samples[index]
        table.insert(sorted, samples[index])
    end
    table.sort(sorted)
    local lowIndex = math.max(1, math.floor(#sorted * 0.10))
    return total / #sorted, sorted[lowIndex]
end

function AURA:GetOptimizerContext()
    if IsInInstance then
        local ok, inInstance, instanceType = pcall(IsInInstance)
        if ok and inInstance then
            if instanceType == "arena" then return "Arena" end
            if instanceType == "pvp" then return "Battleground" end
            if instanceType == "raid" then return "Raid" end
            if instanceType == "party" then return "Dungeon" end
            return "Instance"
        end
    end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then return "Raid" end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then return "Group" end
    return "Open World"
end

function AURA:GetEffectiveTargetFPS()
    local target = math.max(15, self.optimizer and tonumber(self.optimizer.targetFPS) or 60)
    local cap = tonumber(self:ReadCVar("maxFPS"))
    if cap and cap > 0 then target = math.min(target, cap) end
    if tostring(self:ReadCVar("gxVSync")) == "1" then
        local refreshText = tostring(self:ReadCVar("gxRefresh") or "")
        local refresh = tonumber(refreshText) or tonumber(string.match(refreshText, "(%d+)"))
        if refresh and refresh > 0 then target = math.min(target, refresh) end
    end
    return math.max(1, math.floor(target + 0.001))
end

function AURA:IsWorldStable()
    return self.worldReadyAt and (not GetTime or GetTime() >= self.worldReadyAt)
end

function AURA:IsOptimizerSampleUsable(fps)
    local backgroundCap = tonumber(self:ReadCVar("maxFPSBk"))
    if backgroundCap and backgroundCap > 0 and fps >= backgroundCap * 0.97 and fps <= backgroundCap * 1.03 then
        if self.backgroundCapDetected then return false, "background" end
        table.insert(self.backgroundCapSamples, fps)
        if #self.backgroundCapSamples >= 8 then
            local minimum, maximum = self.backgroundCapSamples[1], self.backgroundCapSamples[1]
            for _, sample in ipairs(self.backgroundCapSamples) do
                minimum, maximum = math.min(minimum, sample), math.max(maximum, sample)
            end
            wipe(self.backgroundCapSamples)
            if maximum - minimum <= math.max(1, backgroundCap * 0.02) then
                self.backgroundCapDetected = true
                return false, "background"
            end
            return true, "usable"
        end
        return false, "provisional"
    else
        wipe(self.backgroundCapSamples)
        self.backgroundCapDetected = false
    end
    return true, "usable"
end

function AURA:CycleOptimizerTarget(direction)
    if self.analysis then
        self.analysis = nil
        self:UpdateFooter("Benchmark cancelled because the target changed.", 1, 0.65, 0.3)
        if self.RefreshUpdateDriver then self:RefreshUpdateDriver() end
    end
    if self.optimizerPendingEvaluation and not self:CancelPendingOptimizerEvaluation("Reverted the test change because the target changed.", false) then return end
    local current = tonumber(self.optimizer.targetFPS) or 60
    local index = 1
    for candidateIndex, value in ipairs(self.OPTIMIZER_TARGETS) do
        if value == current then index = candidateIndex break end
    end
    index = index + (direction or 1)
    if index > #self.OPTIMIZER_TARGETS then index = 1 end
    if index < 1 then index = #self.OPTIMIZER_TARGETS end
    self.optimizer.targetFPS = self.OPTIMIZER_TARGETS[index]
    self:ResetOptimizerTelemetry()
    if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
end

function AURA:CycleOptimizerGoal(direction)
    if self.optimizerPendingEvaluation and not self:CancelPendingOptimizerEvaluation("Reverted the test change because the goal changed.", false) then return end
    local index = 1
    for candidateIndex, value in ipairs(self.OPTIMIZER_GOALS) do
        if value == self.optimizer.goal then index = candidateIndex break end
    end
    index = index + (direction or 1)
    if index > #self.OPTIMIZER_GOALS then index = 1 end
    if index < 1 then index = #self.OPTIMIZER_GOALS end
    self.optimizer.goal = self.OPTIMIZER_GOALS[index]
    self:ResetOptimizerTelemetry()
    if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
end

function AURA:ValidateOptimizerState()
    local optimizer = self.optimizer
    self.adaptiveSettingByID = {}
    for _, step in ipairs(self.ADAPTIVE_STEPS) do self.adaptiveSettingByID[step.id] = step end

    local validTarget = false
    for _, target in ipairs(self.OPTIMIZER_TARGETS) do
        if target == optimizer.targetFPS then validTarget = true break end
    end
    if not validTarget then optimizer.targetFPS = 60 end

    local previousSchema = optimizer.schemaVersion
    local sourceSnapshot = CopyTable(optimizer.snapshot)
    local validChanges, owned = {}, {}
    for _, change in ipairs(optimizer.changes) do
        if #validChanges >= 64 then break end
        if type(change) == "table" and self.adaptiveSettingByID[change.id]
            and (type(change.from) == "string" or type(change.from) == "number")
            and (type(change.to) == "string" or type(change.to) == "number") then
            table.insert(validChanges, change)
            owned[change.id] = true
        end
    end

    wipe(optimizer.snapshot)
    wipe(optimizer.expected)
    wipe(optimizer.changes)
    for _, change in ipairs(validChanges) do
        local baseline = sourceSnapshot[change.id]
        if owned[change.id] and self.settingByID[change.id]
            and (type(baseline) == "string" or type(baseline) == "number") then
            if optimizer.snapshot[change.id] == nil then optimizer.snapshot[change.id] = baseline end
            optimizer.expected[change.id] = change.to
            table.insert(optimizer.changes, change)
        end
    end

    optimizer.sessionActive = optimizer.sessionActive == true or #optimizer.changes > 0
    optimizer.blocked = type(optimizer.blocked) == "string" and optimizer.blocked or nil
    if previousSchema ~= self.OPTIMIZER_SCHEMA and #optimizer.changes > 0 then
        optimizer.blocked = "A previous optimizer state requires Restore Baseline before reuse."
    end
    if #optimizer.changes == 0 then optimizer.blocked = nil end
    optimizer.schemaVersion = self.OPTIMIZER_SCHEMA
    optimizer.enabled = false
    if #optimizer.changes > 0 then optimizer.lastAction = "Previous adaptive session loaded paused." end
end

function AURA:ResetOptimizerTelemetry(keepPendingEvaluation)
    wipe(self.optimizerSamples)
    self.optimizerSampleElapsed = 0
    self.optimizerEvaluateElapsed = 0
    self.optimizerUnderSeconds = 0
    self.optimizerOverSeconds = 0
    self.optimizerAverage = 0
    self.optimizerLow = 0
    self.optimizerNewSamples = 0
    self.optimizerInvalidSeconds = 0
    self.optimizerLastChangeAt = GetTime and GetTime() or 0
    self.optimizerSampleContext = self:GetOptimizerContext()
    self.optimizerEffectiveTargetFPS = self:GetEffectiveTargetFPS()
    self.optimizerIgnoredSeconds = 0
    self.backgroundCapSamples = self.backgroundCapSamples or {}
    wipe(self.backgroundCapSamples)
    self.backgroundCapDetected = false
    if not keepPendingEvaluation then self.optimizerPendingEvaluation = nil end
end

function AURA:ClearOptimizerSession(message)
    self.optimizer.enabled = false
    wipe(self.optimizer.snapshot)
    wipe(self.optimizer.expected)
    wipe(self.optimizer.changes)
    wipe(self.optimizerSkipped)
    self.optimizer.schemaVersion = self.OPTIMIZER_SCHEMA
    self.optimizer.sessionActive = false
    self.optimizer.blocked = nil
    self:ResetOptimizerTelemetry()
    self.optimizer.lastAction = message or "Adaptive session cleared."
    if self.RefreshUpdateDriver then self:RefreshUpdateDriver() end
end

function AURA:RemoveOptimizerOwnership(id)
    self.optimizer.snapshot[id] = nil
    self.optimizer.expected[id] = nil
    self.optimizerSkipped[id] = nil
    local remaining = {}
    for _, change in ipairs(self.optimizer.changes) do
        if change.id ~= id then table.insert(remaining, change) end
    end
    wipe(self.optimizer.changes)
    for _, change in ipairs(remaining) do table.insert(self.optimizer.changes, change) end
    if self.optimizerPendingEvaluation and self.optimizerPendingEvaluation.id == id then self.optimizerPendingEvaluation = nil end
end

function AURA:GetLastOptimizerChange(id)
    for index = #self.optimizer.changes, 1, -1 do
        if self.optimizer.changes[index].id == id then return self.optimizer.changes[index] end
    end
    return nil
end

function AURA:ReconcileOptimizerOwnership()
    local relinquished = {}
    for id in pairs(self.optimizer.snapshot) do
        local setting = self.settingByID[id]
        local current = setting and self:ReadCVar(setting.cvar)
        if not setting then
            table.insert(relinquished, id)
        elseif current == nil then
            self.optimizer.blocked = setting.label .. " could not be read. Retry after the client is stable."
            return false
        elseif not ValuesEqual(current, self.optimizer.expected[id]) then
            table.insert(relinquished, id)
            if setting.type == "slider" then self.pending[id] = tonumber(current) else self.pending[id] = tostring(current) end
        end
    end
    for _, id in ipairs(relinquished) do self:RemoveOptimizerOwnership(id) end
    return true
end

function AURA:RelinquishOptimizerState()
    for id in pairs(self.optimizer.snapshot) do
        local setting = self.settingByID[id]
        local current = setting and self:ReadCVar(setting.cvar)
        if setting and current ~= nil and not self.manuallyStaged[id] then
            if setting.type == "slider" then self.pending[id] = tonumber(current) else self.pending[id] = tostring(current) end
        end
    end
    self:ClearOptimizerSession("Relinquished all remaining adaptive ownership without changing game settings.")
    if self.RefreshAllRows then self:RefreshAllRows() end
    self:UpdateFooter(self.optimizer.lastAction, 0.95, 0.78, 0.32)
    if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
end

function AURA:TransferOptimizerOwnership(ids)
    if not next(ids) then return end
    for id in pairs(ids) do self:RemoveOptimizerOwnership(id) end
    if #self.optimizer.changes == 0 then
        self:ClearOptimizerSession("Manual settings are now the baseline for the next adaptive session.")
    else
        self.optimizer.enabled = false
        self:ResetOptimizerTelemetry()
        self.optimizer.lastAction = "Manual settings were adopted; other adaptive changes remain restorable."
    end
end

function AURA:StartOptimizer()
    if self.analysis then
        self:UpdateFooter("Finish or cancel the benchmark before starting Adaptive Optimization.", 1, 0.65, 0.3)
        return
    end
    if not self:IsWorldStable() then
        self:UpdateFooter("Wait for the world to finish loading before starting Adaptive Optimization.", 1, 0.65, 0.3)
        return
    end
    if next(self.manuallyStaged) then
        self:UpdateFooter("Apply or reset staged settings before starting Adaptive Optimization.", 1, 0.65, 0.3)
        return
    end
    if self.optimizer.blocked then
        self:UpdateFooter(self.optimizer.blocked, 1, 0.35, 0.35)
        return
    end
    if not self:ReconcileOptimizerOwnership() then
        self:UpdateFooter(self.optimizer.blocked, 1, 0.35, 0.35)
        return
    end
    local supported = false
    for _, step in ipairs(self.ADAPTIVE_STEPS) do
        if self.settingByID[step.id] then supported = true break end
    end
    if not supported then
        self:UpdateFooter("No supported immediate optimization controls were found.", 1, 0.35, 0.35)
        return
    end
    if not self.optimizer.sessionActive then
        wipe(self.optimizer.snapshot)
        wipe(self.optimizer.expected)
        wipe(self.optimizer.changes)
        wipe(self.optimizerSkipped)
        self.optimizer.sessionActive = true
    end
    self.optimizer.enabled = true
    self.optimizer.lastAction = "Warming up before the first evaluation."
    self:ResetOptimizerTelemetry()
    self:UpdateFooter(string.format("Adaptive Optimization enabled at a %d FPS target.", self:GetEffectiveTargetFPS()), 0.4, 1, 0.55)
    if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
    if self.RefreshUpdateDriver then self:RefreshUpdateDriver() end
end

function AURA:PauseOptimizer(silent)
    if self.optimizerPendingEvaluation and not self:CancelPendingOptimizerEvaluation("Reverted the unfinished test change before pausing.", false) then
        if not silent then self:UpdateFooter("Adaptive Optimization paused, but its test change could not be reverted.", 1, 0.35, 0.35) end
        if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
        return false
    end
    self.optimizer.enabled = false
    self.optimizer.lastAction = "Paused; adaptive changes remain active until restored."
    if not silent then self:UpdateFooter("Adaptive Optimization paused. Current changes remain active.", 0.95, 0.78, 0.32) end
    if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
    if self.RefreshUpdateDriver then self:RefreshUpdateDriver() end
    return true
end

function AURA:RestoreOptimizerBaseline()
    if next(self.manuallyStaged) then
        self:UpdateFooter("Apply or reset staged settings before restoring the adaptive baseline.", 1, 0.65, 0.3)
        return
    end
    local restored, relinquished, failed = 0, 0, 0
    self.analysis = nil
    self.optimizer.enabled = false
    self.optimizerPendingEvaluation = nil
    local completedIDs = {}
    for id, value in pairs(self.optimizer.snapshot) do
        local setting = self.settingByID[id]
        local current = setting and self:ReadCVar(setting.cvar)
        local expected = self.optimizer.expected[id]
        if not setting then
            relinquished = relinquished + 1
            table.insert(completedIDs, id)
        elseif current == nil then
            failed = failed + 1
        elseif expected == nil or not ValuesEqual(current, expected) then
            relinquished = relinquished + 1
            table.insert(completedIDs, id)
            if setting.type == "slider" then self.pending[id] = tonumber(current) else self.pending[id] = tostring(current) end
        elseif setting.secure and InCombatLockdown and InCombatLockdown() then
            failed = failed + 1
        elseif self:WriteCVar(setting.cvar, value) then
            restored = restored + 1
            table.insert(completedIDs, id)
            if setting.type == "slider" then self.pending[id] = tonumber(value) else self.pending[id] = tostring(value) end
        else
            failed = failed + 1
        end
    end
    for _, id in ipairs(completedIDs) do self:RemoveOptimizerOwnership(id) end
    if not next(self.optimizer.snapshot) then
        self:ClearOptimizerSession()
    else
        self.optimizer.blocked = "Some adaptive settings could not be restored; retry Restore Baseline out of combat."
        self:ResetOptimizerTelemetry()
    end
    self.optimizer.lastAction = string.format("Restored %d setting%s; relinquished %d externally changed setting%s.", restored, restored == 1 and "" or "s", relinquished, relinquished == 1 and "" or "s")
    if self.RefreshAllRows then self:RefreshAllRows() end
    if failed > 0 then
        self:UpdateFooter(string.format("Could not restore %d setting%s; retained for retry.", failed, failed == 1 and "" or "s"), 1, 0.65, 0.3)
    else
        self:UpdateFooter(self.optimizer.lastAction, 0.4, 1, 0.55)
    end
    if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
    if self.RefreshUpdateDriver then self:RefreshUpdateDriver() end
end

function AURA:ReduceOneOptimizerSetting(average, low, context)
    for _, step in ipairs(self.ADAPTIVE_STEPS) do
        local setting = self.settingByID[step.id]
        if setting and setting.apply == "Immediate" and not self.optimizerSkipped[step.id]
            and not (setting.secure and InCombatLockdown and InCombatLockdown()) then
            local current = self:ReadCVar(setting.cvar)
            local expected = self.optimizer.expected[step.id]
            if expected ~= nil and not ValuesEqual(current, expected) then
                self.optimizer.enabled = false
                self.optimizer.blocked = setting.label .. " changed outside the optimizer. Use Restore Baseline to resolve the session."
                self.optimizer.lastAction = self.optimizer.blocked
                return nil
            end
            local minimum = step.minByContext and step.minByContext[context]
            local nextValue = current ~= nil and FindNextLowerValue(step.values, current, minimum)
            if nextValue ~= nil then
                if #self.optimizer.changes >= 64 then
                    self.optimizer.enabled = false
                    self.optimizer.blocked = "Adaptive change history reached its safety limit. Use Restore Baseline."
                    self.optimizer.lastAction = self.optimizer.blocked
                    return nil
                end
                if self:WriteCVar(setting.cvar, nextValue) then
                    if self.optimizer.snapshot[step.id] == nil then self.optimizer.snapshot[step.id] = current end
                    self.optimizer.expected[step.id] = tostring(nextValue)
                    table.insert(self.optimizer.changes, { id = step.id, from = current, to = tostring(nextValue), changedAt = time and time() or 0 })
                    if setting.type == "slider" then self.pending[step.id] = tonumber(nextValue) else self.pending[step.id] = tostring(nextValue) end
                    self.optimizerPendingEvaluation = {
                        id = step.id, from = current, to = tostring(nextValue),
                        beforeAverage = average, beforeLow = low, context = context
                    }
                    self.optimizer.lastAction = "Testing a lower " .. setting.label .. " setting."
                    if self.RefreshRow then self:RefreshRow(setting) end
                    return setting.label
                else
                    self.optimizerSkipped[step.id] = true
                end
            end
        end
    end
    return nil
end

function AURA:RecoverOneOptimizerSetting()
    local change = self.optimizer.changes[#self.optimizer.changes]
    if not change then return nil end
    local setting = self.settingByID[change.id]
    local current = setting and self:ReadCVar(setting.cvar)
    if setting and current == nil then
        self.optimizer.enabled = false
        self.optimizer.blocked = setting.label .. " could not be read. Use Restore Baseline to retry safely."
        self.optimizer.lastAction = self.optimizer.blocked
        return nil
    end
    if setting and not ValuesEqual(current, self.optimizer.expected[change.id] or change.to) then
        self:RemoveOptimizerOwnership(change.id)
        self.optimizer.enabled = false
        self.optimizer.blocked = setting.label .. " changed outside the optimizer. Use Restore Baseline to resolve remaining changes."
        self.optimizer.lastAction = self.optimizer.blocked
        return nil
    end
    if setting and setting.secure and InCombatLockdown and InCombatLockdown() then return nil end
    if setting and self:WriteCVar(setting.cvar, change.from) then
        table.remove(self.optimizer.changes)
        local previous = self:GetLastOptimizerChange(change.id)
        if previous then
            self.optimizer.expected[change.id] = previous.to
        else
            self.optimizer.snapshot[change.id] = nil
            self.optimizer.expected[change.id] = nil
        end
        if setting.type == "slider" then self.pending[change.id] = tonumber(change.from) else self.pending[change.id] = tostring(change.from) end
        self.optimizer.lastAction = "Restored " .. setting.label .. " after sustained frame stability."
        if self.RefreshRow then self:RefreshRow(setting) end
        return setting.label
    end
    self.optimizer.enabled = false
    self.optimizer.blocked = "A quality recovery write failed. Use Restore Baseline before resuming."
    self.optimizer.lastAction = self.optimizer.blocked
    return nil
end

function AURA:CancelPendingOptimizerEvaluation(reason, skipStep)
    local pending = self.optimizerPendingEvaluation
    if not pending then return true end
    local setting = self.settingByID[pending.id]
    if setting and setting.secure and InCombatLockdown and InCombatLockdown() then
        self.optimizer.enabled = false
        self.optimizer.blocked = "Waiting to revert a protected test change after combat."
        self.optimizer.lastAction = self.optimizer.blocked
        return false
    end
    local current = setting and self:ReadCVar(setting.cvar)
    if setting and current == nil then
        self.optimizer.enabled = false
        self.optimizer.blocked = setting.label .. " could not be read. Use Restore Baseline to retry safely."
        self.optimizer.lastAction = self.optimizer.blocked
        return false
    end
    if setting and not ValuesEqual(current, pending.to) then
        self:RemoveOptimizerOwnership(pending.id)
        self.optimizer.enabled = false
        self.optimizer.blocked = setting.label .. " changed outside the optimizer. Use Restore Baseline to resolve remaining changes."
        self.optimizer.lastAction = self.optimizer.blocked
        return false
    end
    if not setting or not self:WriteCVar(setting.cvar, pending.from) then
        self.optimizer.enabled = false
        self.optimizer.blocked = "A test change could not be reverted. Use Restore Baseline before resuming."
        self.optimizer.lastAction = self.optimizer.blocked
        return false
    end
    local last = self.optimizer.changes[#self.optimizer.changes]
    if last and last.id == pending.id and ValuesEqual(last.to, pending.to) then table.remove(self.optimizer.changes) end
    local previous = self:GetLastOptimizerChange(pending.id)
    if previous then
        self.optimizer.expected[pending.id] = previous.to
    else
        self.optimizer.snapshot[pending.id] = nil
        self.optimizer.expected[pending.id] = nil
    end
    if skipStep ~= false then self.optimizerSkipped[pending.id] = true end
    if setting.type == "slider" then self.pending[pending.id] = tonumber(pending.from) else self.pending[pending.id] = tostring(pending.from) end
    if self.RefreshRow then self:RefreshRow(setting) end
    self.optimizerPendingEvaluation = nil
    self.optimizer.lastAction = reason or ("Reverted " .. setting.label .. "; no measurable benefit was found.")
    return true
end

function AURA:EvaluatePendingOptimizerChange(average, low)
    local pending = self.optimizerPendingEvaluation
    if not pending then return false end
    local setting = self.settingByID[pending.id]
    local current = setting and self:ReadCVar(setting.cvar)
    if setting and current == nil then
        self.optimizer.enabled = false
        self.optimizer.blocked = setting.label .. " could not be read. Use Restore Baseline to retry safely."
        self.optimizer.lastAction = self.optimizer.blocked
        return true
    end
    if not setting or not ValuesEqual(current, pending.to) then
        if setting then self:RemoveOptimizerOwnership(pending.id) end
        self.optimizer.enabled = false
        self.optimizer.blocked = "The tested setting changed outside the optimizer. Use Restore Baseline to resolve remaining changes."
        self.optimizer.lastAction = self.optimizer.blocked
        return true
    end
    local target = self:GetEffectiveTargetFPS()
    local averageGain = math.max(1, target * 0.02)
    local lowGain = math.max(1, target * 0.025)
    local averageTolerance = math.max(1, target * 0.015)
    local lowTolerance = math.max(1, target * 0.02)
    local improved = (average >= pending.beforeAverage + averageGain and low >= pending.beforeLow - lowTolerance)
        or (low >= pending.beforeLow + lowGain and average >= pending.beforeAverage - averageTolerance)
    if improved then
        self.optimizerPendingEvaluation = nil
        self.optimizer.lastAction = "Kept lower " .. (setting and setting.label or pending.id) .. "; frame stability improved."
    else
        if not self:CancelPendingOptimizerEvaluation() then return true end
    end
    self:ResetOptimizerTelemetry()
    return true
end

function AURA:UpdateOptimizer(elapsed)
    if not self.optimizer or not self.optimizer.enabled then return end
    if not self:IsWorldStable() then return end
    self.optimizerSampleElapsed = (self.optimizerSampleElapsed or 0) + elapsed
    self.optimizerEvaluateElapsed = (self.optimizerEvaluateElapsed or 0) + elapsed
    if self.optimizerSampleElapsed >= 0.25 then
        self.optimizerSampleElapsed = 0
        local context = self:GetOptimizerContext()
        if self.optimizerSampleContext and context ~= self.optimizerSampleContext then
            if not self:CancelPendingOptimizerEvaluation("Reverted the test change because the gameplay context changed.", false) then return end
            self:ResetOptimizerTelemetry()
            return
        end
        local effectiveTarget = self:GetEffectiveTargetFPS()
        if self.optimizerEffectiveTargetFPS and effectiveTarget ~= self.optimizerEffectiveTargetFPS then
            if self.optimizerPendingEvaluation and not self:CancelPendingOptimizerEvaluation("Reverted the test change because the frame ceiling changed.", false) then return end
            self.optimizer.lastAction = "Frame ceiling changed; warming up with fresh samples."
            self:ResetOptimizerTelemetry()
            return
        end
        local fps = GetFramerate and GetFramerate() or 0
        local usable, sampleState = false, nil
        if fps > 0 then usable, sampleState = self:IsOptimizerSampleUsable(fps) end
        if usable then
            self.optimizerIgnoredSeconds = 0
            self.optimizerInvalidSeconds = 0
            self.optimizerNewSamples = (self.optimizerNewSamples or 0) + 1
            table.insert(self.optimizerSamples, fps)
            if #self.optimizerSamples > 80 then table.remove(self.optimizerSamples, 1) end
        elseif fps > 0 and sampleState == "background" then
            self.optimizerIgnoredSeconds = (self.optimizerIgnoredSeconds or 0) + 0.25
            wipe(self.optimizerSamples)
            self.optimizerUnderSeconds, self.optimizerOverSeconds = 0, 0
            self.optimizer.lastAction = "Sampling paused near the background frame cap."
        elseif fps <= 0 then
            self.optimizerInvalidSeconds = (self.optimizerInvalidSeconds or 0) + 0.25
            if self.optimizerInvalidSeconds >= 1 then
                self:ResetOptimizerTelemetry()
                self.optimizer.lastAction = "Frame telemetry was unavailable; warming up again."
                return
            end
        end
    end
    if self.optimizerEvaluateElapsed < 1 then return end
    self.optimizerEvaluateElapsed = 0
    if (self.optimizerNewSamples or 0) == 0 then return end
    self.optimizerNewSamples = 0
    if #self.optimizerSamples < 20 then
        if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
        return
    end

    local average, low = self:CalculatePerformanceStats(self.optimizerSamples)
    self.optimizerAverage, self.optimizerLow = average, low
    if self.optimizerPendingEvaluation then
        if #self.optimizerSamples >= 40 then
            local recentAverage, recentLow = self:CalculatePerformanceStats(self.optimizerSamples, 40)
            self:EvaluatePendingOptimizerChange(recentAverage, recentLow)
        end
        if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
        return
    end
    local target = self:GetEffectiveTargetFPS()
    local rule = self.OPTIMIZER_RULES[self.optimizer.goal] or self.OPTIMIZER_RULES.Balanced
    local context = self.optimizerSampleContext or self:GetOptimizerContext()
    local reduceSeconds = rule.reduceSeconds

    if low < target * rule.reduceRatio then
        self.optimizerUnderSeconds = (self.optimizerUnderSeconds or 0) + 1
    else
        self.optimizerUnderSeconds = 0
    end
    if average >= target * rule.recoverAverageRatio and low >= target * rule.recoverLowRatio then
        self.optimizerOverSeconds = (self.optimizerOverSeconds or 0) + 1
    else
        self.optimizerOverSeconds = 0
    end

    local now = GetTime and GetTime() or 0
    if now - (self.optimizerLastChangeAt or 0) >= 15 then
        if self.optimizerUnderSeconds >= reduceSeconds then
            local recentAverage, recentLow = self:CalculatePerformanceStats(self.optimizerSamples, 40)
            local changed = self:ReduceOneOptimizerSetting(recentAverage, recentLow, context)
            if not changed and self.optimizer.enabled and not self.optimizer.blocked then
                self.optimizer.lastAction = "Minimum adaptive settings reached; no further safe reduction is available."
            end
            if changed then self:ResetOptimizerTelemetry(true) else self.optimizerUnderSeconds, self.optimizerOverSeconds = 0, 0 end
            self.optimizerLastChangeAt = now
        elseif self.optimizerOverSeconds >= rule.recoverSeconds and #self.optimizer.changes > 0 then
            local changed = self:RecoverOneOptimizerSetting()
            if changed then self:ResetOptimizerTelemetry() else self.optimizerUnderSeconds, self.optimizerOverSeconds = 0, 0 end
            self.optimizerLastChangeAt = now
        end
    end
    if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
end

function AURA:StartAnalysis()
    if self.analysis then
        return
    end
    if self.optimizer and (self.optimizer.enabled or self.optimizerPendingEvaluation or self.optimizer.blocked or #self.optimizer.changes > 0) then
        self:UpdateFooter("Pause and restore or relinquish the adaptive session before running a benchmark.", 1, 0.65, 0.3)
        return
    end
    if next(self.manuallyStaged) then
        self:UpdateFooter("Apply or reset staged settings before running a benchmark.", 1, 0.65, 0.3)
        return
    end
    if not self:IsWorldStable() then
        self:UpdateFooter("Wait for the world to finish loading before running a benchmark.", 1, 0.65, 0.3)
        return
    end
    wipe(self.backgroundCapSamples)
    self.backgroundCapDetected = false
    if self.optimizer.sessionActive then self:ClearOptimizerSession("Closed an ownership-free adaptive session for benchmarking.") end
    self.analysis = { samples = {}, sampleElapsed = 0, activeElapsed = 0, wallElapsed = 0, invalidElapsed = 0, context = self:GetOptimizerContext(), target = self:GetEffectiveTargetFPS() }
    self:UpdateFooter("Benchmarking live performance for 15 seconds...", 0.35, 0.85, 1)
    if self.RefreshUpdateDriver then self:RefreshUpdateDriver() end
end

function AURA:UpdateAnalysis(elapsed)
    if not self.analysis then
        return
    end
    local analysis = self.analysis
    analysis.wallElapsed = analysis.wallElapsed + elapsed
    if analysis.wallElapsed >= 45 then
        self.analysis = nil
        self:UpdateFooter("Benchmark cancelled after prolonged loading or background throttling.", 1, 0.65, 0.3)
        return
    end
    if not self:IsWorldStable() then return end
    analysis.sampleElapsed = analysis.sampleElapsed + elapsed
    if analysis.sampleElapsed >= 0.25 then
        analysis.sampleElapsed = 0
        if analysis.context ~= self:GetOptimizerContext() then
            self.analysis = nil
            self:UpdateFooter("Benchmark cancelled because the gameplay context changed.", 1, 0.65, 0.3)
            return
        end
        if analysis.target ~= self:GetEffectiveTargetFPS() then
            self.analysis = nil
            self:UpdateFooter("Benchmark cancelled because the effective frame target changed.", 1, 0.65, 0.3)
            return
        end
        local fps = GetFramerate and GetFramerate() or 0
        local usable, sampleState = false, nil
        if fps > 0 then usable, sampleState = self:IsOptimizerSampleUsable(fps) end
        if usable then
            analysis.invalidElapsed = 0
            table.insert(analysis.samples, fps)
            analysis.activeElapsed = analysis.activeElapsed + 0.25
        elseif fps > 0 and sampleState == "background" then
            wipe(analysis.samples)
            analysis.activeElapsed = 0
            self:UpdateFooter("Benchmark paused near the background frame cap; focus the game or choose a distinct background cap.", 1, 0.65, 0.3)
        elseif sampleState == "provisional" then
            -- Hold cap-adjacent samples until foreground/background classification completes.
        else
            analysis.invalidElapsed = analysis.invalidElapsed + 0.25
            if analysis.invalidElapsed >= 1 then
                wipe(analysis.samples)
                analysis.activeElapsed = 0
            end
        end
    end
    if analysis.activeElapsed < 15 then
        return
    end

    local average, low = self:CalculatePerformanceStats(analysis.samples)
    local target = analysis.target
    local context = self:GetOptimizerContext()
    local profile = average >= target * 0.98 and low >= target * 0.95 and "Quality"
        or (average >= target * 0.90 and low >= target * 0.80 and "Balanced" or "Performance")
    if context == "Raid" and profile ~= "Performance" and low < target then profile = "Raid" end

    self.analysis = nil
    self.optimizer.lastBenchmark = { average = average, low = low, target = target, context = context, completedAt = time and time() or 0 }
    self:StageProfile(profile)
    self:UpdateFooter(string.format("Recommended: %s (%.0f average / %.0f low, %d target, %s).", profile, average, low, target, context), 0.4, 1, 0.55)
    if self.UpdateOptimizerDisplay then self:UpdateOptimizerDisplay() end
end

function AURA:BuildExternalRequest()
    local external = AURAVisualUpgradeDB.external or {}
    AURAVisualUpgradeRequest.serial = (tonumber(AURAVisualUpgradeRequest.serial) or 0) + 1
    AURAVisualUpgradeRequest.version = self.VERSION
    AURAVisualUpgradeRequest.externalRequested = external.externalSyncEnabled and true or false
    AURAVisualUpgradeRequest.renderer = tostring(external.renderer or "DX12")
    AURAVisualUpgradeRequest.reshade = tostring(external.reshade or "Off")
    AURAVisualUpgradeRequest.reshadeMXAO = external.reshadeMXAO and true or false
    AURAVisualUpgradeRequest.reshadeBounce = external.reshadeBounce and true or false
    AURAVisualUpgradeRequest.reshadeBloom = external.reshadeBloom and true or false
    AURAVisualUpgradeRequest.reshadeColor = external.reshadeColor and true or false
    AURAVisualUpgradeRequest.reshadeSharpen = external.reshadeSharpen and true or false
    AURAVisualUpgradeRequest.frameGeneration = external.frameGeneration and true or false
    AURAVisualUpgradeRequest.unrestrictedReShade = external.unrestrictedReShade and true or false
    AURAVisualUpgradeRequest.staffApproval = nil
    AURAVisualUpgradeRequest.baseFrameCap = tonumber(self:ReadCVar("maxFPS")) or 0
    AURAVisualUpgradeRequest.profile = AURAVisualUpgradeDB.lastProfile or "Custom"
    AURAVisualUpgradeRequest.updatedAt = time and time() or 0
    AURAVisualUpgradeRequest.pending = AURAVisualUpgradeRequest.externalRequested
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

    if not next(self.manuallyStaged) then
        self:UpdateFooter("No staged changes to apply.", 0.75, 0.8, 0.88)
        return
    end
    self.analysis = nil
    local optimizerWasEnabled = self.optimizer and self.optimizer.enabled
    if optimizerWasEnabled and not self:PauseOptimizer(true) then
        self:UpdateFooter("Apply stopped because the optimizer test change could not be reverted.", 1, 0.35, 0.35)
        return
    end
    local needsGxRestart, needsRelog, needsClientRestart, externalChanged = false, false, false, false
    local optimizerOwnership, appliedIDs, failed = {}, {}, {}
    for _, setting in ipairs(self.supportedSettings) do
        if self.manuallyStaged[setting.id] then
            local value = self.pending[setting.id]
            if self:IsExternalSetting(setting) then
                if AURAVisualUpgradeDB.external[setting.id] ~= value then externalChanged = true end
                AURAVisualUpgradeDB.external[setting.id] = value
                appliedIDs[setting.id] = true
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
                if not self:WriteCVar(setting.cvar, writeValue, setting.deferredReadback) then
                    table.insert(failed, setting.label)
                else
                    appliedIDs[setting.id] = true
                    if self.adaptiveSettingByID and self.adaptiveSettingByID[setting.id] then optimizerOwnership[setting.id] = true end
                    if setting.apply == "Graphics restart" then
                        needsGxRestart = true
                    elseif setting.apply == "Relog" then
                        needsRelog = true
                    elseif setting.apply == "Client restart" then
                        needsClientRestart = true
                    end
                end
            else
                appliedIDs[setting.id] = true
                if self.adaptiveSettingByID and self.adaptiveSettingByID[setting.id] then optimizerOwnership[setting.id] = true end
            end
        end
        end
    end

    for id in pairs(appliedIDs) do self.manuallyStaged[id] = nil end
    if externalChanged and AURAVisualUpgradeDB.external.externalSyncEnabled then needsClientRestart = true end
    if #failed == 0 and not next(self.manuallyStaged) then
        AURAVisualUpgradeDB.lastProfile = self.stagedProfile or "Custom"
    else
        self.stagedProfile = "Custom"
        if self.UpdateProfileDisplay then self:UpdateProfileDisplay("Custom") end
    end
    self:BuildExternalRequest()
    self:TransferOptimizerOwnership(optimizerOwnership)

    if needsGxRestart then self.outstandingNotices.gx = true end
    if needsRelog then self.outstandingNotices.relog = true end
    if needsClientRestart then self.outstandingNotices.client = true end
    local suffix = ""
    if optimizerWasEnabled then suffix = suffix .. " Adaptive Optimization was paused for manual changes." end
    if #failed > 0 then
        self:UpdateFooter("Partially applied. Failed: " .. table.concat(failed, ", ") .. "." .. suffix, 1, 0.45, 0.3)
    else
        self:UpdateFooter("Game settings applied." .. suffix, 0.4, 1, 0.55)
    end

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
    OnAccept = function()
        AURA.outstandingNotices.gx = false
        RestartGx()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3
}

StaticPopupDialogs["AURA_VISUAL_RELINQUISH"] = {
    text = "Relinquish all remaining adaptive ownership without changing current game settings? You will no longer be able to restore those values through this session.",
    button1 = "Relinquish",
    button2 = "Cancel",
    OnAccept = function() AURA:RelinquishOptimizerState() end,
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
        self:RegisterEvent("PLAYER_LEAVING_WORLD")
        self:RegisterEvent("PARTY_MEMBERS_CHANGED")
        self:RegisterEvent("RAID_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_GUILD_UPDATE")
        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("UI_SCALE_CHANGED")
        self:RegisterEvent("DISPLAY_SIZE_CHANGED")
        AURA:InitializeDatabase()
        AURA:LoadPendingValues()
        AURA:ValidateOptimizerState()
        AURA:InitializePeerProtocol()
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        AURA:CreateUI()
        AURA:Print("Loaded. Type |cffffffff/auravis|r or click the AV minimap button.")
    elseif event == "CHAT_MSG_ADDON" then
        AURA:HandlePeerMessage(...)
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        if AURA.UpdateWindowScale then AURA:UpdateWindowScale() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if AURA.optimizerPendingEvaluation and AURA.optimizer and AURA.optimizer.blocked == "Waiting to revert a protected test change after combat." then
            AURA.optimizer.blocked = nil
            if AURA:CancelPendingOptimizerEvaluation("Reverted the protected test change after combat.", false) then
                AURA:UpdateFooter(AURA.optimizer.lastAction, 0.95, 0.78, 0.32)
            end
            if AURA.UpdateOptimizerDisplay then AURA:UpdateOptimizerDisplay() end
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        AURA.worldReadyAt = nil
        if AURA.analysis then
            AURA.analysis = nil
            AURA:UpdateFooter("Benchmark cancelled because the world changed.", 1, 0.65, 0.3)
        end
        if AURA.optimizerPendingEvaluation then AURA:CancelPendingOptimizerEvaluation("Reverted the test change before leaving the world.", false) end
        if AURA.optimizer then AURA:ResetOptimizerTelemetry() end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        if event == "PLAYER_ENTERING_WORLD" then
            AURA.worldReadyAt = (GetTime and GetTime() or 0) + 10
            if AURA.optimizer then AURA:ResetOptimizerTelemetry() end
        end
        if not AURA.peerAnnouncementSent and not AURA.peerAnnouncementScheduled then
            AURA.peerAnnouncementScheduled = true
            AURA.peerAnnouncementDelay = event == "PLAYER_ENTERING_WORLD" and 8 or 2
            if AURA.RefreshUpdateDriver then AURA:RefreshUpdateDriver() end
        end
    end
end)

local function UpdateDriver(_, elapsed)
    AURA:UpdateAnalysis(elapsed)
    AURA:UpdateOptimizer(elapsed)
    if AURA.peerAnnouncementDelay then
        AURA.peerAnnouncementDelay = AURA.peerAnnouncementDelay - elapsed
        if AURA.peerAnnouncementDelay <= 0 then
            AURA.peerAnnouncementDelay = nil
            AURA.peerAnnouncementScheduled = false
            AURA:AnnouncePeerVersion()
        end
    end
    if AURA.UpdateDashboard and AURA.frame and AURA.frame:IsShown() then
        AURA.dashboardElapsed = (AURA.dashboardElapsed or 0) + elapsed
        if AURA.dashboardElapsed >= 1 then
            AURA.dashboardElapsed = 0
            AURA:UpdateDashboard()
            if AURA.optimizerPanel and AURA.optimizerPanel:IsShown() then AURA:UpdateOptimizerDisplay() end
        end
    end
    if not AURA:NeedsUpdateDriver() then eventFrame:SetScript("OnUpdate", nil) end
end

function AURA:NeedsUpdateDriver()
    return self.analysis ~= nil
        or (self.optimizer and self.optimizer.enabled)
        or self.peerAnnouncementDelay ~= nil
        or (self.frame and self.frame:IsShown())
end

function AURA:RefreshUpdateDriver()
    eventFrame:SetScript("OnUpdate", self:NeedsUpdateDriver() and UpdateDriver or nil)
end

SLASH_AURAVIS1 = "/auravis"
SlashCmdList.AURAVIS = function(message)
    local command = string.lower(string.match(tostring(message or ""), "^%s*(.-)%s*$"))
    if command == "update" then
        if AURA.Show then AURA:Show() end
        if AURA.ShowUpdatePanel then AURA:ShowUpdatePanel() end
        AURA:CheckPeerVersions()
    elseif command == "optimize" or command == "optimizer" then
        if AURA.Show then AURA:Show() end
        if AURA.ShowOptimizerPanel then AURA:ShowOptimizerPanel() end
    elseif command == "benchmark" then
        if AURA.Show then AURA:Show() end
        if AURA.ShowOptimizerPanel then AURA:ShowOptimizerPanel() end
        AURA:StartAnalysis()
    elseif command == "acknowledge" or command == "ack" then
        AURA:AcknowledgeOutstandingNotices()
    elseif AURA.Toggle then
        AURA:Toggle()
    end
end
