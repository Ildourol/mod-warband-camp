-- QOLAddon/UI/Widgets.lua
-- Reusable UI factories used by tabs. Built from lightweight, single-
-- texture widgets so tabs stack rows smoothly.

local addonName, QOL = ...

local ROW_HEIGHT  = 26
local ROW_SPACING = 4
local LABEL_WIDTH = 168
local INPUT_WIDTH = 104
local PIP_WIDTH   = 6

-- ─── Backdrops ─────────────────────────────────────────────────────────────
QOL.backdrops = {
    panel = {
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    },
    inset = {
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
}

function QOL.ApplyBackdrop(frame, kind, bgAlpha, r, g, b)
    frame:SetBackdrop(QOL.backdrops[kind or "panel"])
    frame:SetBackdropColor(r or 0.04, g or 0.05, b or 0.07, bgAlpha or 0.92)
    frame:SetBackdropBorderColor(0.30, 0.45, 0.55, 1)
end

-- ─── Section header ────────────────────────────────────────────────────────
function QOL.CreateSectionHeader(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetText(QOL.colors.label .. text .. QOL.colors.reset)
    return fs
end

-- ─── Flat widget factories ─────────────────────────────────────────────────
function QOL.MakeFlatButton(parent, w, h, text, opts)
    opts = opts or {}
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetTexture(0.13, 0.15, 0.19, 0.95)
    b.bg = bg

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture(1, 1, 1, 0.16)

    local fs = b:CreateFontString(nil, "OVERLAY", opts.font or "GameFontNormalSmall")
    fs:SetPoint("LEFT", b, "LEFT", opts.padLeft or 6, 0)
    fs:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    fs:SetJustifyH(opts.justify or "LEFT")
    fs:SetText(text)
    if opts.danger then fs:SetTextColor(1, 0.45, 0.45) end
    b:SetFontString(fs)
    b.label = fs
    return b
end

local function makeFlatEditBox(parent, w, h, placeholder, isNumeric)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(w, h)
    e:SetFontObject(GameFontHighlightSmall)
    e:SetTextColor(1, 1, 1, 1)
    e:SetTextInsets(6, 6, 0, 0)
    e:SetAutoFocus(false)
    e:SetMaxLetters(isNumeric and 14 or 96)

    local bg = e:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(e)
    bg:SetTexture(0, 0, 0, 0.55)

    local border = e:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", e, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", 1, -1)
    border:SetTexture(0.25, 0.35, 0.42, 0.7)
    bg:SetDrawLayer("BACKGROUND", 1)

    if placeholder then
        local hint = e:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        hint:SetPoint("LEFT", e, "LEFT", 6, 0)
        hint:SetText(placeholder)
        e.hint = hint
        local function refresh()
            if e:GetText() == "" and not e:HasFocus() then hint:Show() else hint:Hide() end
        end
        e.refreshHint = refresh
        e:HookScript("OnTextChanged", refresh)
        e:HookScript("OnEditFocusGained", refresh)
        e:HookScript("OnEditFocusLost", refresh)
    end
    return e
end
QOL.MakeFlatEditBox = makeFlatEditBox

-- ─── Flat dropdown (choice) ────────────────────────────────────────────────
local openChoiceMenu, choiceCloser
local function closeChoiceMenu()
    if openChoiceMenu then openChoiceMenu:Hide() end
    openChoiceMenu = nil
    if choiceCloser then choiceCloser:Hide() end
end
QOL.CloseChoiceMenu = closeChoiceMenu

local function ensureCloser()
    if choiceCloser then return choiceCloser end
    choiceCloser = CreateFrame("Button", nil, UIParent)
    choiceCloser:SetAllPoints(UIParent)
    choiceCloser:SetFrameStrata("FULLSCREEN")
    choiceCloser:Hide()
    choiceCloser:SetScript("OnClick", closeChoiceMenu)
    return choiceCloser
end

function QOL.CreateChoice(parent, w, h, choices, placeholder, onSelect)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(w, h)
    local bg = c:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(c); bg:SetTexture(0, 0, 0, 0.55)
    bg:SetDrawLayer("BACKGROUND", 1); c.bg = bg
    local border = c:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", c, "TOPLEFT", -1, 1); border:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 1, -1)
    border:SetTexture(0.25, 0.35, 0.42, 0.7)
    local hl = c:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(c); hl:SetTexture(1, 1, 1, 0.12)
    local txt = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", c, "LEFT", 6, 0); txt:SetPoint("RIGHT", c, "RIGHT", -14, 0); txt:SetJustifyH("LEFT")
    txt:SetText(placeholder or "select"); txt:SetTextColor(0.6, 0.7, 0.85); c.text = txt
    local arrow = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", c, "RIGHT", -5, 0); arrow:SetText("v"); arrow:SetTextColor(0.6, 0.7, 0.85)

    c.value, c.choices = nil, choices or {}
    function c.GetValue() return c.value end
    function c.SetChoices(list) c.choices = list or {} end
    function c.SetValue(v)
        c.value = v
        if v == nil or v == "" then
            txt:SetText(placeholder or "select"); txt:SetTextColor(0.6, 0.7, 0.85)
        else
            local disp = v
            for _, opt in ipairs(c.choices) do
                if type(opt) == "table" then if opt.value == v then disp = opt.text; break end
                elseif opt == v then disp = v; break end
            end
            txt:SetText(disp); txt:SetTextColor(1, 1, 1)
        end
    end

    local menu
    local function rebuild()
        if not menu then
            menu = CreateFrame("Frame", nil, UIParent)
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:EnableMouse(true)
            QOL.ApplyBackdrop(menu, "inset", 0.98, 0.05, 0.07, 0.10)
            menu:Hide(); menu._btns = {}; menu._offset = 0; c.menu = menu

            menu:EnableMouseWheel(true)
            menu:SetScript("OnMouseWheel", function(self, delta)
                local maxOffset = math.max(0, #c.choices - 15)
                if maxOffset == 0 then return end
                self._offset = math.max(0, math.min(maxOffset, (self._offset or 0) - delta * 3))
                self.render()
            end)
        end

        local maxw = w
        for _, opt in ipairs(c.choices) do
            local text = type(opt) == "table" and opt.text or opt
            local tw = 28
            if menu._btns[1] and menu._btns[1].label then
                local oldText = menu._btns[1].label:GetText()
                menu._btns[1].label:SetText(text)
                tw = (menu._btns[1].label:GetStringWidth() or 0) + 32
                menu._btns[1].label:SetText(oldText)
            else
                tw = (#tostring(text) * 8) + 32
            end
            if tw > maxw then maxw = tw end
        end

        local visibleCount = math.min(#c.choices, 15)
        local btnWidth = math.max(w, maxw)
        menu:SetWidth(btnWidth + 8)
        menu:SetHeight(visibleCount * 20 + 8)

        local function render()
            local offset = menu._offset or 0
            for i = 1, 15 do
                local optIdx = offset + i
                local opt = c.choices[optIdx]
                local b = menu._btns[i]
                if not b then
                    b = QOL.MakeFlatButton(menu, btnWidth, 18, "", { padLeft = 6 })
                    menu._btns[i] = b
                end
                b:SetWidth(btnWidth)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 20)

                if opt then
                    local text = type(opt) == "table" and opt.text or opt
                    local val  = type(opt) == "table" and opt.value or opt
                    b.label:SetText(text)
                    b._val = val
                    b:SetScript("OnClick", function(self)
                        c.SetValue(self._val)
                        closeChoiceMenu()
                        if onSelect then onSelect(self._val) end
                    end)
                    b:Show()
                else
                    b:Hide()
                end
            end
        end
        menu.render = render
        menu._offset = 0
        render()
    end

    c:SetScript("OnClick", function(self)
        if menu and menu:IsShown() then closeChoiceMenu(); return end
        closeChoiceMenu(); rebuild()
        menu:ClearAllPoints()
        local bottom = self:GetBottom() or 100
        if bottom - menu:GetHeight() < 0 then menu:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)
        else menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2) end
        ensureCloser():Show(); menu:Show(); menu:Raise()
        openChoiceMenu = menu
    end)
    return c
end

-- ─── Single command row ────────────────────────────────────────────────────
-- def = { id, label, format, args, danger, group, tooltip, send, getScope }
function QOL.CreateCommandRow(parent, def)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row.def = def

    local rowKey = (def.group or "?") .. ":" .. (def.id or def.label or "?")

    -- Category pip (cyan = your command, tan = bot order).
    local pip = row:CreateTexture(nil, "ARTWORK")
    pip:SetPoint("LEFT", row, "LEFT", 0, 0)
    pip:SetSize(PIP_WIDTH, ROW_HEIGHT - 4)
    local cat = QOL.cats[QOL.CatOf(def)]
    pip:SetTexture(cat.rgb[1], cat.rgb[2], cat.rgb[3], 0.95)

    -- Label button.
    local labelText = def.label or def.id or "?"
    local btn = QOL.MakeFlatButton(row, LABEL_WIDTH, ROW_HEIGHT - 2, labelText, { danger = def.danger })
    btn:SetPoint("LEFT", pip, "RIGHT", 4, 0)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.button = btn

    local execute, gatherValues

    row.edits = {}
    row.getters = {}
    local prev = btn
    for _, arg in ipairs(def.args or {}) do
        local choices = arg.choices
        if type(choices) == "function" then choices = choices() end
        if not choices and arg.placeholder and arg.placeholder:lower():match("^on%s*/%s*off") then choices = { "on", "off" } end
        if choices then
            local ch = QOL.CreateChoice(row, arg.width or INPUT_WIDTH, ROW_HEIGHT - 2, choices, arg.placeholder,
                function(v) QOL.SetInputCache(rowKey, arg.key, v) end)
            ch:SetPoint("LEFT", prev, "RIGHT", 8, 0)
            local cached = QOL.GetInputCache(rowKey, arg.key)
            if cached and cached ~= "" then ch.SetValue(cached) end
            row.getters[arg.key] = ch.GetValue
            prev = ch
        else
            local edit = makeFlatEditBox(row, arg.width or INPUT_WIDTH, ROW_HEIGHT - 2, arg.placeholder, arg.numeric)
            edit:SetPoint("LEFT", prev, "RIGHT", 8, 0)
            edit:HookScript("OnTextChanged", function(self) QOL.SetInputCache(rowKey, arg.key, self:GetText()) end)
            edit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); execute() end)
            edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            local cached = QOL.GetInputCache(rowKey, arg.key)
            if cached and cached ~= "" then edit:SetText(cached) end
            if edit.refreshHint then edit.refreshHint() end
            row.edits[arg.key] = edit
            row.getters[arg.key] = function() return edit:GetText() end
            prev = edit
        end
    end

    gatherValues = function()
        local v = {}
        for _, arg in ipairs(def.args or {}) do
            local g = row.getters[arg.key]
            v[arg.key] = g and g() or nil
        end
        return v
    end

    execute = function()
        local line, err = QOL.BuildLine(def, gatherValues())
        if not line then QOL.Warn(err or "invalid args"); return end
        if def.send == "bot" then
            local scope = (def.getScope and def.getScope()) or def.botScope
            QOL.RunBotOrder(line, { scope = scope })
        else
            QOL.RunCommand(line, { danger = def.danger })
        end
    end
    row.Execute = execute

    btn:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            QOL.ToggleFavorite(def)
        elseif IsShiftKeyDown() then
            ChatFrame_OpenChat(QOL.PreviewLine(def, gatherValues()))
        else
            execute()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local title = def.label or def.id or ""
        GameTooltip:SetText(title, 1, 0.82, 0.30)
        GameTooltip:AddLine(QOL.PreviewLine(def, gatherValues()), 0.27, 0.84, 1, true)
        if def.tooltip then GameTooltip:AddLine(def.tooltip, 1, 1, 1, true) end
        GameTooltip:AddLine(" ")
        if def.send == "bot" then
            GameTooltip:AddLine("Bot order - sent to all your bots (party/raid) or the targeted bot (whisper).", 0.90, 0.80, 0.50, true)
        else
            GameTooltip:AddLine("Your command - runs as you.", 0.7, 0.7, 0.7)
        end
        if def.danger then GameTooltip:AddLine("Asks for confirmation before sending.", 1, 0.45, 0.45) end
        GameTooltip:AddLine("Left-click run  /  Shift-click edit in chat  /  Right-click pin", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

-- ─── Vertical / column row layout ──────────────────────────────────────────
function QOL.LayoutRows(parent, defs, opts)
    opts = opts or {}
    local x = opts.x or 8
    local y = -(opts.yTop or 8)

    if opts.sectionTitle then
        local hdr = QOL.CreateSectionHeader(parent, opts.sectionTitle)
        hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        y = y - hdr:GetHeight() - 6
    end

    local startY = y
    local colWidth = opts.columnWidth or 430
    local rowsPerColumn = opts.rowsPerColumn
    local col, count = 0, 0
    local rowTopMin = startY

    for _, def in ipairs(defs) do
        local row = QOL.CreateCommandRow(parent, def)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", x + col * colWidth, y)
        row:SetWidth(colWidth - 16)
        if y < rowTopMin then rowTopMin = y end
        y = y - (ROW_HEIGHT + ROW_SPACING)
        count = count + 1
        if rowsPerColumn and count % rowsPerColumn == 0 then
            col = col + 1
            y = startY
        end
    end
    return -(rowTopMin - ROW_HEIGHT) + 8
end

-- ─── Sub-tab strip (the "top tabs" within a left-rail tab) ─────────────────
function QOL.BuildSubTabs(parent, subTabsDef, dbKey)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -2)
    strip:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -2)
    strip:SetHeight(22)

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -1)
    divider:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT", 0, -1)
    divider:SetHeight(1)
    divider:SetTexture(0.30, 0.45, 0.55, 0.6)

    local subContent = CreateFrame("Frame", nil, parent)
    subContent:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -6)
    subContent:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)

    local entries = {}
    local function selectSub(idx)
        for i, e in ipairs(entries) do
            if i == idx then
                e.button.bg:SetTexture(0.10, 0.30, 0.40, 0.95)
                e.button.label:SetTextColor(1, 0.82, 0.30)
                e.contentFrame:Show()
            else
                e.button.bg:SetTexture(0.13, 0.15, 0.19, 0.95)
                e.button.label:SetTextColor(0.82, 0.82, 0.82)
                e.contentFrame:Hide()
            end
        end
        if dbKey and QOL.db then QOL.db.subTabs[dbKey] = idx end
    end

    local sizer = strip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local prev
    for i, def in ipairs(subTabsDef) do
        sizer:SetText(def.label)
        local w = math.max(54, math.ceil(sizer:GetStringWidth()) + 18)
        local btn = QOL.MakeFlatButton(strip, w, 20, def.label, { justify = "CENTER", padLeft = 4 })
        if prev then btn:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else btn:SetPoint("LEFT", strip, "LEFT", 0, 0) end
        prev = btn

        local content = CreateFrame("Frame", nil, subContent)
        content:SetAllPoints(subContent)
        content:Hide()

        if def.rows then QOL.LayoutRows(content, def.rows, def.layoutOpts or {}) end
        if def.builder then
            local ok, err = pcall(def.builder, content)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555QOL sub-tab '" .. tostring(def.label) .. "' error:|r " .. tostring(err))
            end
        end

        btn:SetScript("OnClick", function() selectSub(i) end)
        table.insert(entries, { button = btn, contentFrame = content })
    end
    sizer:Hide()

    QOL.db.subTabs = QOL.db.subTabs or {}
    local saved = (dbKey and QOL.db.subTabs[dbKey]) or 1
    if not entries[saved] then saved = 1 end
    selectSub(saved)
