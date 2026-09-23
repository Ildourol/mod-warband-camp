-- QOLAddon/UI/Tabs/Warband.lua
-- * Warband Camp (repack v1.5.0, task #74): manage the whole camp by buttons —
-- claim/travel/visit/break, gather alts, and place props from categorized
-- dropdowns. Authored from handoffs/2026-08-09_addon_warband_tab.md.
-- State + reply parsing live in Core/Warband.lua; the prop catalogue in
-- Data/WarbandProps.lua. Module ships OFF server-side: on the literal
-- not-enabled reply this panel greys out for the session.
-- Boundaries: NO Warband Bank, NO banner picker (v1.6 — layout room left).

local addonName, QOL = ...

local function row(id, label, fmt, tooltip, args)
    return { id = id, label = label, format = fmt, wl = false, group = "Warband",
             tooltip = tooltip, args = args }
end

local CampRows = {
    row("wb_claim", "Claim camp", ".camp claim",
        "Found your Warband Camp on the ground you're standing on. The server refuses with a one-line reason if the spot won't work (indoors, water, city, bridge, too close to another camp, ...)."),
    row("wb_go", "Travel to camp", ".camp go",
        "Teleport to your camp. 5-minute cooldown (shared with Visit); blocked in combat, while dead, and in BGs/arenas/Pilgrim's Way."),
    row("wb_alts", "Gather alts", ".camp alts",
        "Manually re-gather your alts at the camp (max 8). They normally gather on their own at login."),
    row("wb_privacy", "Camp privacy", ".camp privacy %s",
        "Set who can discover and visit your camp: public, party, guild, or private.",
        { { key = "mode", choices = { "public", "party", "guild", "private" }, placeholder = "privacy", width = 110 } }),
    row("wb_dummy", "Training dummy", ".camp dummy %s",
        "Spawn or remove a combat training dummy at your camp (80, boss, normal, or remove).",
        { { key = "type", choices = { "80", "boss", "normal", "remove" }, placeholder = "type", width = 110 } }),
    row("wb_message", "Welcome message", ".camp message %s",
        "Set greeting displayed to visitors crossing into camp, or type 'clear' to remove.",
        { { key = "msg", placeholder = "greeting or clear", width = 140 } }),
    row("wb_visit", "Visit player", ".camp visit %s",
        "Travel to another player's camp. Shares the 5-minute cooldown with Travel. Blank = your current target.",
        { {key="name",placeholder="player",fallback="target",width=120} }),
    row("wb_list", "Nearby camps", ".camp list",
        "List camps near you - who, zone, distance - in your chat."),
}

local function warbandBuilder(parent)
    local W = QOL.Warband
    local c = QOL.colors

    -- ─── Status bar ────────────────────────────────────────────────────────
    local statusFS = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusFS:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    statusFS:SetJustifyH("LEFT")

    local refresh = QOL.MakeFlatButton(parent, 90, 22, "Refresh", { justify = "CENTER" })
    refresh:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -6)
    refresh:SetScript("OnClick", function() QOL.RunCommand(".camp") end)

    -- ─── Body (everything below the status bar; hidden when disabled) ──────
    local body = CreateFrame("Frame", nil, parent)
    body:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -34)
    body:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    -- Left: camp actions
    local used = QOL.LayoutRows(body, CampRows, { yTop = 8, x = 8, columnWidth = 360,
        sectionTitle = "Your camp" })

    local breakBtn = QOL.MakeFlatButton(body, 168, 24, "Break camp...", { justify = "CENTER", danger = true })
    breakBtn:SetPoint("TOPLEFT", body, "TOPLEFT", 18, -(used + 4))
    breakBtn:SetScript("OnClick", function()
        -- The server itself is two-step: `.camp leave` prints its warning line,
        -- our popup then sends `.camp leave confirm`.
        QOL.RunCommand(".camp leave")
        StaticPopup_Show("QOL_CONFIRM_CAMP_LEAVE")
    end)
    breakBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Break camp", 1, 0.45, 0.45)
        GameTooltip:AddLine("Destroys your camp and ALL its props. Cannot be undone. Asks for confirmation.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    breakBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Right: prop placement
    local hdr = QOL.CreateSectionHeader(body, "Place props")
    hdr:SetPoint("TOPLEFT", body, "TOPLEFT", 380, -8)

    local catDD = QOL.CreateChoice(body, 150, 24, QOL.WarbandProps.CategoryNames(), "category")
    catDD:SetPoint("TOPLEFT", body, "TOPLEFT", 384, -(8 + hdr:GetHeight() + 8))

    local propDD = QOL.CreateChoice(body, 150, 24, {}, "prop")
    propDD:SetPoint("LEFT", catDD, "RIGHT", 6, 0)

    local angleBox = QOL.MakeFlatEditBox(body, 50, 24, "0°", true)
    angleBox:SetPoint("LEFT", propDD, "RIGHT", 6, 0)
    angleBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Rotation Angle", 1, 0.82, 0.30)
        GameTooltip:AddLine("Optional rotation in degrees (-360 to 360). Leave blank or 0 for default facing.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    angleBox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Category pick fills the prop list (dot-call style, matching CreateChoice).
    local origCatSet = catDD.SetValue
    catDD.SetValue = function(v)
        origCatSet(v)
        propDD.SetChoices(v and QOL.WarbandProps.PropChoices(v) or {})
        propDD.SetValue(nil)
    end

    local placeBtn = QOL.MakeFlatButton(body, 85, 24, "Place", { justify = "CENTER" })
    placeBtn:SetPoint("TOPLEFT", catDD, "BOTTOMLEFT", 0, -10)
    placeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Place prop", 1, 0.82, 0.30)
        GameTooltip:AddLine(".camp place <key> [angle]", 0.27, 0.84, 1)
        GameTooltip:AddLine("Spawns the selected prop facing you, with optional rotation angle.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    placeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local removeBtn = QOL.MakeFlatButton(body, 125, 24, "Remove nearest", { justify = "CENTER" })
    removeBtn:SetPoint("LEFT", placeBtn, "RIGHT", 6, 0)
    removeBtn:SetScript("OnClick", function() QOL.RunCommand(".camp remove") end)
    removeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove nearest", 1, 0.82, 0.30)
        GameTooltip:AddLine(".camp remove", 0.27, 0.84, 1)
        GameTooltip:AddLine("Packs away the nearest camp prop in front of you.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local undoBtn = QOL.MakeFlatButton(body, 85, 24, "Undo last", { justify = "CENTER" })
    undoBtn:SetPoint("LEFT", removeBtn, "RIGHT", 6, 0)
    undoBtn:SetScript("OnClick", function() QOL.RunCommand(".camp undo") end)
    undoBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Undo last prop", 1, 0.82, 0.30)
        GameTooltip:AddLine(".camp undo", 0.27, 0.84, 1)
        GameTooltip:AddLine("Packs away the most recently placed item in your camp.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    undoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 3-second per-prop server cooldown -> debounce the button client-side.
    local lastPlace = 0
    placeBtn:SetScript("OnClick", function()
        local key = propDD.GetValue()
        if not key then QOL.Warn("pick a category and a prop first.") return end
        if GetTime() - lastPlace < 3 then return end   -- "Steady on - one thing at a time."
        lastPlace = GetTime()
        local angle = QOL.Trim(angleBox:GetText() or "")
        local cmd = ".camp place " .. key
        if angle ~= "" and tonumber(angle) then
            cmd = cmd .. " " .. tonumber(angle)
        end
        QOL.RunCommand(cmd)
        placeBtn.label:SetText("Placing...")
        QOL.After(3, function() placeBtn.label:SetText("Place") end)
    end)

    local placeHint = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeHint:SetPoint("TOPLEFT", placeBtn, "BOTTOMLEFT", -4, -8)
    placeHint:SetPoint("RIGHT", body, "RIGHT", -8, 0)
    placeHint:SetJustifyH("LEFT")
    placeHint:SetText("Props appear IN FRONT of you - face where you want it before clicking Place. "
        .. "Optional rotation angle in degrees (-360 to 360) can be entered in the angle box. "
        .. "Bigger props land further out; stand on a table to place at table height. "
        .. "You must be within 32 yd of the camp centre, on the ground.")

    local gomoveBtn = QOL.MakeFlatButton(body, 200, 24, "Open 3D Camp Builder", { justify = "CENTER" })
    gomoveBtn:SetPoint("TOPLEFT", placeHint, "BOTTOMLEFT", 0, -10)
    gomoveBtn:SetScript("OnClick", function()
        if QOL.SelectTabById then
            QOL.SelectTabById("gomove")
        end
    end)
    gomoveBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("3D Camp Builder & Editor", 1, 0.82, 0.30)
        GameTooltip:AddLine("Switches to the integrated GOMove 3D editor and object browser to place, nudge, rotate, and scale camp objects in real-time.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    gomoveBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ─── Facts footer ──────────────────────────────────────────────────────
    local facts = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    facts:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 8, 8)
    facts:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -8, 8)
    facts:SetJustifyH("LEFT")
    facts:SetText(c.muted
        .. "The camp belongs to your ACCOUNT - every character shares it. Others see it only within 40 yd; "
        .. "friends can walk right in, no invite needed. Your alts gather there at login (max 8) and stroll "
        .. "around - whisper an alt 'follow' (a bot whisper, not a dot-command) to take it adventuring.\n"
        .. "Cooldowns: Travel / Visit share 5 min; placing has a 3 s per-prop breather." .. c.reset)

    -- ─── Disabled view (module ships OFF) ──────────────────────────────────
    local disabledFS = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    disabledFS:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -60)
    disabledFS:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -60)
    disabledFS:SetJustifyH("LEFT")
    disabledFS:SetText(c.danger .. "Warband Camps are not enabled on this realm." .. c.reset
        .. "\n\n" .. c.muted .. "The server owner can turn them on in mod_warband_camp.conf. "
        .. "This panel wakes up on its own once they are." .. c.reset)
    disabledFS:Hide()

    -- ─── State -> UI ───────────────────────────────────────────────────────
    local function render()
        if W.probed and W.enabled == false then
            body:Hide(); disabledFS:Show()
            statusFS:SetText(c.danger .. "Warband Camps: disabled" .. c.reset)
            return
        end
        disabledFS:Hide(); body:Show()
        if not W.probed then
            statusFS:SetText(c.muted .. "Camp: checking... (or hit Refresh)" .. c.reset)
        elseif W.hasCamp == false then
            statusFS:SetText(c.label .. "Camp: " .. c.reset
                .. "none yet - stand somewhere nice in the open world and Claim.")
        else
            local things = W.count and (W.count .. (W.cap and (" of " .. W.cap) or "") .. " things set up")
                or "contents unknown"
            statusFS:SetText(c.label .. "Camp: " .. c.reset .. c.accent .. (W.zone or "?") .. c.reset
                .. c.muted .. "  -  " .. things .. c.reset)
        end
    end
    W.OnChange(render)
    parent:HookScript("OnShow", render)
    render()
end

QOL.RegisterTab({
    id = "warband", label = "Warband", wl = false,
    builder = warbandBuilder,
})
