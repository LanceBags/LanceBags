--[[
LanceBags - Alt Inventory Viewer (Wrath 3.3.5a)
--]]

local addonName, addon = ...
local L = addon.L or setmetatable({
    ["Alt Inventory"] = "Alt Inventory",
    ["Show Bank"]     = "Show Bank",
    ["Show Bags"]     = "Show Bags",
    ["Refresh"]       = "Refresh",
    ["No other characters on this realm."] = "No other characters on this realm.",
    ["No data for this character yet. Log into them once."] = "No data for this character yet. Log into them once.",
    ["Click to view the inventory of your other characters."] = "Click to view the inventory of your other characters.",
    ["This character's bags are empty."] = "This character's bags are empty.",
    ["This character's bank is empty."] = "This character's bank is empty.",
}, { __index = function(t,k) return k end })

------------------------------------------------------------
-- Blizzard API locals
------------------------------------------------------------
local _G = _G
local CreateFrame, UIParent = _G.CreateFrame, _G.UIParent
local GetRealmName, UnitName = _G.GetRealmName, _G.UnitName
local GetItemInfo = _G.GetItemInfo
local GetItemQualityColor = _G.GetItemQualityColor
local SetItemButtonTexture = _G.SetItemButtonTexture
local SetItemButtonCount   = _G.SetItemButtonCount
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local GameTooltip = _G.GameTooltip
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo  = _G.UIDropDownMenu_CreateInfo
local UIDropDownMenu_SetSelectedValue = _G.UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_SetText     = _G.UIDropDownMenu_SetText
local UIDropDownMenu_AddButton   = _G.UIDropDownMenu_AddButton

------------------------------------------------------------
-- Module setup
------------------------------------------------------------
local mod = addon:NewModule("AltViewer", "AceEvent-3.0", "AceTimer-3.0")
mod.uiName = L["Alt Inventory"]
mod.state = { selectedKey = nil, viewBank = false }


-- === Icon-priming helpers (Wrath 3.3.5a) ===
local function AnyMissingItemInfo(items)
    if not items then return false end
    for i = 1, #items do
        local id = items[i].id
        local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
        if (not name) or (not icon) then
            return true
        end
    end
    return false
end

local function PrimeItemInfoCache(items)
    if not items or #items == 0 then return end
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    for i = 1, #items do
        local id = items[i].id
        local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
        if (not name) or (not icon) then
            GameTooltip:SetHyperlink("item:" .. id)
        end
    end
    GameTooltip:Hide()
end


-- === Repeated priming loop for slow item info ===
function mod:StartPrimeRepeater()
    if self._primeRepeater then return end  -- already running
    self._primeRepeaterCount = 0
    self._primeRepeater = self:ScheduleRepeatingTimer(function()
        if not (self.viewer and self.viewer:IsShown() and self.currentItems) then
            self:StopPrimeRepeater()
            return
        end
        self._primeRepeaterCount = self._primeRepeaterCount + 1
        PrimeItemInfoCache(self.currentItems)

        -- Stop early if everything is resolved or after 3 passes
        if not AnyMissingItemInfo(self.currentItems) or self._primeRepeaterCount >= 3 then
            self:StopPrimeRepeater()
        end
    end, 0.8)  -- every 0.8 seconds; you can raise/lower
end

function mod:StopPrimeRepeater()
    if self._primeRepeater then
        self:CancelTimer(self._primeRepeater)
        self._primeRepeater = nil
    end
end

-- === Preload icons before showing viewer ===
function mod:PrimeItemsBeforeDisplay(srcMap, onDone)
    if not srcMap or not next(srcMap) then
        if onDone then onDone() end
        return
    end

    local items = {}
    for itemID in pairs(srcMap) do
        table.insert(items, { id = itemID })
    end

    local passes = 0
    local function doPrime()
        passes = passes + 1
        PrimeItemInfoCache(items)
        if passes < 3 and AnyMissingItemInfo(items) then
            self:ScheduleTimer(doPrime, 0.5) -- run 3 times, 0.5s apart
        else
            if onDone then onDone() end
        end
    end
    doPrime()
end





-- one-shot listener state
mod._itemInfoListening = false
mod._itemInfoTries = 0
local MAX_ITEMINFO_TRIES = 10

function mod:StartItemInfoListener()
    if self._itemInfoListening then return end
    self._itemInfoListening = true
    self._itemInfoTries = 0
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end

function mod:StopItemInfoListener()
    if not self._itemInfoListening then return end
    self._itemInfoListening = false
    self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
end

