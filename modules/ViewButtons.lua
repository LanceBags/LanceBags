local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule("ViewButtons", "AceEvent-3.0")

-- Store references to ALL created buttons and their parent frames
local createdButtons = {}

-- This helper function updates a button's appearance. It doesn't need any changes.
local function UpdateToggleButton(btn, frame)
    local viewMode = addon.db.profile.viewMode

    -- Set button text to reflect the CURRENT view
    if viewMode == "category" then
        btn:SetText("Cat")
        addon.SetupTooltip(btn, { L["Category View"], L["Click to cycle view mode."] }, "ANCHOR_BOTTOM", 0, -8)
    elseif viewMode == "bag" then
        btn:SetText("Bag")
        addon.SetupTooltip(btn, { L["Bag View"], L["Click to cycle view mode."] }, "ANCHOR_BOTTOM", 0, -8)
    else -- "onebag"
        btn:SetText("One")
        addon.SetupTooltip(btn, { L["One Bag View"], L["Click to cycle view mode."] }, "ANCHOR_BOTTOM", 0, -8)
    end

    -- Show the physical bag slots ONLY when in Bag view
    if viewMode == "bag" then
        if frame.BagSlotPanel then frame.BagSlotPanel:Show() end
    else
        if frame.BagSlotPanel then frame.BagSlotPanel:Hide() end
    end
end

function mod:OnEnable()
    -- This message listener now updates every button in our list
    self:RegisterMessage("LanceBags_ViewModeChanged", function()
        for _, data in ipairs(createdButtons) do
            UpdateToggleButton(data.button, data.frame)
        end
    end)
    addon:HookBagFrameCreation(self, "OnBagFrameCreated")
end

function mod:OnBagFrameCreated(bag)
    -- Apply to Backpack and Bank
    if bag.bagName ~= "Backpack" and bag.bagName ~= "Bank" then return end
    local frame = bag:GetFrame()
    if not frame or not frame.HeaderRightRegion then return end

    -- Create a new local button for this specific frame
    local toggleBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    toggleBtn:SetSize(40, 20)
    
    -- Click handler: Calls our central function to cycle the view mode
    toggleBtn:SetScript("OnClick", function()
        addon:CycleViewMode()
    end)

    -- Place the button using the AddWidget call
    frame.HeaderRightRegion:AddWidget(toggleBtn, -10, 40, 0, 0)
    
    -- Set the initial appearance of the button
    UpdateToggleButton(toggleBtn, frame)
    
    -- Add the new button and its frame to our list to keep track of it
    table.insert(createdButtons, { button = toggleBtn, frame = frame })

    frame.viewToggleBtn = toggleBtn
end