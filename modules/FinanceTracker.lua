local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local date = _G.date
local GetMoney = _G.GetMoney
local GetMoneyString = _G.GetMoneyString
local GetAchievementCriteriaInfo = _G.GetAchievementCriteriaInfo
local LibStub = _G.LibStub
local math_abs = _G.math.abs
local tonumber = _G.tonumber
local UnitExists = _G.UnitExists
local type = _G.type
local string = _G.string
local ipairs = _G.ipairs
local pairs = _G.pairs
--GLOBALS>

local mod = addon:NewModule('FinanceTracker', 'AceEvent-3.0')
mod.uiName = L['Financial Tracker'] or "Financial Tracker"
mod.uiDesc = L['Tracks gold earned and spent per session, day, week, and month.'] or "Tracks gold earned and spent per session, day, week, and month."

mod.trackedStats = {
	quests   = { id = 3355, label = L["Quests"] },
	looted   = { id = 3354, label = L["Looted"] },
	vendor   = { id = 3361, label = L["Vendors"] },
	taxi     = { id = 3356, label = L["Travel"] },
}

-----------------------------------------------------------
-- Initialization and Options
-----------------------------------------------------------

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace('FinanceTracker', {
		char = {
			lastMoney = nil,
			lastMoneyAtSessionStart = 0,
			session = {
				gained = 0, spent = 0,
				gained_sources = { quests = 0, looted = 0, vendor = 0, other = 0 },
				spent_sources = { taxi = 0, repairs = 0, other = 0 },
			},
			daily = { day = 0, gained = 0, spent = 0 },
			weekly = { week = 0, gained = 0, spent = 0 },
			monthly = { month = 0, gained = 0, spent = 0 },
		},
		profile = {
			lockFrame = false, clampFrame = true, hideInCombat = false,
			showSession = true, showDaily = true, showWeekly = true, showMonthly = true,
			frameTransparency = 0.9,
			summaryView = true,
		}
	})
end

function mod:GetOptions()
	return {
		behavior = {
			type = "group", name = "Behavior", order = 10,
			args = {
				lockFrame = { type = "toggle", name = "Lock Frame", desc = "Prevents the frame from being moved.", order = 1, get = function() return self.db.profile.lockFrame end, set = function(info, v) self.db.profile.lockFrame = v; self:ApplyFrameSettings() end },
				clampFrame = { type = "toggle", name = "Clamp to Screen", desc = "Prevents the frame from being moved off-screen.", order = 2, get = function() return self.db.profile.clampFrame end, set = function(info, v) self.db.profile.clampFrame = v; self:ApplyFrameSettings() end },
				hideInCombat = { type = "toggle", name = "Hide in Combat", desc = "Automatically hides the frame when you enter combat.", order = 3, get = function() return self.db.profile.hideInCombat end, set = function(info, v) self.db.profile.hideInCombat = v end },
			},
		},
		display = {
			type = "group", name = "Display", order = 20,
			args = {
				header_periods = { type = "header", name = "Visible Time Periods", order = 1 },
				showSession = { type = "toggle", name = "Show Session", order = 2, get = function() return self.db.profile.showSession end, set = function(info, v) self.db.profile.showSession = v; self:UpdateDisplayFrame() end },
				showDaily = { type = "toggle", name = "Show Today", order = 3, get = function() return self.db.profile.showDaily end, set = function(info, v) self.db.profile.showDaily = v; self:UpdateDisplayFrame() end },
				showWeekly = { type = "toggle", name = "Show This Week", order = 4, get = function() return self.db.profile.showWeekly end, set = function(info, v) self.db.profile.showWeekly = v; self:UpdateDisplayFrame() end },
				showMonthly = { type = "toggle", name = "Show This Month", order = 5, get = function() return self.db.profile.showMonthly end, set = function(info, v) self.db.profile.showMonthly = v; self:UpdateDisplayFrame() end },
				header_appearance = { type = "header", name = "Appearance", order = 10 },
				frameTransparency = { type = "range", name = "Frame Transparency", desc = "Sets the transparency of the frame background.", order = 11, min = 0.1, max = 1, step = 0.05, get = function() return self.db.profile.frameTransparency end, set = function(info, v) self.db.profile.frameTransparency = v; self:ApplyFrameSettings() end },
			},
		},
	}
end

-----------------------------------------------------------
-- Event Handling and Data Tracking
-----------------------------------------------------------

function mod:OnEnable()
	self:RegisterEvent("PLAYER_MONEY", "OnPlayerMoneyChanged")
	self:RegisterEvent("PLAYER_LOGIN", "InitializeSession")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")
	if UnitExists("player") then self:InitializeSession() end
	
	self:CreateDisplayFrame() 
	self.displayFrame:Hide()
end

function mod:OnDisable()
	self:UnregisterAllEvents()
end

local function GetCriteriaQuantity(criteriaID)
	if not criteriaID then return 0 end
	local _, _, _, quantity = GetAchievementCriteriaInfo(criteriaID)
	return quantity or 0
end

