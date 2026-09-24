-- WarbandCamp/Core/GOMove.lua
-- Complete GOMove client engine ported into WarbandCamp.
-- Preserves all original GOMove tables, functions, data structures, protocol handling,
-- floating utility windows, and /gomove slash command.

local addonName, WBC = ...

GOMove = GOMove or {Frames = {}, Inputs = {}}
_G.GOMove = GOMove

function GOMove:Update()
    for _, Frame in ipairs(GOMove.Frames) do
        if Frame.Update then
            Frame:Update()
        end
    end
end

function GOMove:CreateFrame(name, width, height, DataTable, both)
    local Frame = CreateFrame("Frame", name, UIParent)
    Frame:SetMovable(true)
    Frame:EnableMouse(true)
    Frame:SetClampedToScreen(true)
    Frame:RegisterForDrag("LeftButton")
    Frame:SetScript("OnDragStart", Frame.StartMoving)
    Frame:SetScript("OnDragStop", Frame.StopMovingOrSizing)
    Frame:SetScript("OnHide", Frame.StopMovingOrSizing)
    Frame:SetSize(width, height)
    Frame:SetPoint("CENTER")
    Frame.ButtonCount = math.floor((height - 32) / 16)
    Frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 16,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    local NameFrame = CreateFrame("Frame", name .. "_Name", Frame)
    NameFrame:SetHeight(16)
    NameFrame:SetWidth(width - 16)
    NameFrame.text = NameFrame:CreateFontString()
    NameFrame.text:SetFont("Fonts\\MORPHEUS.ttf", 14)
    NameFrame.text:SetTextColor(0.8, 0.2, 0.2)
    NameFrame.text:SetJustifyH("LEFT")
    NameFrame.text:SetAllPoints()
    NameFrame.text:SetText(name:gsub("_", " "))
    NameFrame:SetPoint("TOPLEFT", Frame, "TOPLEFT", 8, -8)
    NameFrame:Show()
    Frame.NameFrame = NameFrame
    local CloseButton = CreateFrame("Button", name .. "_CloseButton", Frame)
    CloseButton:SetSize(25, 25)
    CloseButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    CloseButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    CloseButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    CloseButton:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", 0, 0)
    CloseButton:SetScript("OnClick", function() Frame:Hide() end)

    if DataTable then
        Frame.DataTable = DataTable
        function Frame:Update()
            local maxValue = #DataTable
            FauxScrollFrame_Update(self.ScrollBar, maxValue, self.ButtonCount, 16, nil, nil, nil, nil, nil, nil, true)
            local offset = FauxScrollFrame_GetOffset(self.ScrollBar)
            for idx = 1, self.ButtonCount do
                local value = idx + offset
                if value <= maxValue then
                    local Btn = self.Buttons[idx]
                    local Label = DataTable[value][1]
                    if DataTable.NameWidth and #DataTable[value][1] > DataTable.NameWidth then
                        Label = DataTable[value][1]:sub(0, DataTable.NameWidth - 2) .. ".."
                    end
                    if not both then
                        Btn:SetText(Label)
                    else
                        Btn:SetText(DataTable[value][2] .. " " .. Label)
                    end
                    Btn.MiscButton:Show()
                    Btn:Show()
                else
                    self.Buttons[idx]:Hide()
                    self.Buttons[idx].MiscButton:Hide()
                end
                if Frame.UpdateScript then
                    Frame:UpdateScript(idx)
                end
            end
        end

        local ScrollBar = CreateFrame("ScrollFrame", "$parent_ScrollBar", Frame, "FauxScrollFrameTemplate")
        ScrollBar:SetPoint("TOPLEFT", 0, -24)
        ScrollBar:SetPoint("BOTTOMRIGHT", -30, 8)

        ScrollBar:SetScript("OnVerticalScroll", function(self, offset)
            self.offset = math.floor(offset / 16 + 0.5)
            Frame:Update()
        end)

        ScrollBar:SetScript("OnShow", function()
            Frame:Update()
        end)

        Frame.ScrollBar = ScrollBar

        local Buttons = setmetatable({}, { __index = function(t, i)
            local Button = CreateFrame("Button", "$parent_Button" .. i, Frame)
            Button:SetSize(Frame:GetWidth() - 55, 16)
            Button:SetNormalFontObject(GameFontHighlightLeft)
            if i == 1 then
                Button:SetPoint("TOPLEFT", ScrollBar, 8, 0)
            else
                Button:SetPoint("TOPLEFT", Frame.Buttons[i - 1], "BOTTOMLEFT")
            end
            Button:SetScript("OnClick", function(self) if Frame.ButtonOnClick then Frame:ButtonOnClick(i) end end)
            local MiscButton = CreateFrame("Button", "$parent_Button" .. i .. "_Misc", Frame)
            MiscButton:SetSize(16, 16)
            MiscButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Disabled")
            MiscButton:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
            MiscButton:SetHighlightTexture("Interface\\Buttons\\UI-MinusButton-Up")
            MiscButton:SetNormalFontObject(GameFontHighlightLeft)
            MiscButton:SetPoint("TOPLEFT", Button, "TOPRIGHT", 0, 0)
            MiscButton:SetScript("OnClick", function(self) if Frame.MiscOnClick then Frame:MiscOnClick(i) end end)
            Button.MiscButton = MiscButton
            rawset(t, i, Button)
            return Button
        end })

        Frame.Buttons = Buttons
        Frame:Update()

        -- Resize grip (bottom-right corner)
        Frame:SetResizable(true)
        Frame:SetMinResize(150, 80)
        local resizeGrip = CreateFrame("Button", name .. "_ResizeGrip", Frame)
        resizeGrip:SetSize(16, 16)
        resizeGrip:SetPoint("BOTTOMRIGHT", Frame, "BOTTOMRIGHT", 0, 0)
        resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        resizeGrip:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then Frame:StartSizing("BOTTOMRIGHT") end
        end)
        resizeGrip:SetScript("OnMouseUp", function(self, button)
            Frame:StopMovingOrSizing()
            Frame:Update()
        end)
        Frame:SetScript("OnSizeChanged", function(self, w, h)
            self.ButtonCount = math.floor((h - 32) / 16)
            local i = 1
            while rawget(self.Buttons, i) do
                self.Buttons[i]:SetWidth(w - 55)
                i = i + 1
            end
            self:Update()
        end)
    end
    function Frame:Position(FramePoint, Parent, ParentPoint, Ox, Oy)
        Frame.Default = {FramePoint, Parent, ParentPoint, Ox, Oy}
        Frame:SetPoint(FramePoint, Parent, ParentPoint, Ox, Oy)
    end
    table.insert(GOMove.Frames, Frame)
    return Frame
