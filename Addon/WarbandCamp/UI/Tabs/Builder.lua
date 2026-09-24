-- WarbandCamp/UI/Tabs/Builder.lua
-- GOMove Tab: GameObject builder, positioning keypad, elevation, rotation,
-- scale overrides, selection manager, and 3D browser launcher inside WarbandCamp.

local addonName, WBC = ...

local function gomoveBuilder(parent)
    local c = WBC.colors

    -- ─── Top Action Bar ────────────────────────────────────────────────────
    local topBar = CreateFrame("Frame", nil, parent)
    topBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -6)
    topBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -6)
    topBar:SetHeight(26)

    local browseBtn = WBC.MakeFlatButton(topBar, 150, 24, "Browse 3D Objects", { justify = "CENTER" })
    browseBtn:SetPoint("LEFT", topBar, "LEFT", 0, 0)
    browseBtn:SetScript("OnClick", function()
        if GOMove_ToggleBrowser then
            GOMove_ToggleBrowser()
        else
            local bf = _G["GOMove_BrowseFrame"]
            if bf then if bf:IsVisible() then bf:Hide() else bf:Show() end end
        end
    end)
    browseBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("3D Camp Object Browser", 1, 0.82, 0.30)
        GameTooltip:AddLine("Opens the interactive 3D model viewer and search engine to place objects in your Warband Camp.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    browseBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local hudBtn = WBC.MakeFlatButton(topBar, 140, 24, "Pop-out Keypad HUD", { justify = "CENTER" })
    hudBtn:SetPoint("LEFT", browseBtn, "RIGHT", 6, 0)
    hudBtn:SetScript("OnClick", function()
        if GOMove.MainFrame then
            if GOMove.MainFrame:IsVisible() then
                GOMove.MainFrame:Hide()
            else
                GOMove.MainFrame:Show()
            end
        end
    end)
    hudBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("Floating Keypad HUD", 1, 0.82, 0.30)
        GameTooltip:AddLine("Toggles the compact floating movement keypad on screen so you can adjust objects while walking around.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    hudBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local floatListsBtn = WBC.MakeFlatButton(topBar, 130, 24, "Floating Lists", { justify = "CENTER" })
    floatListsBtn:SetPoint("LEFT", hudBtn, "RIGHT", 6, 0)
    floatListsBtn:SetScript("OnClick", function()
        if GOMove.SelFrame then
            if GOMove.SelFrame:IsVisible() then
                GOMove.SelFrame:Hide()
                if GOMove.FavFrame then GOMove.FavFrame:Hide() end
            else
                GOMove.SelFrame:Show()
                if GOMove.FavFrame then GOMove.FavFrame:Show() end
            end
        end
    end)
    floatListsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("Floating Selection & Favs", 1, 0.82, 0.30)
        GameTooltip:AddLine("Toggles the floating Selection and Favorites list frames on screen.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    floatListsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local targetNearBtn = WBC.MakeFlatButton(topBar, 110, 24, "Target Nearest", { justify = "CENTER" })
    targetNearBtn:SetPoint("LEFT", floatListsBtn, "RIGHT", 6, 0)
    targetNearBtn:SetScript("OnClick", function() GOMove:Move("SELECTNEAR") end)

    local selectAllBtn = WBC.MakeFlatButton(topBar, 110, 24, "Select Nearby", { justify = "CENTER" })
    selectAllBtn:SetPoint("LEFT", targetNearBtn, "RIGHT", 6, 0)
    selectAllBtn:SetScript("OnClick", function() GOMove:Move("SELECTALLNEAR", 30) end)

    -- ─── Content Body ──────────────────────────────────────────────────────
    local body = CreateFrame("Frame", nil, parent)
    body:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -8)
    body:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 26)

    -- ─── Left Column: Positioning, Keypad, Elevation, Resets ───────────────
    local colLeft = CreateFrame("Frame", nil, body)
    colLeft:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    colLeft:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
    colLeft:SetWidth(360)

    local hdrCompass = WBC.CreateSectionHeader(colLeft, "Nudge & Compass")
    hdrCompass:SetPoint("TOPLEFT", colLeft, "TOPLEFT", 0, 0)

    -- Step distance editbox
    local distLabel = colLeft:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    distLabel:SetPoint("TOPLEFT", hdrCompass, "BOTTOMLEFT", 0, -8)
    distLabel:SetText("Step distance (yd):")

    local distBox = WBC.MakeFlatEditBox(colLeft, 60, 22, "30", true)
    distBox:SetPoint("LEFT", distLabel, "RIGHT", 8, 0)
    distBox:SetText("30")

    local function getDist()
        local n = tonumber(distBox:GetText())
        return (n and n > 0) and n or 30
    end

    -- Compass 3x3 Keypad
    local keypad = CreateFrame("Frame", nil, colLeft)
    keypad:SetSize(190, 84)
    keypad:SetPoint("TOPLEFT", distLabel, "BOTTOMLEFT", 0, -8)

    local btnNW = WBC.MakeFlatButton(keypad, 44, 24, "NW", { justify = "CENTER" })
    btnNW:SetPoint("TOPLEFT", keypad, "TOPLEFT", 0, 0)
    btnNW:SetScript("OnClick", function() GOMove:Move("NORTHWEST", getDist()) end)

    local btnN = WBC.MakeFlatButton(keypad, 54, 24, "N", { justify = "CENTER" })
    btnN:SetPoint("LEFT", btnNW, "RIGHT", 4, 0)
    btnN:SetScript("OnClick", function() GOMove:Move("NORTH", getDist()) end)

    local btnNE = WBC.MakeFlatButton(keypad, 44, 24, "NE", { justify = "CENTER" })
    btnNE:SetPoint("LEFT", btnN, "RIGHT", 4, 0)
    btnNE:SetScript("OnClick", function() GOMove:Move("NORTHEAST", getDist()) end)

    local btnW = WBC.MakeFlatButton(keypad, 44, 24, "W", { justify = "CENTER" })
    btnW:SetPoint("TOPLEFT", btnNW, "BOTTOMLEFT", 0, -4)
    btnW:SetScript("OnClick", function() GOMove:Move("WEST", getDist()) end)

    local btnCenter = WBC.MakeFlatButton(keypad, 54, 24, "Face", { justify = "CENTER" })
    btnCenter:SetPoint("LEFT", btnW, "RIGHT", 4, 0)
    btnCenter:SetScript("OnClick", function() GOMove:Move("FACE") end)
    btnCenter:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Snap to Facing", 1, 0.82, 0.30)
        GameTooltip:AddLine("Rotates selected object(s) to match your character's current facing angle.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnCenter:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local btnE = WBC.MakeFlatButton(keypad, 44, 24, "E", { justify = "CENTER" })
    btnE:SetPoint("LEFT", btnCenter, "RIGHT", 4, 0)
    btnE:SetScript("OnClick", function() GOMove:Move("EAST", getDist()) end)

    local btnSW = WBC.MakeFlatButton(keypad, 44, 24, "SW", { justify = "CENTER" })
    btnSW:SetPoint("TOPLEFT", btnW, "BOTTOMLEFT", 0, -4)
    btnSW:SetScript("OnClick", function() GOMove:Move("SOUTHWEST", getDist()) end)

    local btnS = WBC.MakeFlatButton(keypad, 54, 24, "S", { justify = "CENTER" })
    btnS:SetPoint("LEFT", btnSW, "RIGHT", 4, 0)
    btnS:SetScript("OnClick", function() GOMove:Move("SOUTH", getDist()) end)

    local btnSE = WBC.MakeFlatButton(keypad, 44, 24, "SE", { justify = "CENTER" })
    btnSE:SetPoint("LEFT", btnS, "RIGHT", 4, 0)
    btnSE:SetScript("OnClick", function() GOMove:Move("SOUTHEAST", getDist()) end)

    -- Elevation & Rotation section
    local hdrElev = WBC.CreateSectionHeader(colLeft, "Elevation & Rotation")
    hdrElev:SetPoint("TOPLEFT", keypad, "BOTTOMLEFT", 0, -10)

    local stepLabel = colLeft:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stepLabel:SetPoint("TOPLEFT", hdrElev, "BOTTOMLEFT", 0, -8)
    stepLabel:SetText("Rot/Elev step:")

    local stepBox = WBC.MakeFlatEditBox(colLeft, 60, 22, "30", true)
    stepBox:SetPoint("LEFT", stepLabel, "RIGHT", 8, 0)
    stepBox:SetText("30")

    local function getStep()
        local n = tonumber(stepBox:GetText())
        return (n and n > 0) and n or 30
    end

    local elevPad = CreateFrame("Frame", nil, colLeft)
    elevPad:SetSize(240, 54)
    elevPad:SetPoint("TOPLEFT", stepLabel, "BOTTOMLEFT", 0, -8)

    local btnUp = WBC.MakeFlatButton(elevPad, 55, 24, "Up", { justify = "CENTER" })
    btnUp:SetPoint("TOPLEFT", elevPad, "TOPLEFT", 0, 0)
    btnUp:SetScript("OnClick", function() GOMove:Move("UP", getStep()) end)

    local btnDown = WBC.MakeFlatButton(elevPad, 55, 24, "Down", { justify = "CENTER" })
    btnDown:SetPoint("LEFT", btnUp, "RIGHT", 4, 0)
    btnDown:SetScript("OnClick", function() GOMove:Move("DOWN", getStep()) end)

    local btnLeft = WBC.MakeFlatButton(elevPad, 55, 24, "Turn L", { justify = "CENTER" })
    btnLeft:SetPoint("LEFT", btnDown, "RIGHT", 4, 0)
    btnLeft:SetScript("OnClick", function() GOMove:Move("LEFT", getStep()) end)

    local btnRight = WBC.MakeFlatButton(elevPad, 55, 24, "Turn R", { justify = "CENTER" })
    btnRight:SetPoint("LEFT", btnLeft, "RIGHT", 4, 0)
    btnRight:SetScript("OnClick", function() GOMove:Move("RIGHT", getStep()) end)

    local btnFloor = WBC.MakeFlatButton(elevPad, 55, 22, "Floor", { justify = "CENTER" })
    btnFloor:SetPoint("TOPLEFT", btnUp, "BOTTOMLEFT", 0, -4)
    btnFloor:SetScript("OnClick", function() GOMove:Move("FLOOR") end)

    local btnGround = WBC.MakeFlatButton(elevPad, 55, 22, "Ground", { justify = "CENTER" })
    btnGround:SetPoint("LEFT", btnFloor, "RIGHT", 4, 0)
    btnGround:SetScript("OnClick", function() GOMove:Move("GROUND") end)

    local btnGoto = WBC.MakeFlatButton(elevPad, 55, 22, "Go to", { justify = "CENTER" })
    btnGoto:SetPoint("LEFT", btnGround, "RIGHT", 4, 0)
    btnGoto:SetScript("OnClick", function() GOMove:Move("GOTO") end)

    local btnRespawn = WBC.MakeFlatButton(elevPad, 55, 22, "Respawn", { justify = "CENTER" })
    btnRespawn:SetPoint("LEFT", btnGoto, "RIGHT", 4, 0)
    btnRespawn:SetScript("OnClick", function() GOMove:Move("RESPAWN") end)

    -- Axis resets (X, Y, Z, O)
    local axisRow = CreateFrame("Frame", nil, colLeft)
    axisRow:SetSize(240, 24)
    axisRow:SetPoint("TOPLEFT", elevPad, "BOTTOMLEFT", 0, -8)

    local btnX = WBC.MakeFlatButton(axisRow, 42, 22, "X", { justify = "CENTER" })
    btnX:SetPoint("LEFT", axisRow, "LEFT", 0, 0)
    btnX:SetScript("OnClick", function() GOMove:Move("X") end)

    local btnY = WBC.MakeFlatButton(axisRow, 42, 22, "Y", { justify = "CENTER" })
    btnY:SetPoint("LEFT", btnX, "RIGHT", 4, 0)
    btnY:SetScript("OnClick", function() GOMove:Move("Y") end)

    local btnZ = WBC.MakeFlatButton(axisRow, 42, 22, "Z", { justify = "CENTER" })
    btnZ:SetPoint("LEFT", btnY, "RIGHT", 4, 0)
    btnZ:SetScript("OnClick", function() GOMove:Move("Z") end)

    local btnO = WBC.MakeFlatButton(axisRow, 42, 22, "O", { justify = "CENTER" })
    btnO:SetPoint("LEFT", btnZ, "RIGHT", 4, 0)
    btnO:SetScript("OnClick", function() GOMove:Move("O") end)

    -- Scale and Phase section
    local hdrProps = WBC.CreateSectionHeader(colLeft, "Scale & Phase Overrides")
    hdrProps:SetPoint("TOPLEFT", axisRow, "BOTTOMLEFT", 0, -10)

    -- Scale Row
    local scaleBox = WBC.MakeFlatEditBox(colLeft, 70, 22, "1.0", true)
    scaleBox:SetPoint("TOPLEFT", hdrProps, "BOTTOMLEFT", 0, -8)
    scaleBox:SetText("1.0")

    local scaleBtn = WBC.MakeFlatButton(colLeft, 80, 22, "Set Scale", { justify = "CENTER" })
    scaleBtn:SetPoint("LEFT", scaleBox, "RIGHT", 6, 0)
    scaleBtn:SetScript("OnClick", function()
        local sc = tonumber(scaleBox:GetText())
        if sc and sc > 0 then
            GOMove:Move("SCALE", sc)
        else
            WBC.Warn("enter a valid scale number (e.g. 1.0, 1.5, 0.8)")
        end
    end)

    -- Phase Row
    local phaseBox = WBC.MakeFlatEditBox(colLeft, 70, 22, "1", true)
    phaseBox:SetPoint("LEFT", scaleBtn, "RIGHT", 10, 0)
    phaseBox:SetText("1")

    local phaseBtn = WBC.MakeFlatButton(colLeft, 80, 22, "Set Phase", { justify = "CENTER" })
    phaseBtn:SetPoint("LEFT", phaseBox, "RIGHT", 6, 0)
    phaseBtn:SetScript("OnClick", function()
        if not WBC.IsGM() then
            WBC.Warn("Camp objects automatically inherit your camp phase mask.")
            return
        end
        local ph = tonumber(phaseBox:GetText())
        if ph and ph >= 0 then
            GOMove:Move("PHASE", ph)
        else
            WBC.Warn("enter a valid phase mask integer (e.g. 1, 169)")
        end
    end)
    phaseBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Phase Mask", 1, 0.82, 0.30)
        if WBC.IsGM() then
            GameTooltip:AddLine("Set the phase mask for the selected world object.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("Camp objects automatically inherit your personal camp phase. (GM administrative setting)", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    phaseBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Spawn direct by Entry
    local spawnBox = WBC.MakeFlatEditBox(colLeft, 100, 22, "Entry ID", true)
    spawnBox:SetPoint("TOPLEFT", scaleBox, "BOTTOMLEFT", 0, -8)

    local spawnBtn = WBC.MakeFlatButton(colLeft, 80, 22, "Spawn", { justify = "CENTER" })
    spawnBtn:SetPoint("LEFT", spawnBox, "RIGHT", 6, 0)
    spawnBtn:SetScript("OnClick", function()
        local ent = tonumber(spawnBox:GetText())
        if ent and ent > 0 then
            GOMove:Move("SPAWN", ent)
        else
            WBC.Warn("enter a valid GameObject Entry ID")
        end
    end)

    local spellSpawnBtn = WBC.MakeFlatButton(colLeft, 110, 22, "Target Spell", { justify = "CENTER" })
    spellSpawnBtn:SetPoint("LEFT", spawnBtn, "RIGHT", 6, 0)
    spellSpawnBtn:SetScript("OnClick", function()
        local ent = tonumber(spawnBox:GetText())
        if ent and ent > 0 then
            GOMove:Move("SPAWNSPELL", ent)
            CastSpellByID(27651)
        else
            WBC.Warn("enter a valid GameObject Entry ID to place with spell")
        end
    end)

    -- ─── Right Column: Selection List & Favorites ──────────────────────────
    local colRight = CreateFrame("Frame", nil, body)
    colRight:SetPoint("TOPLEFT", colLeft, "TOPRIGHT", 16, 0)
    colRight:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)

    local hdrSel = WBC.CreateSectionHeader(colRight, "Selected Objects")
    hdrSel:SetPoint("TOPLEFT", colRight, "TOPLEFT", 0, 0)

    local selCountFS = colRight:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selCountFS:SetPoint("LEFT", hdrSel, "RIGHT", 8, 0)

    local deselectAllBtn = WBC.MakeFlatButton(colRight, 80, 20, "Deselect", { justify = "CENTER" })
    deselectAllBtn:SetPoint("TOPRIGHT", colRight, "TOPRIGHT", 0, 0)
    deselectAllBtn:SetScript("OnClick", function()
        local toRemove = {}
        for k, _ in pairs(GOMove.Selected) do
            if tonumber(k) then table.insert(toRemove, k) end
        end
        for _, k in ipairs(toRemove) do GOMove.Selected:Del(k) end
        GOMove:Update()
    end)

    local delBtn = WBC.MakeFlatButton(colRight, 85, 20, "Delete Selected", { justify = "CENTER", danger = true })
    delBtn:SetPoint("RIGHT", deselectAllBtn, "LEFT", -6, 0)
    delBtn:SetScript("OnClick", function()
        GOMove:Move("DELETE")
    end)

    -- Scroll area for selection list
    local selArea = CreateFrame("Frame", nil, colRight)
    selArea:SetPoint("TOPLEFT", hdrSel, "BOTTOMLEFT", 0, -6)
    selArea:SetPoint("RIGHT", colRight, "RIGHT", 0, 0)
    selArea:SetHeight(160)
    WBC.ApplyBackdrop(selArea, "inset", 0.6, 0.02, 0.03, 0.05)

    local scrollSel, contentSel = WBC.CreateScrollContent(selArea)

    local emptySel = contentSel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptySel:SetPoint("CENTER", selArea, "CENTER", 0, 0)
    emptySel:SetText("No objects selected.\nTarget an object or click Target Nearest / Select Nearby.")

    -- Refresh selection list UI
    local poolSel = {}
    local function refreshSelection()
        local count = 0
        for k, _ in pairs(GOMove.Selected) do
            if tonumber(k) then count = count + 1 end
        end
        selCountFS:SetText(c.accent .. count .. " selected" .. c.reset)

        for _, b in ipairs(poolSel) do b:Hide() end

        local data = GOMove.SelL or {}
        if #data == 0 then
            emptySel:Show()
            contentSel:SetHeight(150)
            return
        end
        emptySel:Hide()

        local y = -2
        for i, item in ipairs(data) do
            local name = item[1] or "Unknown"
            local guid = item[2]
            local entry = item[3]
            local isSel = GOMove.Selected[guid] ~= nil

            local row = poolSel[i]
            if not row then
                row = CreateFrame("Frame", nil, contentSel)
                row:SetSize(340, 22)

                local btnPick = WBC.MakeFlatButton(row, 200, 20, "")
                btnPick:SetPoint("LEFT", row, "LEFT", 2, 0)
                row.btnPick = btnPick

                local btnFav = WBC.MakeFlatButton(row, 24, 20, "+", { justify = "CENTER" })
                btnFav:SetPoint("LEFT", btnPick, "RIGHT", 4, 0)
                row.btnFav = btnFav

                local btnSpawn = WBC.MakeFlatButton(row, 50, 20, "Clone", { justify = "CENTER" })
                btnSpawn:SetPoint("LEFT", btnFav, "RIGHT", 4, 0)
                row.btnSpawn = btnSpawn

                local btnDel = WBC.MakeFlatButton(row, 44, 20, "Del", { justify = "CENTER", danger = true })
                btnDel:SetPoint("LEFT", btnSpawn, "RIGHT", 4, 0)
                row.btnDel = btnDel

                poolSel[i] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", contentSel, "TOPLEFT", 2, y)

            local dispName = (name:len() > 22) and (name:sub(1, 20) .. "..") or name
            row.btnPick.label:SetText((isSel and c.good or c.white) .. dispName .. c.reset .. " " .. c.muted .. "#" .. tostring(guid) .. c.reset)
            row.btnPick:SetScript("OnClick", function()
                if GOMove.Selected[guid] then
                    GOMove.Selected:Del(guid)
                else
                    GOMove.Selected:Add(name, guid)
                end
                GOMove:Update()
            end)

            row.btnFav:SetScript("OnClick", function()
                if GOMove.FavL and entry then
                    GOMove.FavL:Add(name, entry)
                    GOMove:Update()
                    WBC.Print("Added " .. name .. " to favorites.")
                end
            end)

            row.btnSpawn:SetScript("OnClick", function()
                if entry then GOMove:Move("SPAWN", entry) end
            end)

            row.btnDel:SetScript("OnClick", function()
                GOMove:Move("DELETE", guid)
            end)

            row:Show()
            y = y - 24
        end
        contentSel:SetHeight(-y + 8)
    end

    -- Favorites section
    local hdrFav = WBC.CreateSectionHeader(colRight, "Favorite Objects")
    hdrFav:SetPoint("TOPLEFT", selArea, "BOTTOMLEFT", 0, -10)

    local favArea = CreateFrame("Frame", nil, colRight)
    favArea:SetPoint("TOPLEFT", hdrFav, "BOTTOMLEFT", 0, -6)
    favArea:SetPoint("BOTTOMRIGHT", colRight, "BOTTOMRIGHT", 0, 0)
    WBC.ApplyBackdrop(favArea, "inset", 0.6, 0.02, 0.03, 0.05)

    local scrollFav, contentFav = WBC.CreateScrollContent(favArea)

    local emptyFav = contentFav:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyFav:SetPoint("CENTER", favArea, "CENTER", 0, 0)
    emptyFav:SetText("No favorite objects saved yet.\nClick [+] on any selected object or use the 3D Browser to add favorites.")

    local poolFav = {}
    local function refreshFavorites()
        for _, b in ipairs(poolFav) do b:Hide() end

        local data = GOMove.FavL or {}
        if #data == 0 then
            emptyFav:Show()
            contentFav:SetHeight(120)
            return
        end
        emptyFav:Hide()

        local y = -2
        for i, item in ipairs(data) do
            local name = item[1] or "Unknown"
            local entry = item[2]

            local row = poolFav[i]
            if not row then
                row = CreateFrame("Frame", nil, contentFav)
                row:SetSize(340, 22)

                local btnSpawn = WBC.MakeFlatButton(row, 280, 20, "")
                btnSpawn:SetPoint("LEFT", row, "LEFT", 2, 0)
                row.btnSpawn = btnSpawn

                local btnRem = WBC.MakeFlatButton(row, 24, 20, "x", { justify = "CENTER", danger = true })
                btnRem:SetPoint("LEFT", btnSpawn, "RIGHT", 6, 0)
                row.btnRem = btnRem

                poolFav[i] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", contentFav, "TOPLEFT", 2, y)

            local dispName = (name:len() > 30) and (name:sub(1, 28) .. "..") or name
            row.btnSpawn.label:SetText(c.accent .. dispName .. c.reset .. " " .. c.muted .. "(" .. tostring(entry) .. ")" .. c.reset)
            row.btnSpawn:SetScript("OnClick", function()
                if entry then GOMove:Move("SPAWN", entry) end
            end)

            row.btnRem:SetScript("OnClick", function()
                if GOMove.FavL and entry then
                    GOMove.FavL:Del(entry)
                    GOMove:Update()
                end
            end)

            row:Show()
            y = y - 24
        end
        contentFav:SetHeight(-y + 8)
    end

    local function refreshAll()
        refreshSelection()
        refreshFavorites()
    end

    table.insert(GOMove.Frames, { Update = refreshAll })
    parent:HookScript("OnShow", refreshAll)
    refreshAll()
end

WBC.RegisterTab({
    id = "builder",
    label = "Builder",
    wl = false,
    builder = gomoveBuilder,
})