function mod:InitializeSession()
	local data = self.db.char
	data.session.gained, data.session.spent = 0, 0
	data.session.stat_snapshots = {}
	for k in pairs(data.session.gained_sources) do data.session.gained_sources[k] = 0 end
	for k in pairs(data.session.spent_sources) do data.session.spent_sources[k] = 0 end
	
	for key, statData in pairs(mod.trackedStats) do
		data.session.stat_snapshots[key] = GetCriteriaQuantity(statData.id)
	end
	
	local dayOfYear = tonumber(date("%j")); if data.daily.day ~= dayOfYear then data.daily = { day = dayOfYear, gained = 0, spent = 0 } end
	local weekOfYear = tonumber(date("%U")); if data.weekly.week ~= weekOfYear then data.weekly = { week = weekOfYear, gained = 0, spent = 0 } end
	local monthOfYear = tonumber(date("%m")); if data.monthly.month ~= monthOfYear then data.monthly = { month = monthOfYear, gained = 0, spent = 0 } end

	local money = GetMoney()
	data.lastMoney = money
	data.lastMoneyAtSessionStart = money
end

function mod:OnPlayerMoneyChanged()
	local data = self.db.char
	local newMoney = GetMoney()
	if data.lastMoney == nil then data.lastMoney = newMoney; return end
	
	local diff = newMoney - data.lastMoney
	if diff ~= 0 then
		if diff > 0 then
			data.daily.gained = data.daily.gained + diff; data.weekly.gained = data.weekly.gained + diff; data.monthly.gained = data.monthly.gained + diff
		else
			local spent = math_abs(diff)
			data.daily.spent = data.daily.spent + spent; data.weekly.spent = data.weekly.spent + spent; data.monthly.spent = data.monthly.spent + spent
		end
		if self.displayFrame and self.displayFrame:IsShown() then self:UpdateDisplayFrame() end
	end
	data.lastMoney = newMoney
end

function mod:UpdateSessionFromStatistics()
	local data = self.db.char
	local categorizedGained, categorizedSpent = 0, 0
	
	local gainedQuests = GetCriteriaQuantity(mod.trackedStats.quests.id) - (data.session.stat_snapshots.quests or 0)
	data.session.gained_sources.quests = gainedQuests; categorizedGained = categorizedGained + gainedQuests
	local gainedLooted = GetCriteriaQuantity(mod.trackedStats.looted.id) - (data.session.stat_snapshots.looted or 0)
	data.session.gained_sources.looted = gainedLooted; categorizedGained = categorizedGained + gainedLooted
	local gainedVendor = GetCriteriaQuantity(mod.trackedStats.vendor.id) - (data.session.stat_snapshots.vendor or 0)
	data.session.gained_sources.vendor = gainedVendor; categorizedGained = categorizedGained + gainedVendor
	
	local spentTaxi = GetCriteriaQuantity(mod.trackedStats.taxi.id) - (data.session.stat_snapshots.taxi or 0)
	data.session.spent_sources.taxi = spentTaxi; categorizedSpent = categorizedSpent + spentTaxi

	local totalChange = GetMoney() - data.lastMoneyAtSessionStart
	totalChange = totalChange - gainedVendor
	local categorizedChange = (categorizedGained - gainedVendor) - categorizedSpent
	local uncategorizedChange = totalChange - categorizedChange
	
	if uncategorizedChange > 0 then data.session.gained_sources.other = uncategorizedChange; data.session.spent_sources.other = 0
	else data.session.gained_sources.other = 0; data.session.spent_sources.other = math_abs(uncategorizedChange) end
	
	data.session.gained = categorizedGained + data.session.gained_sources.other
	data.session.spent = categorizedSpent + data.session.spent_sources.other
end

function mod:OnEnterCombat()
	if self.db.profile.hideInCombat and self.displayFrame and self.displayFrame:IsShown() then
		self.displayFrame:Hide(); self.hiddenInCombat = true
	end
end

function mod:OnLeaveCombat()
	if self.db.profile.hideInCombat and self.hiddenInCombat then
		self:UpdateDisplayFrame(); self.displayFrame:Show(); self.hiddenInCombat = false
	end
end

-----------------------------------------------------------
-- Display Frame (OVERHAULED)
-----------------------------------------------------------