end

function GOMove:CreateButton(Frame, name, width, height, Ox, Oy)
    local Button = CreateFrame("Button", Frame:GetName() .. "_" .. name, Frame, "UIPanelButtonTemplate")
    Button:SetSize(width, height)
    Button:SetText(name)
    Button:SetPoint("TOP", Frame, "TOP", Ox, Oy - 10)
    Button:SetScript("OnClick", function(self) if self.OnClick then self:OnClick(Frame) end end)
    return Button
end

function GOMove:CreateInput(Frame, name, width, height, Ox, Oy, letters, default)
    local Input = CreateFrame("EditBox", Frame:GetName() .. "_" .. name, Frame, "InputBoxTemplate")
    Input:SetSize(width, height)
    Input:SetPoint("TOP", Frame, "TOP", Ox + 2.5, Oy - 10)
    Input:SetAutoFocus(false)
    Input:SetNumeric(true)
    Input:SetMaxLetters(letters)
    Input:SetScript("OnEnterPressed", function() Input:ClearFocus() end)
    Input:SetScript("OnEscapePressed", function() Input:ClearFocus() end)
    if default then
        Input:SetNumber(default)
    end
    table.insert(GOMove.Inputs, Input)
    return Input
end

local trinityID = {}
local TIDs = 0
local function TID(name, reqguid, onetime)
    trinityID[name] = {TIDs, reqguid, onetime}
    TIDs = TIDs + 1
end

