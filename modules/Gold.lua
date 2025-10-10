--[[
LanceBags - GOLD Button Module
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local GetMoneyString = _G.GetMoneyString
local GameTooltip = _G.GameTooltip
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local GetMoney = _G.GetMoney
local GetRealmName = _G.GetRealmName
local UnitName = _G.UnitName
local UnitClass = _G.UnitClass
local type = _G.type 
local next = _G.next
local tinsert = _G.tinsert 
local tsort = _G.table.sort 
--GLOBALS>

local mod = addon:NewModule('Gold', 'AceEvent-3.0')
mod.uiName = L['GOLD Button']
mod.uiDesc = L['Displays the GOLD button with a multi-character gold summary tooltip.']

-- **Define a default color for non-standard/missing classes**
local DEFAULT_COLOR = {r=1, g=1, b=1} -- White (1, 1, 1)

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	for _, bag in addon:IterateBags() do
		if bag:HasFrame() then
			self:OnBagFrameCreated(bag)
		end
	end
end

function mod:OnDisable()
	if self.button then
		self.button:Hide()
	end
end

-- Utility function (no longer needed, but kept for structural integrity)
local function GetCurrentRealmKeyRobust()
    local shortRealmName = GetRealmName()
    
    for realmKey, realmData in pairs(addon.db.realm or {}) do
        if type(realmData) == "table" then
            if string.find(realmKey, shortRealmName, 1, true) then
                return realmKey
            end
        end
    end
    
    return shortRealmName
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" then return end
	local frame = bag:GetFrame()

	-- Create the GOLD button
	local button = CreateFrame("Button", addonName.."GoldButton", frame, "UIPanelButtonTemplate")
	button:SetSize(40, 20)
	button:SetText("|cffFFD700GOLD|r")
	button:SetNormalFontObject("GameFontNormalSmall")
	self.button = button

	-- Add this button as a widget to the bottom right. Order 40.
	frame:AddBottomWidget(button, "RIGHT", 40, 20)

	-- GOLD button scripts
	button:SetScript("OnClick", function(self, button)
		local financeTracker = addon:GetModule("FinanceTracker", true)
		if financeTracker and financeTracker.ToggleDisplayFrame then
			financeTracker:ToggleDisplayFrame()
		end
	end)
	
	button:SetScript("OnEnter", function(frame)
		GameTooltip:SetOwner(frame, "ANCHOR_TOPRIGHT")
        -- Set opacity to 85% and background color to black (0,0,0)
        GameTooltip:SetBackdropColor(0, 0, 0, 0.85) 
		GameTooltip:AddLine(L["Gold Summary"], 1, 1, 1); 

		-- Display Current Character Gold (Current Display remains for structural simplicity)
		local className, class = UnitClass("player");
		local currentColor = RAID_CLASS_COLORS[class] or DEFAULT_COLOR 
		GameTooltip:AddDoubleLine(UnitName("player"), GetMoneyString(GetMoney()), currentColor.r, currentColor.g, currentColor.b, 1, 1, 1)

        -- >>>>>>>>>>>>>>>>>>>>>>>>>> FINAL GLOBAL ACCESS & GROUPING <<<<<<<<<<<<<<<<<<<<<<<<<<<<
        
         local groupedAlts = {}
        local totalAltsFound = 0
        local fullCurrentPlayerKey = (UnitName("player") or "Unknown") .. " - " .. (GetRealmName() or "Unknown")
        local seen = {}

        local function addChar(charKey, charData)
            if charKey ~= fullCurrentPlayerKey and type(charData) == "table" and type(charData.money) == "number" then
                if not seen[charKey] then
                    local realmName = charKey:match("%- (.*)$") or "Unknown Realm"
                    groupedAlts[realmName] = groupedAlts[realmName] or {}
                    tinsert(groupedAlts[realmName], { key = charKey, data = charData })
                    totalAltsFound = totalAltsFound + 1
                    seen[charKey] = true
                end
            end
        end

        -- 1) Preferred future store (cross-realm): addon.db.global.characters
        if addon.db and addon.db.global and type(addon.db.global.characters) == "table" then
            for k, v in pairs(addon.db.global.characters) do
                addChar(k, v)
            end
        end

        -- 2) AceDB all-realms table: addon.db.sv.realm[realmName].characters
        local sv = addon.db and addon.db.sv
        if sv and type(sv.realm) == "table" then
            for realmName, rdata in pairs(sv.realm) do
                local chars = (type(rdata) == "table") and rdata.characters or nil
                if type(chars) == "table" then
                    for k, v in pairs(chars) do
                        addChar(k, v)
                    end
                end
            end
        end

        -- 3) Current realm fallback: addon.db.realm.characters
        if addon.db and addon.db.realm and type(addon.db.realm.characters) == "table" then
            for k, v in pairs(addon.db.realm.characters) do
                addChar(k, v)
            end
        end

        -- Display the collected alt data
        if totalAltsFound > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["All Other Characters:"], 1, 1, 1)

            -- Sort realm keys alphabetically
            local sortedRealmKeys = {}
            for realmKey in pairs(groupedAlts) do
                tinsert(sortedRealmKeys, realmKey)
            end
            tsort(sortedRealmKeys)

            -- Sort characters within each realm and render
            for _, realmName in ipairs(sortedRealmKeys) do
                local altsInGroup = groupedAlts[realmName]
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cffFFD700<< "..realmName.." >>|r", 1, 1, 1)

                tsort(altsInGroup, function(a, b) return a.key < b.key end)
                for _, v in ipairs(altsInGroup) do
                    local altColor = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[v.data.class]) or DEFAULT_COLOR
                    local displayName = v.key:match("^(.-) %-") or v.key
                    GameTooltip:AddDoubleLine("  "..displayName, GetMoneyString(v.data.money),
                        altColor.r, altColor.g, altColor.b, 1, 1, 1)
                end
            end
        else
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("--- No other characters found in saved data. ---", 1, 0, 0)
        end
		
        -- >>>>>>>>>>>>>>>>>>>>>>>>>> END GLOBAL DISPLAY GROUPED BY REALM <<<<<<<<<<<<<<<<<<<<<<<<<<<<

		GameTooltip:Show()
	end)
	
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end