function mod:GET_ITEM_INFO_RECEIVED(_, _itemID, _ok)
    -- If viewer hidden, stop immediately
    if not (self.viewer and self.viewer:IsShown()) then
        self:StopItemInfoListener()
        return
    end

    -- If we have items stored, see if any are still missing
    local missing = false
    if self.currentItems then
        for i = 1, #self.currentItems do
            local id = self.currentItems[i].id
            local n, _, _, _, _, _, _, _, _, ic = GetItemInfo(id)
            if not (n and ic) then missing = true; break end
        end
    end

    -- Light repaint (don’t clear children)
    self:RefreshList(true)

    if missing then
        self._itemInfoTries = (self._itemInfoTries or 0) + 1
        if self._itemInfoTries <= 8 and self.currentItems then
            PrimeItemInfoCache(self.currentItems) -- gently re-poke
        else
            self:StopItemInfoListener()
        end
    else
        self:StopItemInfoListener()
    end
end



-- Layout constants
local ITEM_SIZE    = addon.ITEM_SIZE or 37
local ITEM_SPACING = addon.ITEM_SPACING or 4
local NUM_COLS     = 10
local VIEW_W       = 480
local VIEW_H       = 600

------------------------------------------------------------
-- Wrath-safe quality border
------------------------------------------------------------
local function SafeSetItemButtonQuality(btn, quality)
    local border = btn.IconBorder
    if not border then return end
    if not quality or quality < 2 then
        border:Hide()
        return
    end
    local r, g, b = GetItemQualityColor(quality)
    border:SetVertexColor(r, g, b)
    border:Show()
end

------------------------------------------------------------
-- Utilities
------------------------------------------------------------
local function GetRealmCharacters()
    local list, realm = {}, GetRealmName()
    local me = UnitName("player")
    local chars = (addon.db and addon.db.realm and addon.db.realm.characters) or {}
    for key, data in pairs(chars) do
        local name, r = key:match("^(.-) %- (.+)$")
        if r == realm and name and name ~= me then
            table.insert(list, { key = key, name = name, class = data.class })
        end
    end
    table.sort(list, function(a,b) return a.name < b.name end)
    return list
end


-- Fallback: pick the first saved char on this realm if dropdown is empty
local function FirstCharOnRealmKey()
    local realm = GetRealmName()
    local chars = (addon.db and addon.db.realm and addon.db.realm.characters) or {}
    for key, _ in pairs(chars) do
        local name, r = key:match("^(.-) %- (.+)$")
        if r == realm then
            return key
        end
    end
    return nil
end




local function BuildSortedItemList(src)
    local t, needInfo = {}, false
    for itemID, count in pairs(src or {}) do
        if count and count > 0 then
            local name, link, quality, iLevel, _, _, _, _, _, icon = GetItemInfo(itemID)
            if (not name) or (not icon) then needInfo = true end
            table.insert(t, {
                id=itemID, count=count or 1,
                quality=quality or 1, level=iLevel or 0,
                icon=icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                name=name or ("Item "..tostring(itemID)),
                link=link or ("item:"..tostring(itemID)),
            })
        end
    end
    table.sort(t, function(a,b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.level   ~= b.level   then return a.level   > b.level   end
        return a.name < b.name
    end)
    return t, needInfo
end



------------------------------------------------------------
-- Viewer frame creation
------------------------------------------------------------
function mod:CreateViewer()
    if self.viewer then return end

    local f = CreateFrame("Frame", "LanceBagsAltViewer", UIParent); f:SetSize(VIEW_W, VIEW_H); f:SetPoint("CENTER")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 }}); f:SetBackdropColor(0,0,0,0.9)
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge"); title:SetPoint("TOP", 0, -12); title:SetText(L["Alt Inventory"]); f.title = title
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -6, -6)
    
    local dd = CreateFrame("Frame", "LanceBagsAltViewerDropdown", f, "UIDropDownMenuTemplate"); dd:SetPoint("TOPLEFT", 12, -36); f.dropdown = dd
    local refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); refresh:SetSize(70, 22); refresh:SetText(L["Refresh"]); refresh:SetScript("OnClick", function() mod:RefreshList() end); f.refresh = refresh
    
	local toggle = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	toggle:SetSize(100, 22)
	toggle:SetText(L["Show Bank"])
	toggle:SetScript("OnClick", function()
		mod.state.viewBank = not mod.state.viewBank
		toggle:SetText(mod.state.viewBank and L["Show Bags"] or L["Show Bank"])

		-- NEW: Preload icons before switching views
		local chars = (addon.db and addon.db.realm and addon.db.realm.characters) or {}
		local data  = chars[mod.state.selectedKey]
		if not data then
			mod:RefreshList()
			return
		end

		local srcMap = mod.state.viewBank and data.bank or data.bags
		mod:PrimeItemsBeforeDisplay(srcMap, function()
			mod:RefreshList()
		end)
	end)
	f.toggle = toggle

    
    toggle:SetPoint("TOPRIGHT", -12, -36); refresh:SetPoint("RIGHT", toggle, "LEFT", -5, 0)
    
    local scroll = CreateFrame("ScrollFrame", "LanceBagsAltViewerScroll", f, "UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT", 16, -70); scroll:SetPoint("BOTTOMRIGHT", -28, 16)
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(1,1); scroll:SetScrollChild(content); f.content = content; f.scroll  = scroll
    self.viewer = f
	
	f:SetScript("OnShow", function()
		mod:RefreshList()
	end)