-- NEED to be in order (same as server-side CommandIDs enum)
TID("TEST",          false, true)
TID("SELECTNEAR",    false, true)
TID("DELETE",        true,  true)
TID("X",             true,  false)
TID("Y",             true,  false)
TID("Z",             true,  false)
TID("O",             true,  false)
TID("GROUND",        true,  false)
TID("FLOOR",         true,  false)
TID("RESPAWN",       true,  true)
TID("GOTO",          true,  true)
TID("FACE",          false, true)

TID("SPAWN",         false, true)
TID("NORTH",         true,  false)
TID("EAST",          true,  false)
TID("SOUTH",         true,  false)
TID("WEST",          true,  false)
TID("NORTHEAST",     true,  false)
TID("NORTHWEST",     true,  false)
TID("SOUTHEAST",     true,  false)
TID("SOUTHWEST",     true,  false)
TID("UP",            true,  false)
TID("DOWN",          true,  false)
TID("LEFT",          true,  false)
TID("RIGHT",         true,  false)
TID("PHASE",         true,  false)
TID("SCALE",         true,  false)
TID("SELECTALLNEAR", false, true)
TID("SPAWNSPELL",    false, true)

function GOMove:Move(ID, input)
    if UnitIsDeadOrGhost("player") then
        if UIErrorsFrame then UIErrorsFrame:AddMessage("You can't do that while dead.", 1.0, 0.0, 0.0, 53, 2) end
        return
    end
    for _, inputfield in ipairs(GOMove.Inputs) do
        inputfield:ClearFocus()
    end
    local ARG = 0
    if input then
        ARG = input
    end
    if not trinityID[ID] or not tonumber(trinityID[ID][1]) then
        return
    end
    if not trinityID[ID][2] then
        SendChatMessage(".gomove " .. trinityID[ID][1] .. " " .. (0) .. " " .. ARG, "SAY")
    elseif trinityID[ID][3] and tonumber(ARG) and tonumber(ARG) > 0 then
        SendChatMessage(".gomove " .. trinityID[ID][1] .. " " .. ARG .. " " .. (0), "SAY")
    else
        local did = false
        for GUID, NAME in pairs(GOMove.Selected) do
            if tonumber(GUID) then
                SendChatMessage(".gomove " .. trinityID[ID][1] .. " " .. GUID .. " " .. ARG, "SAY")
                if ID == "GOTO" then
                    return
                end
                did = true
            end
        end
        if not did then
            if UIErrorsFrame then UIErrorsFrame:AddMessage("No objects selected", 1.0, 0.0, 0.0, 53, 2) end
            return
        end
    end
end

-- ─── Data Tables ───────────────────────────────────────────────────────────
GOMove.FavL = {NameWidth = 17}
function GOMove.FavL:Add(name, guid)
    self:Del(guid)
    table.insert(self, 1, {name, guid})
    GOMoveSV.FavL = self
end
function GOMove.FavL:Del(guid)
    for k, v in ipairs(self) do
        if v[2] == guid then
            table.remove(self, k)
            break
        end
    end
    GOMoveSV.FavL = self
end

GOMove.SelL = {NameWidth = 17}
function GOMove.SelL:Add(name, guid, entry)
    table.insert(self, 1, {name, guid, entry})
end
function GOMove.SelL:Del(guid)
    for k, v in ipairs(self) do
        if v[2] == guid then
            table.remove(self, k)
            break
        end
    end
end

GOMove.Selected = {}
function GOMove.Selected:Add(name, guid)
    self[guid] = name
end
function GOMove.Selected:Del(guid)
    self[guid] = nil
end

