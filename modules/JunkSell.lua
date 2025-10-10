--[[
LanceBags - JUNK Sell Button Module
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local GetContainerItemInfo = _G.GetContainerItemInfo
local PlaySound = _G.PlaySound
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS
local GetItemInfo = _G.GetItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local ITEM_QUALITY_POOR = _G.ITEM_QUALITY_POOR
local UseContainerItem = _G.UseContainerItem
local GetMoneyString = _G.GetMoneyString
local GameTooltip = _G.GameTooltip
--GLOBALS>

local mod = addon:NewModule('JunkSell', 'AceEvent-3.0')
mod.uiName = L['JUNK Sell Button']
mod.uiDesc = L['Displays the JUNK button for selling grey items.']

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	for _, bag in addon:IterateBags() do
		if bag:HasFrame() then
			self:OnBagFrameCreated(bag)
		end
	end
	self:RegisterMessage("LanceBags_PostContentUpdate", "UpdateJunkButtonState")
end

function mod:OnDisable()
	if self.button then
		self.button:Hide()
	end
end

function mod:UpdateJunkButtonState()
	if not self.button then return end

	local totalValue = 0
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		for slot = GetContainerNumSlots(bag), 1, -1 do
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
	
	self.totalJunkValue = totalValue

	if totalValue > 0 then
		self.button:Enable()
	else
		self.button:Disable()
	end
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" then return end
	local frame = bag:GetFrame()

	-- Create the JUNK button
	local button = CreateFrame("Button", addonName.."JunkSellButton", frame, "UIPanelButtonTemplate")
	button:SetSize(40, 20)
	button:SetText("|cffC7C7CFJUNK|r")
	button:SetNormalFontObject("GameFontNormalSmall")
	button:SetDisabledFontObject("GameFontDisableSmall")
	self.button = button
	
	-- Add this button as a widget to the bottom right. Order 30.
	frame:AddBottomWidget(button, "RIGHT", 30, 20)

	-- JUNK button scripts
	button:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn"); local v=0; for b=BACKPACK_CONTAINER,NUM_BAG_SLOTS do for s=GetContainerNumSlots(b),1,-1 do local l=GetContainerItemLink(b,s) if l then local _,_,q,_,_,_,_,_,_,_,p=GetItemInfo(l) if q==ITEM_QUALITY_POOR and p and p>0 then local _,c=GetContainerItemInfo(b,s);v=v+(p*(c or 1));UseContainerItem(b,s) end end end end; if v>0 then print(L["Sold junk for:"].." "..GetMoneyString(v)) end
	end)
	button:SetScript("OnEnter", function(frame)
		GameTooltip:SetOwner(frame, "ANCHOR_TOPRIGHT")
		GameTooltip:AddLine(L["Sell Junk"], 1, 1, 1)
		GameTooltip:AddLine(L["Click to sell all junk (grey) items."], 0.8, 0.8, 0.8)
		if self.totalJunkValue and self.totalJunkValue > 0 then
			GameTooltip:AddLine(" ")
			GameTooltip:AddDoubleLine(L["Total Junk Value:"], GetMoneyString(self.totalJunkValue), 0.6, 0.6, 0.6, 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Set initial state
	self:UpdateJunkButtonState()
end