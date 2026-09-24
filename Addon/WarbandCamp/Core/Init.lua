-- WarbandCamp/Core/Init.lua
-- Addon namespace, defaults, event wiring, slash commands, C_Timer shim.
--
-- Warband Camp panel & 3D Builder — WotLK 3.3.5a (AzerothCore mod-warband-camp).

local addonName, WBC = ...
_G.WarbandCamp = WBC
_G.WBC = WBC
-- Backward-compatibility bridge
_G.QOL = WBC

WBC.name    = "Warband Camp"
WBC.short   = "WBC"
WBC.version = GetAddOnMetadata(addonName, "Version") or "1.0.0"

-- Persisted defaults (deep-merged into the SavedVariable on load).
WBC.defaults = {
    frame         = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0, shown = false },
    button        = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -28, y = -120 },
    favorites     = {},
    history       = {},
    inputs        = {},
    activeTab     = 1,
    subTabs       = {},
    minimap       = { hide = false },
    confirmDanger = true,
}

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
WBC.CopyDefaults = copyDefaults

-- ─── Login-handler registry ───────────────────────────────────────────────
WBC._loginHandlers = {}
function WBC.AddLogin(fn) table.insert(WBC._loginHandlers, fn) end

-- ─── C_Timer.After shim ────────────────────────────────────────────────────
do
    local queue = {}
    local ticker = CreateFrame("Frame")
    ticker:Hide()
    ticker:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        for i = #queue, 1, -1 do
            if now >= queue[i].at then
                local fn = queue[i].fn
                table.remove(queue, i)
                local ok, err = pcall(fn)
                if not ok then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff5555WarbandCamp timer error:|r " .. tostring(err))
                end
            end
        end
        if #queue == 0 then self:Hide() end
    end)
    function WBC.After(delay, fn)
        table.insert(queue, { at = GetTime() + (delay or 0), fn = fn })
        ticker:Show()
    end
end

-- ─── Event wiring ──────────────────────────────────────────────────────────
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        WarbandCampDB = WarbandCampDB or {}
        copyDefaults(WBC.defaults, WarbandCampDB)
        WBC.db = WarbandCampDB
    elseif event == "PLAYER_LOGIN" then
        for i, fn in ipairs(WBC._loginHandlers or {}) do
            local ok, err = pcall(fn)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555WarbandCamp login handler #" .. i .. " error:|r " .. tostring(err))
            end
        end
    end
end)

-- ─── Slash commands ────────────────────────────────────────────────────────
SLASH_WARBANDCAMP1 = "/wb"
SLASH_WARBANDCAMP2 = "/warband"
SLASH_WARBANDCAMP3 = "/warbandcamp"
SLASH_WARBANDCAMP4 = "/campui"

SlashCmdList["WARBANDCAMP"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lcmd = msg:lower()

    if lcmd == "reset" then
        WBC.db.frame, WBC.db.button = nil, nil
        if WBC.db.minimap then WBC.db.minimap.hide = false end
        copyDefaults(WBC.defaults, WBC.db)
        if WBC.RestoreMainFramePosition then WBC.RestoreMainFramePosition() end
        if WBC.RestoreButtonPosition then WBC.RestoreButtonPosition() end
        WBC.Print("positions reset.")
    elseif lcmd == "minimap" or lcmd == "icon" or lcmd == "button" then
        if WarbandCamp_ToggleButton then
            if WarbandCamp_ToggleButton:IsShown() then
                WarbandCamp_ToggleButton:Hide()
                if WBC.db and WBC.db.minimap then WBC.db.minimap.hide = true end
                WBC.Print("Minimap button hidden. Type '/wb icon' to restore.")
            else
                WarbandCamp_ToggleButton:Show()
                if WBC.db and WBC.db.minimap then WBC.db.minimap.hide = false end
                WBC.Print("Minimap button shown.")
            end
        end
    elseif lcmd == "show" then
        if WarbandCamp_MainFrame then WarbandCamp_MainFrame:Show() end
    elseif lcmd == "hide" then
        if WarbandCamp_MainFrame then WarbandCamp_MainFrame:Hide() end
    elseif lcmd == "debug" then
        WBC.DumpDebug()
    else
        if WBC.Toggle then WBC.Toggle() end
    end
end

-- Module load-status dump for troubleshooting (/wb debug).
function WBC.DumpDebug()
    local c = WBC.colors
    local function pp(label, val) DEFAULT_CHAT_FRAME:AddMessage("  " .. label .. ": " .. tostring(val)) end
    DEFAULT_CHAT_FRAME:AddMessage(c.accent .. WBC.name .. " debug" .. c.reset .. "  v" .. WBC.version)
    pp("MainFrame", WarbandCamp_MainFrame)
    pp("ToggleButton", WarbandCamp_ToggleButton)
    pp("tabs registered", WBC.tabs and #WBC.tabs or 0)
    if WBC._mainFrameLoadError then pp("MainFrame load error", WBC._mainFrameLoadError) end
    DEFAULT_CHAT_FRAME:AddMessage("  modules:")
    for _, m in ipairs({
        { "Util",          WBC.colors },
        { "SavedVars",     WBC.PushHistory },
        { "CommandRunner", WBC.RunCommand },
        { "WarbandProps",  WBC.WarbandProps },
        { "ConfirmDialog", StaticPopupDialogs and StaticPopupDialogs["WARBAND_CONFIRM_CMD"] },
        { "Widgets",       WBC.CreateCommandRow },
        { "MainFrame",     WBC.RegisterTab },
        { "ToggleButton",  WBC.Toggle },
    }) do
        pp("    " .. m[1], m[2] and (c.good .. "ok" .. c.reset) or (c.danger .. "MISSING" .. c.reset))
    end
end
