-- QOLAddon/UI/ToggleButton.lua
-- Draggable launcher button. Click → toggle panel. SHIFT-drag → reposition.

local addonName, QOL = ...

local SIZE = 32

function QOL.Toggle()
    local f = QOLAddon_MainFrame
    if not f then
        QOL.Warn("main frame not created - run /qol debug.")
        return
    end
    if f:IsShown() then f:Hide() else f:Show(); f:Raise() end
end

local function createToggleButton()
    local b = CreateFrame("Button", "QOLAddon_ToggleButton", UIParent)
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if icon.SetMask then icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end

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
            QOL.SaveFramePoint(self, "button")
        end
    end)
    b:SetScript("OnClick", function() QOL.Toggle() end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("QOL Addon", 1, 0.79, 0.30)
        GameTooltip:AddLine("Click to toggle the player panel.", 1, 1, 1)
        GameTooltip:AddLine("Build & command your bot party, set roles,", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("run dungeons, and manage your Warband Camp.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("SHIFT-drag to move this button.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("/qol reset to recenter everything.", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    b:Show()
    return b
end

function QOL.RestoreButtonPosition()
    if QOLAddon_ToggleButton then
        QOL.RestoreFramePoint(QOLAddon_ToggleButton, "button", QOL.defaults.button)
    end
end

QOL.AddLogin(function()
    if not QOLAddon_ToggleButton then createToggleButton() end
    QOL.RestoreButtonPosition()
    if QOL.db and QOL.db.minimap and QOL.db.minimap.hide then
        QOLAddon_ToggleButton:Hide()
    end
end)
