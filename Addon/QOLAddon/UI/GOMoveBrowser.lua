-- GOMove Browser — GameObject lookup + 3D preview by Project Rx (WoW 3.3.5a client)
-- Opens from "Browse / Search" button on main GOMove frame.
-- Server command: .gomovesearch <name|entry>
-- Server replies with GSRES|entry|name|modelpath (up to 500), then GSEND|total

local PAGE_SIZE    = 50
local ROW_HEIGHT   = 16
local VISIBLE_ROWS = 22

local searchResults = {}
local currentPage   = 1
local totalPages    = 1
local selectedEntry = nil
local selectedModel = ""
local autoSpin      = true
local spinElapsed   = 0
local spawnSpell    = false

-- File-level locals for cross-scope access (event handler + UI)
local resultScroll
local pageLabel
local countLabel

-- ────────────────────────────────────────────────────────────────────────────
-- Event handler registered FIRST — must survive even if UI code below errors
-- ────────────────────────────────────────────────────────────────────────────
local browserEventFrame = CreateFrame("Frame")
browserEventFrame:RegisterEvent("CHAT_MSG_ADDON")
browserEventFrame:SetScript("OnEvent", function(self, event, prefix, msg, msgType, sender)
    if prefix ~= "GOMOVE" then return end
    if sender ~= UnitName("player") then return end

    -- GSRES|entry|name|modelpath
    if msg:sub(1, 6) == "GSRES|" then
        local rest = msg:sub(7)
        local entry, name, modelPath = rest:match("^(%d+)|([^|]*)|(.*)$")
        if entry then
            table.insert(searchResults, {
                entry     = tonumber(entry),
                name      = name,
                modelPath = modelPath,
            })
        end
        return
    end

    -- GSEND|total
    if msg:sub(1, 6) == "GSEND|" then
        local count = #searchResults
        totalPages  = math.max(1, math.ceil(count / PAGE_SIZE))
        currentPage = 1
        if resultScroll then
            resultScroll:SetVerticalScroll(0)
        end
        if countLabel then
            if count == 0 then
                countLabel:SetText("No results")
            else
                countLabel:SetText(count .. " found")
            end
        end
        if pageLabel then
            pageLabel:SetText("Page 1/" .. totalPages)
        end
        if GOMove_Browser_UpdateRows then
            GOMove_Browser_UpdateRows()
        end
        return
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- UI — wrapped in pcall so a UI error never breaks the event handler above
-- ────────────────────────────────────────────────────────────────────────────
local function BuildBrowserUI()

-- Declare panel state at the top so every closure in this scope captures the same upvalue
local leftPanelVisible  = true
local rightPanelVisible = true

local function MakeBackdrop()
    return {
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 16,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",          edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    }
end

-- Main browse frame
local BF = CreateFrame("Frame", "GOMove_BrowseFrame", UIParent)
BF:SetSize(810, 540)
BF:SetPoint("CENTER")
BF:SetMovable(true)
BF:EnableMouse(true)
BF:SetClampedToScreen(true)
BF:RegisterForDrag("LeftButton")
BF:SetScript("OnDragStart", BF.StartMoving)
BF:SetScript("OnDragStop",  BF.StopMovingOrSizing)
BF:SetBackdrop(MakeBackdrop())
BF:Hide()
table.insert(GOMove.Frames, BF)

-- Title
local titleTxt = BF:CreateFontString(nil, "OVERLAY")
titleTxt:SetFont("Fonts\\MORPHEUS.ttf", 15)
titleTxt:SetTextColor(0.8, 0.2, 0.2)
titleTxt:SetPoint("TOPLEFT", BF, "TOPLEFT", 52, -8)
titleTxt:SetText("GameObject Browser")

-- Close button
local cBtn = CreateFrame("Button", "GOMove_BrowseClose", BF)
cBtn:SetSize(25, 25)
cBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
cBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
cBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
cBtn:SetPoint("TOPRIGHT", BF, "TOPRIGHT", 0, 0)
cBtn:SetScript("OnClick", function() BF:Hide() end)

-- Divider
local div = BF:CreateTexture(nil, "BACKGROUND")
div:SetTexture(0.25, 0.25, 0.25, 1)
div:SetWidth(2)
div:SetPoint("TOPLEFT",    BF, "TOPLEFT",   358, -24)
div:SetPoint("BOTTOMLEFT", BF, "BOTTOMLEFT", 358, 8)

-- ── LEFT PANEL ──────────────────────────────────────────────────────────────

local searchBox = CreateFrame("EditBox", "GOMove_SearchBox", BF, "InputBoxTemplate")
searchBox:SetSize(225, 22)
searchBox:SetPoint("TOPLEFT", BF, "TOPLEFT", 10, -30)
searchBox:SetAutoFocus(false)
searchBox:SetMaxLetters(60)

local searchBtn = CreateFrame("Button", "GOMove_SearchBtn", BF, "UIPanelButtonTemplate")
searchBtn:SetSize(75, 22)
searchBtn:SetText("Search")
searchBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)

local prevBtn = CreateFrame("Button", "GOMove_BrowsePrev", BF, "UIPanelButtonTemplate")
prevBtn:SetSize(28, 20)
prevBtn:SetText("<")
prevBtn:SetPoint("TOPLEFT", BF, "TOPLEFT", 10, -57)

pageLabel = BF:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pageLabel:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
pageLabel:SetText("Page 1/1")
pageLabel:SetWidth(100)
pageLabel:SetJustifyH("CENTER")

local nextBtn = CreateFrame("Button", "GOMove_BrowseNext", BF, "UIPanelButtonTemplate")
nextBtn:SetSize(28, 20)
nextBtn:SetText(">")
nextBtn:SetPoint("LEFT", pageLabel, "RIGHT", 4, 0)

countLabel = BF:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
countLabel:SetPoint("LEFT", nextBtn, "RIGHT", 6, 0)
countLabel:SetText("")
countLabel:SetTextColor(0.7, 0.7, 0.7)

-- Scroll frame
resultScroll = CreateFrame("ScrollFrame", "GOMove_BrowseScroll", BF, "FauxScrollFrameTemplate")
resultScroll:SetPoint("TOPLEFT",     BF, "TOPLEFT",   8,   -80)
resultScroll:SetPoint("BOTTOMRIGHT", BF, "BOTTOMLEFT", 330, 24)
resultScroll:SetScript("OnVerticalScroll", function(self, offset)
    self.offset = math.floor(offset / ROW_HEIGHT + 0.5)
    GOMove_Browser_UpdateRows()
end)

-- Result rows (lazy — created on first access so resize can add more)
local resultRows = {}
local function GetResultRow(i)
    if resultRows[i] then return resultRows[i] end
    local btn = CreateFrame("Button", "GOMove_ResultRow"..i, BF)
    btn:SetSize(330, ROW_HEIGHT)
    btn:SetNormalFontObject(GameFontHighlightSmall)
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    if i == 1 then
        btn:SetPoint("TOPLEFT", resultScroll, "TOPLEFT", 2, 0)
    else
        btn:SetPoint("TOPLEFT", GetResultRow(i-1), "BOTTOMLEFT", 0, 0)
    end
    btn:SetScript("OnClick", function(self)
        GOMove_Browser_SelectEntry(self.entryID, self.entryName, self.modelPath)
    end)
    btn:Hide()
    resultRows[i] = btn
    return btn
end

-- ── RIGHT PANEL ─────────────────────────────────────────────────────────────

-- PlayerModel has built-in lighting; Model frame lacks SetLight in this client
-- PlayerModel: has built-in lighting, supports SetModel for arbitrary M2 files
local modelFrame = CreateFrame("PlayerModel", "GOMove_PreviewModel", BF)
modelFrame:SetSize(410, 270)
modelFrame:SetPoint("TOPRIGHT", BF, "TOPRIGHT", -8, -28)
local modelBgTex = modelFrame:CreateTexture(nil, "BACKGROUND")
modelBgTex:SetAllPoints()
modelBgTex:SetTexture(0.12, 0.12, 0.15, 1)

-- ── Camera state ─────────────────────────────────────────────────────────
local camPosX, camPosY, camPosZ = 0, 0, 0
local camZoom    = 1.0
local dragMode   = nil
local dragStartX, dragStartY
local dragStartRot, dragStartPosX, dragStartPosZ

local function ApplyCamera()
    modelFrame:SetPosition(camPosX, camPosY, camPosZ)
    modelFrame:SetFacing(spinElapsed)
    pcall(function() modelFrame:SetModelScale(camZoom) end)
end

local function ResetCamera()
    camPosX, camPosY, camPosZ = 0, 0, 0
    camZoom     = 1.0
    spinElapsed = 0
    autoSpin    = true
    local asb = _G["GOMove_AutoSpinBtn"]
    if asb then asb:SetText("Auto: ON") end
    ApplyCamera()
end

-- ── Mouse controls ──────────────────────────────────────────────────────
modelFrame:EnableMouseWheel(true)
modelFrame:SetScript("OnMouseWheel", function(self, delta)
    local step = IsShiftKeyDown() and 0.02 or 0.08
    camZoom = math.max(0.05, math.min(10, camZoom + delta * step))
    pcall(function() self:SetModelScale(camZoom) end)
end)

modelFrame:EnableMouse(true)
modelFrame:SetScript("OnMouseDown", function(self, button)
    local cx, cy = GetCursorPosition()
    dragStartX, dragStartY = cx, cy
    if button == "LeftButton" then
        dragMode = "orbit"
        dragStartRot = spinElapsed
        autoSpin = false
        local asb = _G["GOMove_AutoSpinBtn"]
        if asb then asb:SetText("Auto: OFF") end
    elseif button == "RightButton" then
        dragMode = "pan"
        dragStartPosX = camPosX
        dragStartPosZ = camPosZ
    elseif button == "MiddleButton" then
        dragMode = "depth"
        dragStartPosX = camPosY
    end
end)

modelFrame:SetScript("OnMouseUp", function(self, button)
    dragMode = nil
end)

modelFrame:SetScript("OnUpdate", function(self, delta)
    if dragMode then
        local cx, cy = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        local dx = (cx - dragStartX) / scale
        local dy = (cy - dragStartY) / scale
        local panSens = 0.002 / math.max(camZoom, 0.1)
        if dragMode == "orbit" then
            spinElapsed = dragStartRot + dx * 0.003
            self:SetFacing(spinElapsed)
        elseif dragMode == "pan" then
            camPosX = dragStartPosX + dx * panSens
            camPosZ = dragStartPosZ + dy * panSens
            self:SetPosition(camPosX, camPosY, camPosZ)
        elseif dragMode == "depth" then
            camPosY = dragStartPosX - dx * panSens
            self:SetPosition(camPosX, camPosY, camPosZ)
        end
    elseif autoSpin then
        spinElapsed = spinElapsed + delta * 0.6
        self:SetFacing(spinElapsed)
    end
end)

-- ── Overlay buttons ─────────────────────────────────────────────────────
local resetBtn = CreateFrame("Button", "GOMove_ResetViewBtn", BF, "UIPanelButtonTemplate")
resetBtn:SetSize(50, 18)
resetBtn:SetText("Reset")
resetBtn:SetPoint("TOPRIGHT", modelFrame, "TOPRIGHT", -4, -4)
resetBtn:SetFrameLevel(modelFrame:GetFrameLevel() + 10)
resetBtn:SetScript("OnClick", ResetCamera)

local infoBtn = CreateFrame("Button", "GOMove_InfoBtn", BF, "UIPanelButtonTemplate")
infoBtn:SetSize(50, 18)
infoBtn:SetText("Info - ?")
infoBtn:SetPoint("RIGHT", resetBtn, "LEFT", -4, 0)
infoBtn:SetFrameLevel(modelFrame:GetFrameLevel() + 10)
infoBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Preview Info", 1, 0.8, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Some objects show a blue/white checkerboard", 1, 1, 1, true)
    GameTooltip:AddLine("pattern instead of their real textures.", 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("This is a WoW 3.3.5a client limitation.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("The UI model viewer cannot resolve all", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("texture paths that the world engine can.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("The object will look correct when spawned.", 0.4, 1, 0.4, true)
    GameTooltip:Show()
end)
infoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
infoBtn:SetScript("OnClick", function() end) -- absorb click so model doesn't get it

-- Overlay frame for text labels (sits above both model frames)
local modelOverlay = CreateFrame("Frame", "GOMove_ModelOverlay", BF)
modelOverlay:SetAllPoints(modelFrame)
modelOverlay:SetFrameLevel(modelFrame:GetFrameLevel() + 5)

local hintText = modelOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hintText:SetPoint("BOTTOM", modelOverlay, "BOTTOM", 0, 4)
hintText:SetText("L-drag: rotate | R-drag: depth | Mid-drag: pan | Scroll: zoom")
hintText:SetTextColor(0.5, 0.5, 0.5, 0.7)

local noPreviewText = modelOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
noPreviewText:SetPoint("CENTER", modelOverlay, "CENTER")
noPreviewText:SetText("No preview available")
noPreviewText:SetTextColor(0.5, 0.5, 0.5)

local entryInfoLabel = BF:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
entryInfoLabel:SetPoint("TOPLEFT", modelFrame, "BOTTOMLEFT", 0, -4)
entryInfoLabel:SetText("Select an object from the list")
entryInfoLabel:SetTextColor(0.9, 0.9, 0.9)
entryInfoLabel:SetWidth(410)
entryInfoLabel:SetJustifyH("LEFT")

-- Scale controls
local scaleLbl = BF:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
scaleLbl:SetPoint("TOPLEFT", entryInfoLabel, "BOTTOMLEFT", 0, -10)
scaleLbl:SetText("Scale: 1.00x")
scaleLbl:SetTextColor(0.8, 0.8, 0.8)
scaleLbl:SetWidth(70)

local scaleSlider = CreateFrame("Slider", "GOMove_ScaleSlider", BF, "OptionsSliderTemplate")
scaleSlider:SetWidth(240)
scaleSlider:SetMinMaxValues(10, 500)
scaleSlider:SetValue(100)
scaleSlider:SetValueStep(5)
scaleSlider:SetPoint("LEFT", scaleLbl, "RIGHT", 6, 0)
local ssl = _G["GOMove_ScaleSliderLow"]
if ssl then ssl:SetText("0.1x") end
local ssh = _G["GOMove_ScaleSliderHigh"]
if ssh then ssh:SetText("5.0x") end
local sst = _G["GOMove_ScaleSliderText"]
if sst then sst:SetText("") end

local scaleApplyBtn = CreateFrame("Button", "GOMove_ScaleApplyBtn", BF, "UIPanelButtonTemplate")
scaleApplyBtn:SetSize(55, 20)
scaleApplyBtn:SetText("Apply")
scaleApplyBtn:SetPoint("LEFT", scaleSlider, "RIGHT", 6, 0)

-- Rotation controls
local rotLbl = BF:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rotLbl:SetPoint("TOPLEFT", scaleLbl, "BOTTOMLEFT", 0, -20)
rotLbl:SetText("Rotation:")
rotLbl:SetTextColor(0.8, 0.8, 0.8)
rotLbl:SetWidth(70)

local rotSlider = CreateFrame("Slider", "GOMove_RotSlider", BF, "OptionsSliderTemplate")
rotSlider:SetWidth(240)
rotSlider:SetMinMaxValues(0, 360)
rotSlider:SetValue(0)
rotSlider:SetValueStep(5)
rotSlider:SetPoint("LEFT", rotLbl, "RIGHT", 6, 0)
local rsl = _G["GOMove_RotSliderLow"]
if rsl then rsl:SetText("0") end
local rsh = _G["GOMove_RotSliderHigh"]
if rsh then rsh:SetText("360") end
local rst = _G["GOMove_RotSliderText"]
if rst then rst:SetText("") end

local autoSpinBtn = CreateFrame("Button", "GOMove_AutoSpinBtn", BF, "UIPanelButtonTemplate")
autoSpinBtn:SetSize(70, 20)
autoSpinBtn:SetText("Auto: ON")
autoSpinBtn:SetPoint("LEFT", rotSlider, "RIGHT", 6, 0)

-- Spawn controls
local spawnModeBtn = CreateFrame("Button", "GOMove_SpawnModeBtn", BF, "UIPanelButtonTemplate")
spawnModeBtn:SetSize(110, 24)
spawnModeBtn:SetText("Mode: At Feet")
spawnModeBtn:SetPoint("TOPLEFT", rotLbl, "BOTTOMLEFT", 0, -28)

local spawnBtn = CreateFrame("Button", "GOMove_BrowseSpawnBtn", BF, "UIPanelButtonTemplate")
spawnBtn:SetSize(80, 24)
spawnBtn:SetText("Spawn")
spawnBtn:SetPoint("LEFT", spawnModeBtn, "RIGHT", 8, 0)

-- ── Functions ────────────────────────────────────────────────────────────────

function GOMove_Browser_UpdateRows()
    if not resultScroll then return end
    if not leftPanelVisible then
        for _, row in pairs(resultRows) do row:Hide() end
        return
    end
    local offset    = FauxScrollFrame_GetOffset(resultScroll) or 0
    local pageStart = (currentPage - 1) * PAGE_SIZE + 1
    local pageEnd   = math.min(currentPage * PAGE_SIZE, #searchResults)
    local pageCount = math.max(0, pageEnd - pageStart + 1)

    FauxScrollFrame_Update(resultScroll, pageCount, VISIBLE_ROWS, ROW_HEIGHT,
        nil, nil, nil, nil, nil, nil, true)

    for i = 1, VISIBLE_ROWS do
        local dataIdx = pageStart + offset + i - 1
        local row = GetResultRow(i)
        if dataIdx <= pageEnd and searchResults[dataIdx] then
            local r = searchResults[dataIdx]
            local displayName = tostring(r.entry) .. "  " .. r.name
            if #displayName > 42 then displayName = displayName:sub(1, 40) .. "..." end
            row:SetText(displayName)
            row.entryID   = r.entry
            row.entryName = r.name
            row.modelPath = r.modelPath
            if r.entry == selectedEntry then
                row:GetFontString():SetTextColor(1, 0.8, 0)
            else
                row:GetFontString():SetTextColor(1, 1, 1)
            end
            row:Show()
        else
            row:Hide()
        end
    end
    -- Hide any rows beyond the current VISIBLE_ROWS (left over from a larger size)
    local i = VISIBLE_ROWS + 1
    while resultRows[i] do
        resultRows[i]:Hide()
        i = i + 1
    end
end

function GOMove_Browser_SelectEntry(entry, name, modelPath)
    selectedEntry = entry
    selectedModel = modelPath or ""
    spinElapsed   = 0
    entryInfoLabel:SetText("[" .. entry .. "]  " .. (name or ""))
    if selectedModel ~= "" then
        camPosX, camPosY, camPosZ = 0, 0, 0
        camZoom = 1.0
        local ok = pcall(function()
            modelFrame:ClearModel()
            modelFrame:SetModel(selectedModel)
            modelFrame:SetPosition(0, 0, 0)
            modelFrame:SetFacing(0)
            pcall(function() modelFrame:SetModelScale(1.0) end)
        end)
        -- Lighting MUST be applied after SetModel or textures render as black.
        -- Try 13-arg, 10-arg, 6-arg forms (boolean enabled/omni).
        if not pcall(function()
            modelFrame:SetLight(true, false, 0, -0.707, -0.707, 1.0, 1.0, 1.0, 1.0, 0.8, 1.0, 1.0, 1.0)
        end) then
            if not pcall(function()
                modelFrame:SetLight(true, false, 0, -0.707, -0.707, 1.0, 1.0, 1.0, 1.0, 0.8)
            end) then
                pcall(function()
                    modelFrame:SetLight(true, false, 0, -0.707, -0.707, 1.0)
                end)
            end
        end
        if ok and modelFrame:GetModel() then
            noPreviewText:Hide()
        else
            modelFrame:ClearModel()
            noPreviewText:SetText("Failed to load model")
            noPreviewText:Show()
        end
    else
        modelFrame:ClearModel()
        noPreviewText:SetText("No preview available")
        noPreviewText:Show()
    end
    GOMove_Browser_UpdateRows()
end

-- ── Widget scripts ───────────────────────────────────────────────────────────

local function DoSearch()
    local text = searchBox:GetText()
    if not text or text == "" then return end
    searchResults = {}
    currentPage   = 1
    totalPages    = 1
    countLabel:SetText("Searching...")
    pageLabel:SetText("Page 1/1")
    resultScroll:SetVerticalScroll(0)
    for i = 1, VISIBLE_ROWS do if resultRows[i] then resultRows[i]:Hide() end end
    SendChatMessage(".gomovesearch " .. text)
end

searchBtn:SetScript("OnClick", DoSearch)
searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() DoSearch() end)
searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

prevBtn:SetScript("OnClick", function()
    if currentPage > 1 then
        currentPage = currentPage - 1
        resultScroll:SetVerticalScroll(0)
        pageLabel:SetText("Page " .. currentPage .. "/" .. totalPages)
        GOMove_Browser_UpdateRows()
    end
end)

nextBtn:SetScript("OnClick", function()
    if currentPage < totalPages then
        currentPage = currentPage + 1
        resultScroll:SetVerticalScroll(0)
        pageLabel:SetText("Page " .. currentPage .. "/" .. totalPages)
        GOMove_Browser_UpdateRows()
    end
end)

scaleSlider:SetScript("OnValueChanged", function(self, val)
    local s = math.floor(val / 5 + 0.5) * 5
    scaleLbl:SetText(string.format("Scale: %.2fx", s / 100))
end)

scaleApplyBtn:SetScript("OnClick", function()
    local val = math.floor(scaleSlider:GetValue() / 5 + 0.5) * 5
    GOMove:Move("SCALE", val)
end)

rotSlider:SetScript("OnValueChanged", function(self, val)
    local deg = math.floor(val / 5 + 0.5) * 5
    if not autoSpin then
        local rad = deg * math.pi / 180
        spinElapsed = rad
        modelFrame:SetFacing(rad)
    end
end)

autoSpinBtn:SetScript("OnClick", function()
    autoSpin = not autoSpin
    autoSpinBtn:SetText(autoSpin and "Auto: ON" or "Auto: OFF")
end)

spawnModeBtn:SetScript("OnClick", function()
    spawnSpell = not spawnSpell
    spawnModeBtn:SetText(spawnSpell and "Mode: Spell" or "Mode: At Feet")
end)

spawnBtn:SetScript("OnClick", function()
    if not selectedEntry or selectedEntry == 0 then
        UIErrorsFrame:AddMessage("No object selected", 1, 0, 0, 53, 2)
        return
    end
    if spawnSpell then
        GOMove:Move("SPAWNSPELL", selectedEntry)
        CastSpellByID(27651)
    else
        GOMove:Move("SPAWN", selectedEntry)
    end
end)

-- Footer
local footerText = BF:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
footerText:SetPoint("BOTTOM", BF, "BOTTOM", 0, 10)
footerText:SetText("|cff888888Project Rx|r  |cff555555GOMove Browser|r")

-- Panel toggle helpers
local leftPanelElements  = { searchBox, searchBtn, prevBtn, nextBtn, pageLabel, countLabel, resultScroll }
local rightPanelElements = { modelFrame, modelOverlay, entryInfoLabel, scaleLbl, scaleSlider, scaleApplyBtn,
                              rotLbl, rotSlider, autoSpinBtn, spawnModeBtn, spawnBtn, resetBtn, infoBtn }

local function UpdateBFWidth()
    if leftPanelVisible and rightPanelVisible then
        BF:SetWidth(810)
    elseif rightPanelVisible then
        BF:SetWidth(430)   -- model (410) + 8 right margin + 12 left margin
    elseif leftPanelVisible then
        BF:SetWidth(360)   -- scroll goes to x=330; 30px right margin
    end
end

-- Forward-declare so toggleBtn's handler can reference it before creation
local toggleRightBtn

-- << button (top-right): collapse/expand left panel
-- Hidden when right panel is already collapsed (prevents both panels being hidden)
local toggleBtn = CreateFrame("Button", "GOMove_BrowseToggleLeft", BF, "UIPanelButtonTemplate")
toggleBtn:SetSize(40, 18)
toggleBtn:SetText("<<")
toggleBtn:SetPoint("RIGHT", cBtn, "LEFT", -4, 0)
toggleBtn:SetFrameLevel(cBtn:GetFrameLevel())
toggleBtn:SetScript("OnClick", function()
    leftPanelVisible = not leftPanelVisible
    for _, el in ipairs(leftPanelElements) do
        if leftPanelVisible then el:Show() else el:Hide() end
    end
    -- rows hidden via UpdateRows guard; hide explicitly too for the expanding case
    if not leftPanelVisible then
        for _, row in pairs(resultRows) do row:Hide() end
    end
    div[leftPanelVisible and rightPanelVisible and "Show" or "Hide"](div)
    toggleBtn:SetText(leftPanelVisible and "<<" or ">>")
    -- hide the right toggle when left is collapsed so both can't be hidden at once
    if leftPanelVisible then toggleRightBtn:Show() else toggleRightBtn:Hide() end
    UpdateBFWidth()
    if leftPanelVisible and GOMove_Browser_UpdateRows then GOMove_Browser_UpdateRows() end
end)

-- >> button (top-left): collapse/expand right panel
-- Hidden when left panel is already collapsed
toggleRightBtn = CreateFrame("Button", "GOMove_BrowseToggleRight", BF, "UIPanelButtonTemplate")
toggleRightBtn:SetSize(40, 18)
toggleRightBtn:SetText(">>")
toggleRightBtn:SetPoint("TOPLEFT", BF, "TOPLEFT", 4, -4)
toggleRightBtn:SetFrameLevel(cBtn:GetFrameLevel())
toggleRightBtn:SetScript("OnClick", function()
    rightPanelVisible = not rightPanelVisible
    for _, el in ipairs(rightPanelElements) do
        if rightPanelVisible then el:Show() else el:Hide() end
    end
    div[leftPanelVisible and rightPanelVisible and "Show" or "Hide"](div)
    toggleRightBtn:SetText(rightPanelVisible and ">>" or "<<")
    -- hide the left toggle when right is collapsed
    if rightPanelVisible then toggleBtn:Show() else toggleBtn:Hide() end
    UpdateBFWidth()
end)

-- Resize grip
BF:SetResizable(true)
BF:SetMinResize(430, 300)
local bfResizeGrip = CreateFrame("Button", "GOMove_BrowseResizeGrip", BF)
bfResizeGrip:SetSize(16, 16)
bfResizeGrip:SetPoint("BOTTOMRIGHT", BF, "BOTTOMRIGHT", 0, 0)
bfResizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
bfResizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
bfResizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
bfResizeGrip:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then BF:StartSizing("BOTTOM") end
end)
bfResizeGrip:SetScript("OnMouseUp", function(self, button)
    BF:StopMovingOrSizing()
    if GOMove_Browser_UpdateRows then GOMove_Browser_UpdateRows() end
end)
BF:SetScript("OnSizeChanged", function(self, w, h)
    -- Recalculate visible rows from scroll area height (scroll top at -80, bottom at +24)
    VISIBLE_ROWS = math.max(1, math.floor((h - 104) / ROW_HEIGHT))
    -- Resize model frame height only (width is fixed)
    modelFrame:SetHeight(math.max(100, h - 270))
    if GOMove_Browser_UpdateRows then GOMove_Browser_UpdateRows() end
end)

end -- end BuildBrowserUI

local ok, err = pcall(BuildBrowserUI)
if not ok then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000GOMove Browser UI error: " .. tostring(err) .. "|r")
end

-- Browse button is created in GOMoveScripts.lua (references GOMove_BrowseFrame by global name)
