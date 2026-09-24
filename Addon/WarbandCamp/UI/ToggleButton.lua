-- WarbandCamp/UI/ToggleButton.lua
-- Draggable launcher button with campfire icon. Click -> toggle panel. SHIFT-drag -> reposition.

local addonName, WBC = ...

local SIZE = 32

function WBC.Toggle()
    local f = WarbandCamp_MainFrame
    if not f then
        WBC.Warn("main frame not created - run /wb debug.")
        return
    end
    if f:IsShown() then f:Hide() else f:Show(); f:Raise() end
end

local function createToggleButton()
    local b = CreateFrame("Button", "WarbandCamp_ToggleButton", UIParent)
    _G.QOLAddon_ToggleButton = b   -- compatibility alias
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    -- Default anchor before restore
    b:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -28, -120)

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(25, 25)
    bg:SetPoint("CENTER", b, "CENTER", 0, 0)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\Spell_Fire_Fire")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("CENTER", b, "CENTER", 11, -11)

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    b:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then self:StartMoving(); self.isMoving = true end
    end)
    b:SetScript("OnDragStop", function(self)
        if self.isMoving then
            self:StopMovingOrSizing(); self.isMoving = false
            WBC.SaveFramePoint(self, "button")
        end
    end)
    b:SetScript("OnClick", function() WBC.Toggle() end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Warband Camp", 1, 0.79, 0.30)
        GameTooltip:AddLine("Click to toggle the camp and builder panel.", 1, 1, 1)
        GameTooltip:AddLine("Manage your camp, place props, and build in 3D.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("SHIFT-drag to move this button.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("/wb reset to recenter everything.", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    b:Show()
    return b
end

function WBC.RestoreButtonPosition()
    if WarbandCamp_ToggleButton then
        WBC.RestoreFramePoint(WarbandCamp_ToggleButton, "button", WBC.defaults.button)
        if WBC.db and WBC.db.minimap and WBC.db.minimap.hide then
            WarbandCamp_ToggleButton:Hide()
        else
            WarbandCamp_ToggleButton:Show()
        end
    end
end

WBC.AddLogin(function()
    if not WarbandCamp_ToggleButton then createToggleButton() end
    WBC.RestoreButtonPosition()
end)
