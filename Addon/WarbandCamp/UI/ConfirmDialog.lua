-- WarbandCamp/UI/ConfirmDialog.lua
-- Self-contained custom confirmation dialog for dangerous commands.
-- Avoids touching Blizzard's StaticPopupDialogs table to guarantee 0 UI taint on 3.3.5a.

local addonName, WBC = ...

local dialogFrame

local function getDialog()
    if dialogFrame then return dialogFrame end

    local f = CreateFrame("Frame", "WarbandCamp_ConfirmDialog", UIParent)
    f:SetSize(400, 160)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    WBC.ApplyBackdrop(f, "panel", 0.98, 0.05, 0.06, 0.09)

    -- Header / Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("|cffffc94dWarband Camp|r")
    f.title = title

    -- Body Message
    local msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    msg:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -38)
    msg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 44)
    msg:SetJustifyH("CENTER")
    msg:SetJustifyV("MIDDLE")
    f.msg = msg

    -- Accept button
    local btnAccept = WBC.MakeFlatButton(f, 130, 24, "Accept", { justify = "CENTER", danger = true })
    btnAccept:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 45, 14)
    btnAccept:SetScript("OnClick", function()
        f:Hide()
        if f.onAccept then
            pcall(f.onAccept)
        end
    end)
    f.btnAccept = btnAccept

    -- Cancel button
    local btnCancel = WBC.MakeFlatButton(f, 130, 24, "Cancel", { justify = "CENTER" })
    btnCancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -45, 14)
    btnCancel:SetScript("OnClick", function()
        f:Hide()
    end)
    f.btnCancel = btnCancel

    dialogFrame = f
    return dialogFrame
end

function WBC.ShowConfirm(text, onAccept, acceptText, cancelText)
    local d = getDialog()
    d.msg:SetText(text)
    d.onAccept = onAccept
    d.btnAccept.label:SetText(acceptText or "Accept")
    d.btnCancel.label:SetText(cancelText or "Cancel")
    d:Show()
    d:Raise()
end

-- Compatibility shims so nothing breaks if anything checks StaticPopupDialogs
StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["WARBAND_CONFIRM_CMD"] = {
    text = "Run this command?",
    button1 = YES, button2 = NO,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
StaticPopupDialogs["WARBAND_CONFIRM_CAMP_LEAVE"] = StaticPopupDialogs["WARBAND_CONFIRM_CMD"]
StaticPopupDialogs["QOL_CONFIRM_CMD"] = StaticPopupDialogs["WARBAND_CONFIRM_CMD"]
StaticPopupDialogs["QOL_CONFIRM_CAMP_LEAVE"] = StaticPopupDialogs["WARBAND_CONFIRM_CMD"]
