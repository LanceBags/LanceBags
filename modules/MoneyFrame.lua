--[[
LanceBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetMoneyString = _G.GetMoneyString
local GameTooltip = _G.GameTooltip
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local GetMoney = _G.GetMoney
local GetRealmName = _G.GetRealmName
local UnitName = _G.UnitName
local strsplit = _G.strsplit
local ToggleCharacter = _G.ToggleCharacter
local UnitClass = _G.UnitClass
local PlaySound = _G.PlaySound
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS
local GetItemInfo = _G.GetItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local ITEM_QUALITY_POOR = _G.ITEM_QUALITY_POOR
local UseContainerItem = _G.UseContainerItem
--GLOBALS>

local mod = addon:NewModule('MoneyFrame', 'AceEvent-3.0')
mod.uiName = L['Money']
mod.uiDesc = L['Display character money at bottom right of the backpack.']

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	if self.container then
		self.container:Show()
		self:UpdateJunkButtonState() -- Update state when enabled
	end
	-- ## CHANGE ## Listen to the addon's internal message for perfect timing.
	self:RegisterMessage("LanceBags_PostContentUpdate", "UpdateJunkButtonState")
end

function mod:OnDisable()
	if self.container then
		self.container:Hide()
	end
	-- ## CHANGE ## Unregister the message accordingly.
	self:UnregisterMessage("LanceBags_PostContentUpdate")
end

-- This new function scans for junk, updates the button's state, and stores the total value
function mod:UpdateJunkButtonState()
	if not self.junkButton then return end

	local totalValue = 0
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local _, _, quality, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
				if quality == ITEM_QUALITY_POOR and vendorPrice and vendorPrice > 0 then
					local _, count = GetContainerItemInfo(bag, slot)
					totalValue = totalValue + (vendorPrice * (count or 1))
				end
			end
		end
	end
	
	self.totalJunkValue = totalValue -- Store for the tooltip

	if totalValue > 0 then
		self.junkButton:Enable()
	else
		self.junkButton:Disable()
	end
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" then return end
	local frame = bag:GetFrame()

	-- 1. Create a dedicated horizontal container for our footer elements
	local footerContainer = CreateFrame("Frame", nil, frame)
	footerContainer:SetHeight(25)
	self.container = footerContainer

	-- 2. Create the GOLD button, reverting to the basic template
	-- ## CHANGE ## Re-added "UIPanelButtonTemplate"
	local goldButton = CreateFrame("Button", nil, footerContainer, "UIPanelButtonTemplate")
	goldButton:SetSize(60, 22)
	goldButton:SetText("|cffFFD700GOLD|r")
	goldButton:SetPoint("RIGHT", footerContainer, "RIGHT", 0, 0)
	-- ## REMOVED ## All manual texture and font settings are now gone.
	self.goldButton = goldButton

	-- 3. Create the JUNK button, reverting to the basic template
	-- ## CHANGE ## Re-added "UIPanelButtonTemplate"
	local junkButton = CreateFrame("Button", nil, footerContainer, "UIPanelButtonTemplate")
	junkButton:SetSize(60, 22)
	junkButton:SetText("|cffC7C7CFJUNK|r")
	junkButton:SetPoint("RIGHT", goldButton, "LEFT", -5, 0)
	-- ## REMOVED ## All manual texture and font settings are now gone.
	self.junkButton = junkButton
	
	-- 4. Re-position the original MoneyFrame to the left of the buttons
	self.widget = CreateFrame("Frame", addonName.."MoneyFrame", footerContainer, "MoneyFrameTemplate")
	self.widget:SetHeight(19)
	self.widget:SetPoint("RIGHT", junkButton, "LEFT", -10, 0)

	-- 5. Calculate total width and add the container to the bag's layout
	local moneyWidth = self.widget:GetWidth() or 100
	local totalWidth = moneyWidth + junkButton:GetWidth() + goldButton:GetWidth() + 25 -- (spacers)
	footerContainer:SetWidth(totalWidth)
	frame:AddBottomWidget(footerContainer, "RIGHT", 50, footerContainer:GetHeight())

	-- 6. Script the GOLD button (No changes to scripts)
	goldButton:SetScript("OnClick", function(self, button)
		local financeTracker = addon:GetModule("FinanceTracker", true)
		if financeTracker and financeTracker.ToggleDisplayFrame then
			financeTracker:ToggleDisplayFrame()
		end
	end)
	goldButton:SetScript("OnEnter", function(frame)
		GameTooltip:SetOwner(frame, "ANCHOR_TOPRIGHT")
		GameTooltip:AddLine(L["Gold Summary"], 1, 1, 1)
		GameTooltip:AddLine(" ")
		local currentPlayerName = UnitName("player")
		local _, currentPlayerClass = UnitClass("player")
		local classColor = RAID_CLASS_COLORS[currentPlayerClass]
		GameTooltip:AddDoubleLine(currentPlayerName, GetMoneyString(GetMoney()), classColor.r, classColor.g, classColor.b, 1, 1, 1)
		if addon.db.realm.characters and next(addon.db.realm.characters) then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(L["Other Characters:"], 1, 1, 1)
			local currentRealm, currentPlayer = GetRealmName(), UnitName("player")
			local sortedChars = {}
			for key, data in pairs(addon.db.realm.characters) do
				local name, realm = key:match("^(.*) %- (.*)$")
				if name and realm and realm == currentRealm and name ~= currentPlayer then
					table.insert(sortedChars, { name = name, data = data })
				end
			end
			table.sort(sortedChars, function(a, b) return a.name < b.name end)
			for _, char in ipairs(sortedChars) do
				local classColor = RAID_CLASS_COLORS[char.data.class]
				if classColor then
					GameTooltip:AddDoubleLine(char.name, GetMoneyString(char.data.money), classColor.r, classColor.g, classColor.b, 1, 1, 1)
				end
			end
		end
		GameTooltip:Show()
	end)
	goldButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- 7. Script the JUNK button (No changes to scripts)
	junkButton:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		local totalValue = 0
		for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
			for slot = 1, GetContainerNumSlots(bag) do
				local link = GetContainerItemLink(bag, slot)
				if link then
					local _, _, quality, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
					if quality == ITEM_QUALITY_POOR and vendorPrice and vendorPrice > 0 then
						local _, count = GetContainerItemInfo(bag, slot)
						totalValue = totalValue + (vendorPrice * (count or 1))
						UseContainerItem(bag, slot)
					end
				end
			end
		end
		if totalValue > 0 then
			local moneyString = GetMoneyString(totalValue)
			print(L["Sold junk for:"] .. " " .. moneyString)
		end
	end)
	junkButton:SetScript("OnEnter", function(frame)
		GameTooltip:SetOwner(frame, "ANCHOR_TOPRIGHT")
		GameTooltip:AddLine(L["Sell Junk"], 1, 1, 1)
		GameTooltip:AddLine(L["Click to sell all junk (grey) items."], 0.8, 0.8, 0.8)
		if self.totalJunkValue and self.totalJunkValue > 0 then
			GameTooltip:AddLine(" ")
			GameTooltip:AddDoubleLine(L["Total Junk Value:"], GetMoneyString(self.totalJunkValue), 0.6, 0.6, 0.6, 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	junkButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- 8. Set the initial state of the junk button
	self:UpdateJunkButtonState()
end