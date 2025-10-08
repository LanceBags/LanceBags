local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local format = _G.format
local GameTooltip = _G.GameTooltip
local IsAltKeyDown = _G.IsAltKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local IsModifierKeyDown = _G.IsModifierKeyDown
local IsShiftKeyDown = _G.IsShiftKeyDown
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local tconcat = _G.table.concat
local tinsert = _G.tinsert
local tsort = _G.table.sort
local wipe = _G.wipe
-- New Globals for Character Counts
local GetItemInfo = _G.GetItemInfo
local GetRealmName = _G.GetRealmName
local select = _G.select
local string_format = _G.string.format
local tonumber = _G.tonumber
local UnitName = _G.UnitName
local BANK_CONTAINER = _G.BANK_CONTAINER
local BankFrame = _G.BankFrame
local GetContainerItemID = _G.GetContainerItemID
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerNumSlots = _G.GetContainerNumSlots
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS
local NUM_BANKBAGSLOTS = _G.NUM_BANKBAGSLOTS
local NUM_BANKGENERIC_SLOTS = _G.NUM_BANKGENERIC_SLOTS
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
--GLOBALS>

local mod = addon:NewModule('TooltipInfo', 'AceEvent-3.0', 'AceHook-3.0')
mod.uiName = L['Tooltip information']
mod.uiDesc = L['Add more information in tooltips related to items in your bags.']

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.name, {profile={
		item = 'ctrl',
		container = 'ctrl',
		filter = 'ctrl',
		counts = 'always', -- New option for character counts
	}})
end

function mod:OnEnable()
	if not self.hooked then
		GameTooltip:HookScript('OnTooltipSetItem', function(...)
			if self:IsEnabled() then
				return self:OnTooltipSetItem(...)
			end
		end)
		self.hooked = true
	end
end

function mod:GetOptions()
	local modMeta = { __index = {
		type = "select",
		width = "double",
		values = {
			never = L["Never"],
			shift = L["When shift is held down"],
			ctrl = L["When ctrl is held down"],
			alt = L["When alt is held down"],
			any = L["When any modifier key is held down"],
			always = L["Always"],
		},
	}}
	return {
		item = setmetatable({
			name = L["Show item information..."],
			order = 10,
		}, modMeta),
		container = setmetatable({
			name = L["Show container information..."],
			order = 20,
		}, modMeta),
		filter = setmetatable({
			name = L["Show filtering information..."],
			order = 30,
		}, modMeta),
		counts = setmetatable({ -- New options entry
			name = L["Show character counts..."],
			order = 40,
		}, modMeta),
	}, addon:GetOptionHandler(self)
end

local modifierTests = {
	never = function() end,
	always = function() return true end,
	any = IsModifierKeyDown,
	shift = IsShiftKeyDown,
	ctrl = IsControlKeyDown,
	alt = IsAltKeyDown,
}

local function TestModifier(name)
	return modifierTests[mod.db.profile[name] or "never"]()
end

