--[[
LanceBags - Alt Inventory Viewer Module
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
--GLOBALS>

-- Register "AltViewer" as a new module that can be enabled/disabled.
local mod = addon:NewModule('AltViewer', 'AceEvent-3.0')
mod.uiName = L['Alt Inventory']
mod.uiDesc = L['Adds a frame to view the inventory and gold of your other characters.']


-- This function runs when the module is enabled in the options.
function mod:OnEnable()
	-- This hooks our OnBagFrameCreated function to run whenever a bag is created.
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')

	-- If the bag frame already exists, we need to run our creation function manually.
	for _, bag in addon:IterateBags() do
		if bag:HasFrame() then
			self:OnBagFrameCreated(bag)
		end
	end
	addon:Debug("AltViewer enabled.")
end

-- This function runs when the module is disabled.
function mod:OnDisable()
	-- Code to remove the "Alts" button will go here.
	if self.button then
		self.button:Hide()
	end
	addon:Debug("AltViewer disabled.")
end

-- ## NEW ## This function creates and adds our button to the bag frame.
function mod:OnBagFrameCreated(bag)
	-- We only want to add this button to the main backpack, not the bank.
	if bag.bagName ~= "Backpack" then return end
	
	-- Get the main frame of the bag
	local frame = bag:GetFrame()
	
	-- Create the button
	local button = CreateFrame("Button", addonName.."AltViewerButton", frame)
	button:SetSize(20, 20)
	
	-- Set the button's icon
	button:SetNormalTexture("Interface\\FriendsFrame\\PlusManz-Button")
	button:SetPushedTexture("Interface\\FriendsFrame\\PlusManz-Button-Down")
	button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
	
	-- Position the button in the top-right header
	frame:AddHeaderWidget(button, "RIGHT", -45, 20, 0)
	
	-- Add a tooltip
	addon.SetupTooltip(button, L["Alt Inventory"], L["Click to view the inventory of your other characters."])
	
	-- Set the click action
	button:SetScript("OnClick", function()
		self:ToggleViewer()
	end)
	
	-- Save a reference to the button so we can hide it later
	self.button = button
end


-- This will be the main function to show/hide our new viewer window.
function mod:ToggleViewer()
	addon:Debug("ToggleViewer called!")
	-- In the next step, we will build the window that this function will open.
end