end

------------------------------------------------------------
-- Dropdown
------------------------------------------------------------
function mod:RebuildDropdown()
    if not self.viewer then return end
    local f = self.viewer; local list = GetRealmCharacters()
    
	local function Select(key, text)
		mod.state.selectedKey = key
		UIDropDownMenu_SetSelectedValue(f.dropdown, key)
		UIDropDownMenu_SetText(f.dropdown, text)

		-- Preload icons for the newly selected character BEFORE drawing
		local chars = (addon.db and addon.db.realm and addon.db.realm.characters) or {}
		local data  = chars[mod.state.selectedKey]
		if not data then
			mod:RefreshList()
			return
		end

		local srcMap = mod.state.viewBank and data.bank or data.bags
		mod:PrimeItemsBeforeDisplay(srcMap, function()
			mod:RefreshList()
			if mod.viewer and mod.viewer.scroll then
				mod.viewer.scroll:UpdateScrollChildRect()
			end
		end)
	end

	
    UIDropDownMenu_Initialize(f.dropdown, function(_, level)
        if level ~= 1 then return end
        if #list == 0 then local i=UIDropDownMenu_CreateInfo(); i.text=L["No other characters on this realm."]; i.disabled=true; i.notCheckable=true; UIDropDownMenu_AddButton(i, level); return end
        for _, c in ipairs(list) do local col=RAID_CLASS_COLORS[c.class] or {r=1,g=1,b=1}; local n=string.format("|cff%02x%02x%02x%s|r",col.r*255,col.g*255,col.b*255,c.name); local i=UIDropDownMenu_CreateInfo(); i.text=n; i.value=c.key; i.func=function() Select(c.key,n) end; i.checked=(mod.state.selectedKey==c.key); UIDropDownMenu_AddButton(i, level) end
    end)
end