-- ─── Floating Frames: Favourite List ───────────────────────────────────────
local FavFrame = GOMove:CreateFrame("Favourite_List", 200, 280, GOMove.FavL, true)
FavFrame:Position("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
FavFrame:Hide()
GOMove.FavFrame = FavFrame

function FavFrame:ButtonOnClick(ID)
    GOMove:Move("SPAWN", self.DataTable[FauxScrollFrame_GetOffset(self.ScrollBar) + ID][2])
end
function FavFrame:MiscOnClick(ID)
    self.DataTable:Del(self.DataTable[FauxScrollFrame_GetOffset(self.ScrollBar) + ID][2])
    self:Update()
end

-- ─── Floating Frames: Selection List ───────────────────────────────────────
local SelFrame = GOMove:CreateFrame("Selection_List", 250, 280, GOMove.SelL, true)
SelFrame:Position("BOTTOMRIGHT", FavFrame, "TOPRIGHT", 0, 0)
SelFrame:Hide()
GOMove.SelFrame = SelFrame

function SelFrame:ButtonOnClick(ID)
    local DATAID = FauxScrollFrame_GetOffset(self.ScrollBar) + ID
    if GOMove.Selected[self.DataTable[DATAID][2]] then
        GOMove.Selected:Del(self.DataTable[DATAID][2])
    else
        GOMove.Selected:Add(self.DataTable[DATAID][1], self.DataTable[DATAID][2])
    end
    self:Update()
end
function SelFrame:MiscOnClick(ID)
    local DATAID = FauxScrollFrame_GetOffset(self.ScrollBar) + ID
    GOMove.Selected:Del(self.DataTable[DATAID][2])
    self.DataTable:Del(self.DataTable[DATAID][2])
    self:Update()
end
function SelFrame:UpdateScript(ID)
    local DATAID = FauxScrollFrame_GetOffset(self.ScrollBar) + ID
    if self.DataTable[DATAID] then
        if GOMove.Selected[self.DataTable[DATAID][2]] then
            self.Buttons[ID]:GetFontString():SetTextColor(1, 0.8, 0)
        else
            self.Buttons[ID]:GetFontString():SetTextColor(1, 1, 1)
        end
    end
end

local ClearButton = CreateFrame("Button", SelFrame:GetName() .. "_ToggleSelect", SelFrame)
ClearButton:SetSize(16, 16)
ClearButton:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
ClearButton:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-OfficerNote-Up")
ClearButton:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
ClearButton:SetPoint("TOPRIGHT", SelFrame, "TOPRIGHT", -30, -5)
ClearButton:SetScript("OnClick", function()
    local empty = true
    for k, v in pairs(GOMove.Selected) do
        if tonumber(k) then
            empty = false
            break
        end
    end
    if empty then
        for _, tbl in ipairs(SelFrame.DataTable) do
            GOMove.Selected:Add(tbl[1], tbl[2])
        end
    else
        local toRemove = {}
        for k, _ in pairs(GOMove.Selected) do
            if tonumber(k) then
                table.insert(toRemove, k)
            end
        end
        for _, k in ipairs(toRemove) do
            GOMove.Selected:Del(k)
        end
    end
    SelFrame:Update()
end)

for i = 1, SelFrame.ButtonCount do
    local Button = SelFrame.Buttons[i]
    local MiscButton = Button.MiscButton
    local FavButton = CreateFrame("Button", Button:GetName() .. "_Favourite", MiscButton)
    FavButton:SetSize(16, 16)
    FavButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    FavButton:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
    FavButton:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilighted")
    FavButton:SetPoint("TOPRIGHT", MiscButton, "TOPLEFT", 0, 0)
    FavButton:SetScript("OnClick", function()
        local DATAID = FauxScrollFrame_GetOffset(SelFrame.ScrollBar) + i
        FavFrame.DataTable:Add(SelFrame.DataTable[DATAID][1], SelFrame.DataTable[DATAID][3])
        FavFrame:Update()
    end)
    local DeleteButton = CreateFrame("Button", Button:GetName() .. "_Delete", FavButton)
    DeleteButton:SetSize(16, 16)
    DeleteButton:SetNormalTexture("Interface\\PaperDollInfoFrame\\SpellSchoolIcon5")
    DeleteButton:SetPushedTexture("Interface\\PaperDollInfoFrame\\SpellSchoolIcon7")
    DeleteButton:SetHighlightTexture("Interface\\PaperDollInfoFrame\\SpellSchoolIcon3")
    DeleteButton:SetPoint("TOPRIGHT", FavButton, "TOPLEFT", 0, 0)
    DeleteButton:SetScript("OnClick", function()
        GOMove:Move("DELETE", SelFrame.DataTable[FauxScrollFrame_GetOffset(SelFrame.ScrollBar) + i][2])
    end)
    local SpawnButton = CreateFrame("Button", Button:GetName() .. "_Spawn", DeleteButton)
    SpawnButton:SetSize(16, 16)
    SpawnButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    SpawnButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    SpawnButton:SetHighlightTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    SpawnButton:SetPoint("TOPRIGHT", DeleteButton, "TOPLEFT", 0, 0)
    SpawnButton:SetScript("OnClick", function()
        GOMove:Move("SPAWN", SelFrame.DataTable[FauxScrollFrame_GetOffset(SelFrame.ScrollBar) + i][3])
    end)
end

local EmptyButton = CreateFrame("Button", SelFrame:GetName() .. "_EmptyButton", SelFrame)
EmptyButton:SetSize(30, 30)
EmptyButton:SetNormalTexture("Interface\\Buttons\\CancelButton-Up")
EmptyButton:SetPushedTexture("Interface\\Buttons\\CancelButton-Down")
EmptyButton:SetHighlightTexture("Interface\\Buttons\\CancelButton-Highlight")
EmptyButton:SetPoint("TOPRIGHT", SelFrame, "TOPRIGHT", -45, 0)
EmptyButton:SetHitRectInsets(9, 7, 7, 10)
EmptyButton:SetScript("OnClick", function()
    local toRemove = {}
    for k, _ in pairs(GOMove.Selected) do
        if tonumber(k) then
            table.insert(toRemove, k)
        end
    end
    for _, k in ipairs(toRemove) do
        GOMove.Selected:Del(k)
    end
    for i = #SelFrame.DataTable, 1, -1 do
        table.remove(SelFrame.DataTable, i)
    end
    SelFrame:Update()
end)

-- ─── Floating Frames: Main Keypad UI ───────────────────────────────────────
local MainFrame = GOMove:CreateFrame("GOMove_UI", 170, 490)
GOMove.MainFrame = MainFrame
MainFrame:Position("LEFT", UIParent, "LEFT", 0, 85)
MainFrame:Hide()

local NEWS = GOMove:CreateInput(MainFrame, "NEWS", 40, 25, 0, -50, 4, 30)
GOMove.Inputs_NEWS = NEWS

local NORTH = GOMove:CreateButton(MainFrame, "N", 50, 25, 0, -25)
function NORTH:OnClick() GOMove:Move("NORTH", NEWS:GetNumber()) end
local EAST = GOMove:CreateButton(MainFrame, "E", 50, 25, 50, -50)
function EAST:OnClick() GOMove:Move("EAST", NEWS:GetNumber()) end
local SOUTH = GOMove:CreateButton(MainFrame, "S", 50, 25, 0, -75)
function SOUTH:OnClick() GOMove:Move("SOUTH", NEWS:GetNumber()) end
local WEST = GOMove:CreateButton(MainFrame, "W", 50, 25, -50, -50)
function WEST:OnClick() GOMove:Move("WEST", NEWS:GetNumber()) end

local NORTHEAST = GOMove:CreateButton(MainFrame, "NE", 40, 20, 45, -30)
function NORTHEAST:OnClick() GOMove:Move("NORTHEAST", NEWS:GetNumber()) end
local NORTHWEST = GOMove:CreateButton(MainFrame, "NW", 40, 20, -45, -30)
function NORTHWEST:OnClick() GOMove:Move("NORTHWEST", NEWS:GetNumber()) end
local SOUTHEAST = GOMove:CreateButton(MainFrame, "SE", 40, 20, 45, -75)
function SOUTHEAST:OnClick() GOMove:Move("SOUTHEAST", NEWS:GetNumber()) end
local SOUTHWEST = GOMove:CreateButton(MainFrame, "SW", 40, 20, -45, -75)
function SOUTHWEST:OnClick() GOMove:Move("SOUTHWEST", NEWS:GetNumber()) end

local X = GOMove:CreateButton(MainFrame, "X", 35, 20, -60, -105)
function X:OnClick() GOMove:Move("X") end
local Y = GOMove:CreateButton(MainFrame, "Y", 35, 20, -20, -105)
function Y:OnClick() GOMove:Move("Y") end
local Z = GOMove:CreateButton(MainFrame, "Z", 35, 20, 20, -105)
function Z:OnClick() GOMove:Move("Z") end
local O = GOMove:CreateButton(MainFrame, "O", 35, 20, 60, -105)
function O:OnClick() GOMove:Move("O") end

local ROTHEI = GOMove:CreateInput(MainFrame, "ROTHEI", 40, 25, 0, -155, 4, 30)
GOMove.Inputs_ROTHEI = ROTHEI

local UP = GOMove:CreateButton(MainFrame, "Up", 40, 25, 0, -130)
function UP:OnClick() GOMove:Move("UP", ROTHEI:GetNumber()) end
local DOWN = GOMove:CreateButton(MainFrame, "Down", 40, 25, 0, -180)
function DOWN:OnClick() GOMove:Move("DOWN", ROTHEI:GetNumber()) end
local RIGHT = GOMove:CreateButton(MainFrame, "Right", 40, 25, 45, -155)
function RIGHT:OnClick() GOMove:Move("RIGHT", ROTHEI:GetNumber()) end
local LEFT = GOMove:CreateButton(MainFrame, "Left", 40, 25, -45, -155)
function LEFT:OnClick() GOMove:Move("LEFT", ROTHEI:GetNumber()) end

local RESPAWN = GOMove:CreateButton(MainFrame, "Respawn", 65, 25, -35, -237.5)
function RESPAWN:OnClick() GOMove:Move("RESPAWN") end
local FLOOR = GOMove:CreateButton(MainFrame, "Floor", 65, 25, 35, -237.5)
function FLOOR:OnClick() GOMove:Move("FLOOR") end
local SELECTNEAR = GOMove:CreateButton(MainFrame, "Target", 50, 25, 55, -210)
function SELECTNEAR:OnClick() GOMove:Move("SELECTNEAR") end
local FACE = GOMove:CreateButton(MainFrame, "Snap", 50, 25, 0, -210)
function FACE:OnClick() GOMove:Move("FACE") end
local DELETE = GOMove:CreateButton(MainFrame, "Delete", 50, 25, -55, -210)
function DELETE:OnClick() GOMove:Move("DELETE") end

local GROUND = GOMove:CreateButton(MainFrame, "Ground", 70, 25, -40, -265)
function GROUND:OnClick() GOMove:Move("GROUND") end
local GOTO = GOMove:CreateButton(MainFrame, "Go to", 70, 25, 40, -265)
function GOTO:OnClick() GOMove:Move("GOTO") end

local ENTRY = GOMove:CreateInput(MainFrame, "ENTRY", 65, 25, -30, -295, 10)
local SPAWN = GOMove:CreateButton(MainFrame, "Spawn", 50, 25, 40, -295)
function SPAWN:OnClick() GOMove:Move("SPAWN", ENTRY:GetNumber()) end

local RADIUS = GOMove:CreateInput(MainFrame, "RADIUS", 40, 25, -55, -325, 4)
local SELECTALLNEAR = GOMove:CreateButton(MainFrame, "Select by radius", 110, 25, 25, -325)
function SELECTALLNEAR:OnClick() GOMove:Move("SELECTALLNEAR", RADIUS:GetNumber()) end

local MASK = GOMove:CreateInput(MainFrame, "MASK", 65, 25, -30, -355, 10)
local PHASE = GOMove:CreateButton(MainFrame, "Phase", 50, 25, 40, -355)
function PHASE:OnClick() GOMove:Move("PHASE", MASK:GetNumber()) end

local FAVOURITES = GOMove:CreateButton(MainFrame, "Favourites", 80, 25, -40, -385)
function FAVOURITES:OnClick()
    if FavFrame:IsVisible() then FavFrame:Hide() else FavFrame:Show() end
end
local SELECTIONS = GOMove:CreateButton(MainFrame, "Selections", 80, 25, 40, -385)
function SELECTIONS:OnClick()
    if SelFrame:IsVisible() then SelFrame:Hide() else SelFrame:Show() end
end

local SPELLENTRY = GOMove:CreateInput(MainFrame, "SPELLENTRY", 65, 25, -30, -415, 10)
local SPELLSPAWN = GOMove:CreateButton(MainFrame, "Send", 50, 25, 40, -415)
function SPELLSPAWN:OnClick()
    GOMove:Move("SPAWNSPELL", SPELLENTRY:GetNumber())
    CastSpellByID(27651)
end

local BROWSE = GOMove:CreateButton(MainFrame, "Browse / Search", 155, 22, 0, -445)
function BROWSE:OnClick()
    if GOMove_ToggleBrowser then
        GOMove_ToggleBrowser()
    else
        local bf = _G["GOMove_BrowseFrame"]
        if bf then if bf:IsVisible() then bf:Hide() else bf:Show() end end
    end
end

-- ─── Slash Commands & Helpers ──────────────────────────────────────────────
GOMove.SCMD = {}
function GOMove.SCMD.help()
    for k, _ in pairs(GOMove.SCMD) do print(k) end
end
function GOMove.SCMD.reset()
    for _, inputfield in ipairs(GOMove.Inputs) do inputfield:ClearFocus() end
    print("Frames reset")
    for _, Frame in pairs(GOMove.Frames) do
        if Frame.Default then
            Frame:ClearAllPoints()
            Frame:SetPoint(Frame.Default[1], Frame.Default[2], Frame.Default[3], Frame.Default[4], Frame.Default[5])
        end
        Frame:Show()
    end
end
function GOMove.SCMD.invertselection()
    local sel = {}
    for GUID, _ in pairs(GOMove.Selected) do
        if tonumber(GUID) then table.insert(sel, GUID) end
    end
    for _, tbl in ipairs(SelFrame.DataTable) do
        GOMove.Selected:Add(tbl[1], tbl[2])
    end
    for _, v in ipairs(sel) do
        GOMove.Selected:Del(v)
    end
    SelFrame:Update()
end

SLASH_GOMOVE1 = '/gomove'
SlashCmdList.GOMOVE = function(msg)
    msg = msg or ""
    if msg ~= "" then
        for k, v in pairs(GOMove.SCMD) do
            if type(k) == "string" and string.find(k, msg:lower()) == 1 and type(v) == "function" then
                v()
                return
            end
        end
        return
    end
    if MainFrame:IsVisible() then MainFrame:Hide() else MainFrame:Show() end
end

-- ─── Event Handling ────────────────────────────────────────────────────────
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("CHAT_MSG_ADDON")

EventFrame:SetScript("OnEvent", function(self, event, MSG, MSG2, Type, Sender)
    if event == "CHAT_MSG_ADDON" and Sender == UnitName("player") then
        if MSG ~= "GOMOVE" then return end
        local ID, ENTRYORGUID, ARG2, ARG3 = MSG2:match("^([^|]+)|([%a%d]+)|(.*)|([%a%d]+)$")
        if ID then
            if ID == "REMOVE" then
                local guid = ENTRYORGUID
                GOMove.Selected:Del(guid)
                for _, tbl in ipairs(GOMove.SelL) do
                    if tbl[2] == guid then
                        GOMove.SelL:Del(guid)
                        break
                    end
                end
                GOMove:Update()
            elseif ID == "ADD" then
                local guid = ENTRYORGUID
                GOMove.Selected:Add(ARG2, guid)
                local exists = false
                for _, tbl in ipairs(GOMove.SelL) do
                    if tbl[2] == guid then
                        exists = true
                        break
                    end
                end
                if not exists then
                    GOMove.SelL:Add(ARG2, guid, ARG3)
                end
                GOMove:Update()
            elseif ID == "SWAP" then
                local oldGUID, newGUID = ENTRYORGUID, ARG3
                local oldName = GOMove.Selected[oldGUID] or ARG2 or ""
                GOMove.Selected:Add(oldName, newGUID)
                GOMove.Selected:Del(oldGUID)
                for _, tbl in ipairs(GOMove.SelL) do
                    if tbl[2] == oldGUID then
                        tbl[2] = newGUID
                        break
                    end
                end
                GOMove:Update()
            end
        end
    elseif (MSG == addonName or MSG == "GOMove") and event == "ADDON_LOADED" then
        if not GOMoveSV or type(GOMoveSV) ~= "table" then
            GOMoveSV = {}
        end
        _G.GOMoveSV = GOMoveSV
        if GOMoveSV.FavL then
            for k, v in ipairs(GOMoveSV.FavL) do
                GOMove.FavL[k] = v
            end
        end
        for _, frame in ipairs(GOMove.Frames) do
            frame:Hide()
        end
        GOMove:Update()
    end
end)