-- This function is a direct copy of the working code from TooltipCounts.lua
local function AddCharacterCounts(tooltip)
	local _, itemLink = tooltip:GetItem()
	if not itemLink then return end
	
	local itemID = tonumber(itemLink:match("item:(%d+)"))
	if not itemID then return end

	local results = {}
	local currentRealm = GetRealmName()
	local currentPlayer = UnitName("player")
	local currentPlayerKey = currentPlayer .. " - " .. currentRealm
	
	-- 1. Get CURRENT character's data
	-- Bags are always scanned live
	local currentBags = 0
	for bagID = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bagID) do
			if GetContainerItemID(bagID, slot) == itemID then
				currentBags = currentBags + (select(2, GetContainerItemInfo(bagID, slot)) or 1)
			end
		end
	end
	
	-- For bank, perform a live scan if open, otherwise use saved data
	local currentBank = 0
	if BankFrame and BankFrame:IsShown() then
		-- Bank is open, do a live scan
		for slot = 1, NUM_BANKGENERIC_SLOTS do
			if GetContainerItemID(BANK_CONTAINER, slot) == itemID then
				currentBank = currentBank + (select(2, GetContainerItemInfo(BANK_CONTAINER, slot)) or 1)
			end
		end
		for bagID = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
			for slot = 1, GetContainerNumSlots(bagID) do
				if GetContainerItemID(bagID, slot) == itemID then
					currentBank = currentBank + (select(2, GetContainerItemInfo(bagID, slot)) or 1)
				end
			end
		end
	else
		-- Bank is closed, use the saved snapshot with a NUMBER key
		if addon.db.realm.characters and addon.db.realm.characters[currentPlayerKey] and addon.db.realm.characters[currentPlayerKey].bank then
			currentBank = addon.db.realm.characters[currentPlayerKey].bank[itemID] or 0
		end
	end
	
	if currentBags + currentBank > 0 then
		tinsert(results, { name = currentPlayer, isCurrent = true, total = currentBags + currentBank, bags = currentBags, bank = currentBank })
	end

	-- 2. Scan and add OTHER characters' saved data
	if addon.db.realm.characters then
		for charKey, charData in pairs(addon.db.realm.characters) do
			local name, realm = charKey:match("^(.*) %- (.*)$")
			if name and realm and realm == currentRealm and name ~= currentPlayer then
				-- Use a NUMBER key for lookups
				local bagCount = (charData.bags and charData.bags[itemID]) or 0
				local bankCount = (charData.bank and charData.bank[itemID]) or 0
				if bagCount + bankCount > 0 then
					tinsert(results, { name = name, total = bagCount + bankCount, bags = bagCount, bank = bankCount })
				end
			end
		end
	end

	-- 3. Display all results if any were found
	if #results > 0 then
		tooltip:AddLine(" ")
		tooltip:AddLine((L["Character Counts:"] or "Character Counts:"), 0.6, 0.8, 1.0)
		for _, data in pairs(results) do
			local nameText = data.name
			if data.isCurrent then
				nameText = "|cffFFFF00" .. nameText .. " (Current)|r"
			end
			local locationStr = string_format("(|cffFFFF00Bags: %d, Bank: %d|r)", data.bags, data.bank)
			tooltip:AddDoubleLine(nameText, data.total .. " " .. locationStr)
		end
		return true -- Indicate that we added lines
	end
	return false
end

local t = {}
local GetBagSlotFromId = addon.GetBagSlotFromId

function mod:OnTooltipSetItem(tt)
	local button = tt:GetOwner()
	if not button then return end
	local bag, slot, container = button.bag, button.slot, button.container
	
	-- We now check for the character counts first, outside the bag-only check
	local addedLines = false
	if TestModifier("counts") then
		if AddCharacterCounts(tt) then
			addedLines = true
		end
	end

	if not (bag and slot and container) then
		if addedLines then tt:Show() end
		return
	end
	
	local slotData = container.content[bag][slot]
	local stack = button:GetStack()
	if stack then button = stack end

	if slotData.link and TestModifier("item") then
		tt:AddLine(" ")
		tt:AddLine(L["Item information"], 1, 1, 1)
		tt:AddDoubleLine(L["Item ID"], slotData.itemId) -- ITEM ID ADDED HERE
		tt:AddDoubleLine(L["Maximum stack size"], slotData.maxStack)
		tt:AddDoubleLine(L["AH category"], slotData.class)
		tt:AddDoubleLine(L["AH subcategory"], slotData.subclass)
		addedLines = true
	end

	if TestModifier("container") then
		tt:AddLine(" ")
		tt:AddLine(L["Container information"], 1, 1, 1)
		local vBag, vSlot = bag, slot
		if stack then
			wipe(t)
			for slotId in pairs(stack.slots) do
				tinsert(t, format("(%d,%d)", GetBagSlotFromId(slotId)))
			end
			if #t > 1 then
				tsort(t)
				tt:AddDoubleLine(L["Virtual stack slots"], tconcat(t, ", "))
				vBag, vSlot = nil, nil
			end
		end
		if vBag and vSlot then
			tt:AddDoubleLine(L["Bag number"], vBag)
			tt:AddDoubleLine(L["Slot number"], vSlot)
		end
		addedLines = true
	end

	if TestModifier("filter") then
		tt:AddLine(" ")
		tt:AddLine(L["Filtering information"], 1, 1, 1)
		tt:AddDoubleLine(L["Filter"], button.filterName or "-")
		local section = button:GetSection()
		tt:AddDoubleLine(L["Section"], section.name or "-")
		tt:AddDoubleLine(L["Category"], section.category or "-")
		addedLines = true
	end

	if addedLines then
		tt:Show()
	end
end