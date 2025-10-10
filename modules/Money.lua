--[[
LanceBags - Custom Money Display Module
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local GetMoney = _G.GetMoney
local floor = _G.math.floor
--GLOBALS>

local mod = addon:NewModule('Money', 'AceEvent-3.0')
mod.uiName = L['Money Display']
mod.uiDesc = L['Displays character money at the bottom right of the backpack.']

-- This function formats your gold into the custom color string.
local function FormatMoney(copper)
	if copper == 0 then
		return "|cffFFFFFF0|r|cffCD853Fc|r"
	end

	local gold = floor(copper / 10000)
	local silver = floor((copper % 10000) / 100)
	local copperVal = copper % 100
	
	local text = ""
	
	if gold > 0 then
		text = text .. "|cffFFFFFF" .. gold .. "|r|cffFFFF00g|r "
	end
	if silver > 0 or gold > 0 then
		text = text .. "|cffFFFFFF" .. silver .. "|r|cffC7C7CFs|r "
	end
	
	text = text .. "|cffFFFFFF" .. copperVal .. "|r|cffCD853Fc|r"
	
	return text
end

-- This is the local version of the update function
local function UpdateDisplay(self)
	if not self.text then return end
	self.text:SetText(FormatMoney(GetMoney()))
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	for _, bag in addon:IterateBags() do
		if bag:HasFrame() then
			self:OnBagFrameCreated(bag)
		end
	end
	self:RegisterEvent("PLAYER_MONEY", function() UpdateDisplay(mod) end)
end

function mod:OnDisable()
	if self.container then
		self.container:Hide()
	end
	self:UnregisterEvent("PLAYER_MONEY")
end

function mod:OnBagFrameCreated(bag)
    if bag.bagName ~= "Backpack" then return end
    local frame = bag:GetFrame()

    -- Create an invisible container with a fixed, compact width.
    local container = CreateFrame("Frame", addonName.."MoneyContainer", frame)
    -- ## CHANGE ## Increased width to 85 to fit the larger font. Height remains 20.
    container:SetSize(85, 20)
    self.container = container
    
    -- Create our custom text label inside the container.
    -- ## FIX ## Changed font object from 'GameFontNormalSmall' to 'GameFontNormal'.
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    text:SetJustifyH("RIGHT") -- Right-align the text
    self.text = text
    
    -- Add the container as a widget to the bottom right.
    -- Order 50 makes it the rightmost item.
    frame:AddBottomWidget(container, "RIGHT", 50, 20)

	-- Set the initial text
	UpdateDisplay(self)
end