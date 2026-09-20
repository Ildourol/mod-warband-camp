-- QOLAddon/UI/Tabs/History.lua
-- The last commands you sent. Click any to re-run it.

local addonName, QOL = ...

QOL.RegisterTab({
    id = "history", label = "History",
    builder = function(parent)
        local top = CreateFrame("Frame", nil, parent)
        top:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
        top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)
        top:SetHeight(24)
        local hint = top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("LEFT", top, "LEFT", 4, 0)
        hint:SetText(QOL.colors.muted .. "Click a line to re-run it." .. QOL.colors.reset)
        local clear = QOL.MakeFlatButton(top, 110, 20, "Clear history", { justify = "CENTER" })
        clear:SetPoint("RIGHT", top, "RIGHT", 0, 0)
        clear:SetScript("OnClick", function() QOL.ClearHistory() end)

        local area = CreateFrame("Frame", nil, parent)
        area:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -4)
        area:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        local scroll, content = QOL.CreateScrollContent(area)

        local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOP", content, "TOP", 0, -40)
        empty:SetText("No commands sent yet this session.")

        local function reRun(line)
            line = QOL.Trim(line)
            if line == "" then return end
            if line:sub(1, 1) == "$" then
                QOL.RunBotOrder((line:gsub("^%$", "")), {})   -- {} → use the current scope
            else
                QOL.RunCommand(line)
            end
        end

        local pool = {}
        local function refresh()
            for _, b in ipairs(pool) do b:Hide() end
            local hist = QOL.GetHistory()
            if #hist == 0 then empty:Show(); content:SetHeight(200); return end
            empty:Hide()
            local y = -4
            for i, line in ipairs(hist) do
                local b = pool[i]
                if not b then
                    b = QOL.MakeFlatButton(content, 760, 22, "", { padLeft = 8 })
                    pool[i] = b
                end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
                b:SetWidth(760)
                b.label:SetText((line:sub(1, 1) == "$" and QOL.colors.bot or QOL.colors.accent) .. line .. QOL.colors.reset)
                b._line = line
                b:SetScript("OnClick", function(self) reRun(self._line) end)
                b:Show()
                y = y - 24
            end
            content:SetHeight(math.max(-y + 8, 200))
        end
        QOL.RefreshHistoryTab = refresh
        refresh()
    end,
    onShow = function() if QOL.RefreshHistoryTab then QOL.RefreshHistoryTab() end end,
})
