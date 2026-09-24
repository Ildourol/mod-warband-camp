-- WarbandCamp/UI/MainFrame.lua
-- Movable parent window: header, left tab rail ("left menu"), content area
-- (each tab hangs its own content inside), and a footer with manual command bar.

local addonName, WBC = ...

local FRAME_W, FRAME_H = 900, 560
local HEADER_H = 32
local RAIL_W   = 120
local FOOTER_H = 22

WBC.tabs = {}   -- { id, label, builder, onShow, button, contentFrame }

function WBC.RegisterTab(def) table.insert(WBC.tabs, def) end

local function selectTab(index)
    local tabs = WBC.tabs
    if not tabs[index] then return end
    for i, tab in ipairs(tabs) do
        if tab.button then
            if i == index then
                tab.button.bg:SetTexture(0.10, 0.30, 0.40, 0.95)
                tab.button.sel:Show()
                tab.button.label:SetTextColor(1, 0.82, 0.30)
            else
                tab.button.bg:SetTexture(0, 0, 0, 0)
                tab.button.sel:Hide()
                tab.button.label:SetTextColor(0.85, 0.85, 0.88)
            end
        end
        if tab.contentFrame then
            if i == index then tab.contentFrame:Show() else tab.contentFrame:Hide() end
        end
    end
    if tabs[index].onShow then pcall(tabs[index].onShow) end
    if WBC.db then WBC.db.activeTab = index end
end
WBC.SelectTab = selectTab

function WBC.SelectTabById(id)
    for i, tab in ipairs(WBC.tabs) do
        if tab.id == id then selectTab(i); return i end
    end
end

local function buildRail(main)
    local rail = CreateFrame("Frame", nil, main)
    rail:SetPoint("TOPLEFT", main, "TOPLEFT", 6, -HEADER_H - 4)
    rail:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 6, FOOTER_H + 4)
    rail:SetWidth(RAIL_W)
    WBC.ApplyBackdrop(rail, "inset", 0.5, 0.02, 0.03, 0.05)
    main.rail = rail
    return rail
end

local function buildAllTabs()
    local main = WarbandCamp_MainFrame
    local rail = main.rail

    local content = CreateFrame("Frame", nil, main)
    content:SetPoint("TOPLEFT", rail, "TOPRIGHT", 8, 0)
    content:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -8, FOOTER_H + 4)
    main.contentArea = content

    local prev
    for i, tab in ipairs(WBC.tabs) do
        local label = tab.label
        local btn = WBC.MakeFlatButton(rail, RAIL_W - 12, 30, label, { padLeft = 10, font = "GameFontNormal" })
        btn.bg:SetTexture(0, 0, 0, 0)

        -- Left selection accent bar (shown only on the active tab).
        local sel = btn:CreateTexture(nil, "OVERLAY")
        sel:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 0)
        sel:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", -2, 0)
        sel:SetWidth(3)
        sel:SetTexture(1, 0.79, 0.30, 1)
        sel:Hide()
        btn.sel = sel

        if prev then btn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
        else btn:SetPoint("TOPLEFT", rail, "TOPLEFT", 6, -6) end
        btn:SetID(i)
        btn:SetScript("OnClick", function(self) selectTab(self:GetID()) end)
        tab.button = btn
        prev = btn

        local cf = CreateFrame("Frame", nil, content)
        cf:SetAllPoints(content)
        cf:Hide()
        tab.contentFrame = cf
        if tab.builder then
            local ok, err = pcall(tab.builder, cf)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555WarbandCamp tab '" .. tostring(tab.label) .. "' build error:|r " .. tostring(err))
            end
        end
    end

    selectTab((WBC.db and WBC.db.activeTab) or 1)
end

function WBC.RestoreMainFramePosition()
    if WarbandCamp_MainFrame then
        WBC.RestoreFramePoint(WarbandCamp_MainFrame, "frame", WBC.defaults.frame)
    end
end

local function createMainFrame()
    local f = CreateFrame("Frame", "WarbandCamp_MainFrame", UIParent)
    _G.QOLAddon_MainFrame = f   -- compatibility alias
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); WBC.SaveFramePoint(self, "frame") end)
    f:SetScript("OnShow", function() if WBC.db and WBC.db.frame then WBC.db.frame.shown = true end end)
    f:SetScript("OnHide", function() if WBC.db and WBC.db.frame then WBC.db.frame.shown = false end end)
    WBC.ApplyBackdrop(f, "panel", 0.95)

    -- Header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    header:SetHeight(HEADER_H)
    WBC.ApplyBackdrop(header, "inset", 0.6, 0.06, 0.09, 0.12)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", header, "LEFT", 12, 0)
    title:SetText(WBC.colors.brand .. "Warband Camp" .. WBC.colors.reset ..
        "  " .. WBC.colors.muted .. "v" .. WBC.version .. WBC.colors.reset)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", header, "RIGHT", 2, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Current-target readout
    local targetFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetFS:SetPoint("RIGHT", close, "LEFT", -10, 0)
    local function updateTarget()
        local n = UnitName("target")
        if n and n ~= "" then
            targetFS:SetText(WBC.colors.muted .. "Target: " .. WBC.colors.reset .. WBC.colors.accent .. n .. WBC.colors.reset)
        else
            targetFS:SetText(WBC.colors.muted .. "No target" .. WBC.colors.reset)
        end
    end
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:SetScript("OnEvent", updateTarget)
    f:HookScript("OnShow", updateTarget)
    f.header = header

    -- Footer: command-category legend & manual command bar
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 4)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 4)
    footer:SetHeight(FOOTER_H)
    local legend = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legend:SetPoint("LEFT", footer, "LEFT", 4, 0)
    legend:SetText(WBC.cats.player.color .. WBC.cats.player.name .. WBC.colors.reset)

    -- Manual command bar (run any dot-command directly)
    local runBtn = WBC.MakeFlatButton(footer, 50, FOOTER_H - 2, "Send", { justify = "CENTER" })
    runBtn:SetPoint("RIGHT", footer, "RIGHT", -2, 0)

    local cmdBox = WBC.MakeFlatEditBox(footer, 420, FOOTER_H - 2, "Manual command (.camp, .gomove...)")
    cmdBox:SetPoint("RIGHT", runBtn, "LEFT", -6, 0)

    local function runManualCommand()
        local text = WBC.Trim(cmdBox:GetText() or "")
        if text == "" then return end
        WBC.RunCommand(text)
        cmdBox:SetText("")
        if cmdBox.refreshHint then cmdBox.refreshHint() end
    end

    cmdBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        runManualCommand()
    end)
    cmdBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    cmdBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Manual Command Bar", 1, 0.82, 0.30)
        GameTooltip:AddLine("Type any server command (e.g. .camp ..., .gomove ...) directly from Warband Camp.", 1, 1, 1, true)
        GameTooltip:AddLine("Press Enter or click Send to execute.", 0.6, 0.8, 1, true)
        GameTooltip:Show()
    end)
    cmdBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    runBtn:SetScript("OnClick", runManualCommand)

    f.tabRail = buildRail(f)
    f:Hide()
    return f
end

WBC.AddLogin(function()
    if not WarbandCamp_MainFrame then createMainFrame() end
    WBC.RestoreMainFramePosition()
    buildAllTabs()
    if WBC.db and WBC.db.frame and WBC.db.frame.shown then WarbandCamp_MainFrame:Show() end
end)

-- Create the shell early so tab files can reference it; surface load errors.
local ok, err = pcall(createMainFrame)
if not ok then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000WarbandCamp MainFrame ERROR:|r " .. tostring(err))
    WBC._mainFrameLoadError = tostring(err)
end