function mod:CreateDisplayFrame()
	local frame = CreateFrame("Frame", "LanceBagsFinanceFrame", UIParent)
	frame:SetSize(280, 520)
	frame:SetPoint("CENTER")
	frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) if not mod.db.profile.lockFrame then self:StartMoving() end end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	
	frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 }})
	
	local title = frame:CreateFontString(nil, "ARTWORK"); title:SetFontObject(addon.bagFont); title:SetPoint("TOP", 0, -12); title:SetText(self.uiName)
	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); closeButton:SetPoint("TOPRIGHT", -6, -6)
	
	frame.dataFields = {}
	local periods = {"session", "daily", "weekly", "monthly"}; local periodLabels = { session = L["Session"], daily = L["Today"], weekly = L["This Week"], monthly = L["This Month"] }
	
	for _, period in ipairs(periods) do
		frame.dataFields[period] = {
			header = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"),
			netValue = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal"),
			gainedLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
			spentLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
			gainedValue = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
			spentValue = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
			separator = frame:CreateTexture(nil, "ARTWORK"),
		}
		frame.dataFields[period].header:SetText(periodLabels[period] or period)
		frame.dataFields[period].gainedLabel:SetText((L["Gained"] or "Gained") .. ":")
		frame.dataFields[period].spentLabel:SetText((L["Spent"] or "Spent") .. ":")

		-- ## NEW ## Set the text color for the labels to white.
		frame.dataFields[period].gainedLabel:SetTextColor(1, 1, 1)
		frame.dataFields[period].spentLabel:SetTextColor(1, 1, 1)
	end

	local toggleButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	toggleButton:SetSize(120, 22)
	toggleButton:SetPoint("BOTTOM", 0, 15)
	toggleButton:SetScript("OnClick", function()
		self.db.profile.summaryView = not self.db.profile.summaryView
		self:UpdateDisplayFrame()
	end)
	frame.toggleButton = toggleButton
	
	self.displayFrame = frame
	self:ApplyFrameSettings()
end

function mod:UpdateDisplayFrame()
	if not self.displayFrame then self:CreateDisplayFrame() end
	self:UpdateSessionFromStatistics()
	
	local frame, data, profile = self.displayFrame, self.db.char, self.db.profile
	local summaryView = profile.summaryView
	
	local lastAnchor = frame
	local ySpacing = -8
	local yHeaderSpacing = -20
	
	frame.toggleButton:SetText(summaryView and (L["Show Details"]) or (L["Show Summary"]))

	for _, period in ipairs({"session", "daily", "weekly", "monthly"}) do
		local row = frame.dataFields[period]
		if profile["show" .. period:gsub("^%l", string.upper)] then
			local pData = data[period]
			
			-- ## CHANGE ## Increased the initial offset from -35 to -45 to add a gap.
			row.header:ClearAllPoints()
			row.header:SetPoint("TOP", lastAnchor, (lastAnchor == frame and "TOP" or "BOTTOM"), 0, (lastAnchor == frame and -45 or yHeaderSpacing - 5))
			row.header:SetPoint("LEFT", frame, "LEFT", 20, 0)
			row.header:SetTextColor(1, 0.82, 0)
			row.header:Show()
			
			local net = pData.gained - pData.spent
			local color = net >= 0 and "|cff20ff20" or "|cffff2020"; local sign = net > 0 and "+" or ""
			row.netValue:ClearAllPoints()
			row.netValue:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
			row.netValue:SetPoint("TOP", row.header, "TOP", 0, 0)
			row.netValue:SetText(color .. sign .. GetMoneyString(net, true) .. "|r")
			row.netValue:Show()
			
			if summaryView then
				row.gainedLabel:Hide(); row.gainedValue:Hide()
				row.spentLabel:Hide(); row.spentValue:Hide()
				lastAnchor = row.header
			else
				row.gainedLabel:ClearAllPoints(); row.gainedLabel:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 20, ySpacing)
				row.gainedValue:ClearAllPoints(); row.gainedValue:SetPoint("LEFT", row.gainedLabel, "RIGHT", 5, 0)
				row.gainedValue:SetText("|cff20ff20" .. GetMoneyString(pData.gained, true) .. "|r")
				row.gainedLabel:Show(); row.gainedValue:Show()

				row.spentValue:ClearAllPoints(); row.spentValue:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, 0)
				row.spentValue:SetPoint("TOP", row.gainedValue, "TOP", 0, 0)
				row.spentValue:SetText("|cffff2020" .. GetMoneyString(pData.spent, true) .. "|r")
				row.spentLabel:ClearAllPoints(); row.spentLabel:SetPoint("RIGHT", row.spentValue, "LEFT", -5, 0)
				row.spentLabel:Show(); row.spentValue:Show()
				lastAnchor = row.gainedLabel
			end
			
			local separator = row.separator
			separator:SetTexture(1, 1, 1, 0.25)
			separator:SetSize(frame:GetWidth() - 40, 1)
			separator:ClearAllPoints()
			separator:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, (lastAnchor:GetBottom() - frame:GetTop()) + ySpacing)
			separator:Show()
			lastAnchor = separator
		else
			for _, element in pairs(row) do if element and element.Hide then element:Hide() end end
		end
	end
	
	local newHeight = (frame:GetTop() - lastAnchor:GetBottom()) + 60
	frame:SetHeight(newHeight)
end

function mod:ApplyFrameSettings()
	if not self.displayFrame then return end
	local frame = self.displayFrame
	frame:SetMovable(not self.db.profile.lockFrame)
	frame:SetClampedToScreen(self.db.profile.clampFrame)
	frame:SetBackdropColor(0.1, 0.1, 0.1, self.db.profile.frameTransparency)
end

function mod:ToggleDisplayFrame()
	if not self.displayFrame then self:CreateDisplayFrame() end
	if self.displayFrame:IsShown() then self.displayFrame:Hide()
	else self:UpdateDisplayFrame(); self.displayFrame:Show() end
end