------------------------------------------------------------
-- Grid refresh
------------------------------------------------------------
function mod:RefreshList()
    if not self.viewer then return end
    local f = self.viewer

    -- NEW: ensure we have a selectedKey on first open
    if not self.state.selectedKey then
        local list = GetRealmCharacters()
        if list and list[1] then
            self.state.selectedKey = list[1].key
        end
    end

    for _, child in ipairs({ f.content:GetChildren() }) do
        child:Hide(); child:SetParent(nil)
    end
    
    local chars = (addon.db and addon.db.realm and addon.db.realm.characters) or {}; local data  = chars[self.state.selectedKey]
    if not data then
        local msg = f.content:CreateFontString(nil, "ARTWORK", "GameFontDisable"); msg:SetPoint("TOPLEFT", 0, 0); msg:SetText(L["No data for this character yet. Log into them once."]); f.content:SetSize(300, 20); return
    end

    local srcMap = self.state.viewBank and data.bank or data.bags
    
    -- ## FIX ## Add a check for an empty bag/bank and show a message.
    if not srcMap or not next(srcMap) then
        local msg = f.content:CreateFontString(nil, "ARTWORK", "GameFontNormal"); msg:SetPoint("TOPLEFT", 10, -10)
        msg:SetText(self.state.viewBank and L["This character's bank is empty."] or L["This character's bags are empty."])
        f.content:SetSize(300, 20); return
    end

    local items, needInfo = BuildSortedItemList(srcMap)
	self.currentItems = items  -- store items so we can recheck them when info arrives
			
	if needInfo then
		PrimeItemInfoCache(items)
		self:StartItemInfoListener()
		self:StartPrimeRepeater()      -- NEW: run 3 short passes to fill stubborn icons
	end


    local used = #items
    local function gridPoint(idx) local r=math.floor((idx-1)/NUM_COLS); local c=(idx-1)%NUM_COLS; return c*(ITEM_SIZE+ITEM_SPACING), -r*(ITEM_SIZE+ITEM_SPACING) end
    local function acquireSlot(name) local b=_G[name]; if not b then b=CreateFrame("Button",name,f.content,"ContainerFrameItemButtonTemplate") else b:SetParent(f.content);b:Show() end; b:SetSize(ITEM_SIZE,ITEM_SIZE); return b end

    for idx, item in ipairs(items) do
        local gI=idx; local n="LanceBagsAltItem"..gI; local b=acquireSlot(n); local x,y=gridPoint(gI)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",x,y); SetItemButtonTexture(b,item.icon); SetItemButtonCount(b,item.count or 1); SafeSetItemButtonQuality(b,item.quality)
        b:RegisterForClicks(); b:SetScript("OnEnter",function(s) GameTooltip:SetOwner(s,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(item.link); GameTooltip:Show() end); b:SetScript("OnLeave",function() GameTooltip:Hide() end); b.UpdateTooltip=b:GetScript("OnEnter")
    end

    local totalCells = used; local rows = math.max(1, math.ceil(totalCells/NUM_COLS)); f.content:SetSize(NUM_COLS*(ITEM_SIZE+ITEM_SPACING), rows*(ITEM_SIZE+ITEM_SPACING))

	if self.viewer and self.viewer.scroll then
		self.viewer.scroll:UpdateScrollChildRect()
	end

end

------------------------------------------------------------
-- Module Lifecycle & Main Functions
------------------------------------------------------------
function mod:OnEnable()
    self:CreateViewer(); self.viewer:Hide()
    if addon.HookBagFrameCreation then addon:HookBagFrameCreation(self, "OnBagFrameCreated") end
    if addon.IterateBags then for _, bag in addon:IterateBags() do if bag and bag.HasFrame and bag:HasFrame() then self:OnBagFrameCreated(bag) end end end
end

function mod:OnDisable()
    if self.button then self.button:Hide() end
    if self.viewer then self.viewer:Hide() end
end

function mod:OnBagFrameCreated(bag)
    if bag.bagName ~= "Backpack" then return end
    local frame = bag:GetFrame()
    if not frame or self.button then return end

    local btn = CreateFrame("Button", addonName.."AltViewerButton",
        frame, "UIPanelButtonTemplate")
    btn:SetSize(40, 20)
    btn:SetText("|cffC7C7CFALTS|r")
    btn:SetNormalFontObject("GameFontNormalSmall")

    -- ## FIX ## Changed the order number from 48 to 20.
    -- This will correctly place it to the left of the JUNK button (order 30).
    if frame.AddBottomWidget then
        frame:AddBottomWidget(btn, "RIGHT", 20, 20)
    else
        btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -120, 8)
    end

    if addon.SetupTooltip then
        addon.SetupTooltip(btn, L["Alt Inventory"],
            L["Click to view the inventory of your other characters."])
    else
        btn:SetScript("OnEnter", function(selfBtn)
            GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
            GameTooltip:SetText(L["Alt Inventory"])
            GameTooltip:AddLine(L["Click to view the inventory of your other characters."],
                1,1,1, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    btn:SetScript("OnClick", function() mod:ToggleViewer() end)
    self.button = btn
end

function mod:ToggleViewer()
    if not self.viewer then self:CreateViewer() end
    if self.viewer:IsShown() then
        self.viewer:Hide()
		self:StopPrimeRepeater()
    else
        -- Ensure a valid selectedKey BEFORE we rebuild and refresh
        local list = GetRealmCharacters()
        if not self.state.selectedKey then
            -- Prefer first from filtered list, else first character on this realm
            if list[1] then
                self.state.selectedKey = list[1].key
            else
                self.state.selectedKey = FirstCharOnRealmKey()
            end
        end

        self:RebuildDropdown()

        -- Set dropdown display text if we resolved a key
        if self.state.selectedKey then
            for _, c in ipairs(list) do
                if c.key == self.state.selectedKey then
                    local col = RAID_CLASS_COLORS[c.class] or {r=1,g=1,b=1}
                    local nameC = string.format("|cff%02x%02x%02x%s|r", col.r*255, col.g*255, col.b*255, c.name)
                    UIDropDownMenu_SetText(self.viewer.dropdown, nameC)
                    break
                end
            end
        end

        -- Preload item info before showing viewer
		local chars = (addon.db and addon.db.realm and addon.db.realm.characters) or {}
		local data  = chars[self.state.selectedKey]
		if not data then
			self:RefreshList()
			self.viewer.scroll:UpdateScrollChildRect()
			self.viewer:Show()
			return
		end

local srcMap = self.state.viewBank and data.bank or data.bags

self:PrimeItemsBeforeDisplay(srcMap, function()
    -- Once priming loop finishes, draw and show the viewer
    self:RefreshList()
    self.viewer.scroll:UpdateScrollChildRect()
    self.viewer:Show()
end)


		-- NEW: one-shot delayed refresh to catch late item/cache availability on first open
		if self.ScheduleTimer then
			self:ScheduleTimer(function()
				if self.viewer and self.viewer:IsShown() then
					self:RefreshList()
				end
			end, 0.10) -- 0.10s is enough; safe on 3.3.5 with AceTimer
		end

		
    end
end
