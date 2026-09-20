-- QOLAddon/UI/MainFrame.lua
-- Movable parent window: header, left tab rail ("left menu"), content area
-- (each tab hangs its own "top tabs" inside), and a footer legend.

local addonName, QOL = ...

local FRAME_W, FRAME_H = 900, 560
local HEADER_H = 32
local RAIL_W   = 120
local FOOTER_H = 22

QOL.tabs = {}   -- { id, label, builder, onShow, button, contentFrame }

function QOL.RegisterTab(def) table.insert(QOL.tabs, def) end

local function selectTab(index)
    local tabs = QOL.tabs
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
    if QOL.db then QOL.db.activeTab = index end
end
QOL.SelectTab = selectTab

function QOL.SelectTabById(id)
    for i, tab in ipairs(QOL.tabs) do
        if tab.id == id then selectTab(i); return i end
    end
end

local function buildRail(main)
    local rail = CreateFrame("Frame", nil, main)
    rail:SetPoint("TOPLEFT", main, "TOPLEFT", 6, -HEADER_H - 4)
    rail:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 6, FOOTER_H + 4)
    rail:SetWidth(RAIL_W)
    QOL.ApplyBackdrop(rail, "inset", 0.5, 0.02, 0.03, 0.05)
    main.rail = rail
    return rail
end

local function buildAllTabs()
    local main = QOLAddon_MainFrame
    local rail = main.rail

    local content = CreateFrame("Frame", nil, main)
    content:SetPoint("TOPLEFT", rail, "TOPRIGHT", 8, 0)
    content:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -8, FOOTER_H + 4)
    main.contentArea = content

    local prev
    for i, tab in ipairs(QOL.tabs) do
        local label = tab.label
        local btn = QOL.MakeFlatButton(rail, RAIL_W - 12, 30, label, { padLeft = 10, font = "GameFontNormal" })
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
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555QOL tab '" .. tostring(tab.label) .. "' build error:|r " .. tostring(err))
            end
        end
    end

    selectTab((QOL.db and QOL.db.activeTab) or 1)
end

function QOL.RestoreMainFramePosition()
    if QOLAddon_MainFrame then
        QOL.RestoreFramePoint(QOLAddon_MainFrame, "frame", QOL.defaults.frame)
    end
end

local function createMainFrame()
    local f = CreateFrame("Frame", "QOLAddon_MainFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); QOL.SaveFramePoint(self, "frame") end)
    f:SetScript("OnShow", function() if QOL.db and QOL.db.frame then QOL.db.frame.shown = true end end)
    f:SetScript("OnHide", function() if QOL.db and QOL.db.frame then QOL.db.frame.shown = false end end)
    QOL.ApplyBackdrop(f, "panel", 0.95)

    -- Header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    header:SetHeight(HEADER_H)
    QOL.ApplyBackdrop(header, "inset", 0.6, 0.06, 0.09, 0.12)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", header, "LEFT", 12, 0)
    title:SetText(QOL.colors.brand .. "QOL" .. QOL.colors.reset .. " " ..
        QOL.colors.white .. "Addon" .. QOL.colors.reset ..
        "  " .. QOL.colors.muted .. "v" .. QOL.version .. QOL.colors.reset)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", header, "RIGHT", 2, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Current-target readout
    local targetFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetFS:SetPoint("RIGHT", close, "LEFT", -10, 0)
    local function updateTarget()
        local n = UnitName("target")
        if n and n ~= "" then
            targetFS:SetText(QOL.colors.muted .. "Target: " .. QOL.colors.reset .. QOL.colors.accent .. n .. QOL.colors.reset)
        else
            targetFS:SetText(QOL.colors.muted .. "No target" .. QOL.colors.reset)
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
    legend:SetText(
        QOL.cats.player.color .. QOL.cats.player.name .. QOL.colors.reset .. "   " ..
        QOL.cats.bot.color    .. QOL.cats.bot.name    .. QOL.colors.reset)

    -- Manual command bar (run any dot-command or bot-order directly)
    local runBtn = QOL.MakeFlatButton(footer, 50, FOOTER_H - 2, "Send", { justify = "CENTER" })
    runBtn:SetPoint("RIGHT", footer, "RIGHT", -2, 0)

    local cmdBox = QOL.MakeFlatEditBox(footer, 420, FOOTER_H - 2, "Manual command (.camp, .playerbots, $order...)")
    cmdBox:SetPoint("RIGHT", runBtn, "LEFT", -6, 0)

    local function runManualCommand()
        local text = QOL.Trim(cmdBox:GetText() or "")
        if text == "" then return end
        if text:sub(1, 1) == "$" then
            QOL.RunBotOrder(text:sub(2))
        else
            QOL.RunCommand(text)
        end
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
        GameTooltip:AddLine("Type any server command (e.g. .camp ..., .clear ...) or bot order ($...) directly from QOLAddon.", 1, 1, 1, true)
        GameTooltip:AddLine("Press Enter or click Send to execute.", 0.6, 0.8, 1, true)
        GameTooltip:Show()
    end)
    cmdBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    runBtn:SetScript("OnClick", runManualCommand)

    f.tabRail = buildRail(f)
    f:Hide()
    return f
end

QOL.AddLogin(function()
    if not QOLAddon_MainFrame then createMainFrame() end
    QOL.RestoreMainFramePosition()
    buildAllTabs()
    if QOL.db and QOL.db.frame and QOL.db.frame.shown then QOLAddon_MainFrame:Show() end
end)

-- Create the shell early so tab files can reference it; surface load errors.
local ok, err = pcall(createMainFrame)
if not ok then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000QOL MainFrame ERROR:|r " .. tostring(err))
    QOL._mainFrameLoadError = tostring(err)
end