end

-- ─── Bot-order scope selector ──────────────────────────────────────────────
QOL._scopeSelectors = {}
function QOL.RefreshScopeSelectors()
    for _, s in ipairs(QOL._scopeSelectors) do if s.refresh then s.refresh() end end
end

function QOL.MakeScopeSelector(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(24)

    local lbl = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", bar, "LEFT", 4, 0)
    lbl:SetText(QOL.colors.muted .. "Send $ orders to:" .. QOL.colors.reset)

    local allBtn = QOL.MakeFlatButton(bar, 150, 20, "All my bots (party)", { justify = "CENTER" })
    allBtn:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    local whisBtn = QOL.MakeFlatButton(bar, 160, 20, "Targeted bot (whisper)", { justify = "CENTER" })
    whisBtn:SetPoint("LEFT", allBtn, "RIGHT", 6, 0)

    local note = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("LEFT", whisBtn, "RIGHT", 12, 0)
    note:SetText("Whisper needs a bot targeted")

    local function refresh()
        if QOL.GetBotScope() == "whisper" then
            whisBtn.bg:SetTexture(0.10, 0.30, 0.40, 0.95); whisBtn.label:SetTextColor(1, 0.82, 0.30)
            allBtn.bg:SetTexture(0.13, 0.15, 0.19, 0.95);  allBtn.label:SetTextColor(0.82, 0.82, 0.82)
        else
            allBtn.bg:SetTexture(0.10, 0.30, 0.40, 0.95);  allBtn.label:SetTextColor(1, 0.82, 0.30)
            whisBtn.bg:SetTexture(0.13, 0.15, 0.19, 0.95); whisBtn.label:SetTextColor(0.82, 0.82, 0.82)
        end
    end
    allBtn:SetScript("OnClick", function() QOL.SetBotScope("all") end)
    whisBtn:SetScript("OnClick", function() QOL.SetBotScope("whisper") end)
    bar.refresh = refresh
    table.insert(QOL._scopeSelectors, bar)
    refresh()
    return bar
end

-- ─── Scrollable content holder ─────────────────────────────────────────────
local scrollSeq = 0
function QOL.CreateScrollContent(parent)
    scrollSeq = scrollSeq + 1
    local scroll = CreateFrame("ScrollFrame", "QOL_Scroll" .. scrollSeq, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -28, 4)

    local bar = _G[scroll:GetName() .. "ScrollBar"]

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        if bar then
            bar:SetValue(bar:GetValue() - delta * (ROW_HEIGHT * 2))
        else
            local t = self:GetVerticalScroll() - delta * (ROW_HEIGHT * 2)
            self:SetVerticalScroll(t < 0 and 0 or t)
        end
    end)

    scroll:SetScript("OnShow", function(self)
        if ScrollFrame_OnScrollRangeChanged then ScrollFrame_OnScrollRangeChanged(self) end
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(820, 400)
    scroll:SetScrollChild(content)
    scroll.content = content
    return scroll, content
end

QOL.ROW_HEIGHT = ROW_HEIGHT
