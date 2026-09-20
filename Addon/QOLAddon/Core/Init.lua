-- QOLAddon/Core/Init.lua
-- Addon namespace, defaults, event wiring, slash commands, C_Timer shim.
--
-- QOL Addon panel — WotLK 3.3.5a (AzerothCore).
-- Every file receives the addon name and the shared private table via `...`:
--     local addonName, QOL = ...
-- so there is exactly one shared table and no reliance on a global. We also
-- mirror it to _G.QOL and _G.QOLAddon so it can be accessed from /script.

local addonName, QOL = ...
_G.QOL = QOL
_G.QOLAddon = QOL

QOL.name    = "QOL Addon"
QOL.short   = "QOL"
QOL.version = GetAddOnMetadata(addonName, "Version") or "1.0.0"

-- Persisted defaults (deep-merged into the SavedVariable on load).
QOL.defaults = {
    frame   = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0, shown = false },
    button  = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -28, y = -120 },
    favorites = {},
    history   = {},
    inputs    = {},
    activeTab = 1,
    subTabs   = {},          -- per-tab remembered sub-tab index, keyed by tab id
    botScope  = "all",       -- where $ bot orders go: "all" (party/raid) or "whisper"
    minimap   = { hide = false },
    confirmDanger = true,     -- show confirm popup for danger commands
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
QOL.CopyDefaults = copyDefaults

-- ─── Login-handler registry ───────────────────────────────────────────────
-- Each module appends a function via QOL.AddLogin(); on PLAYER_LOGIN we run
-- each in sequence wrapped in pcall, so a failure in one (e.g. a tab builder)
-- never blocks the others (e.g. the toggle button).
QOL._loginHandlers = {}
function QOL.AddLogin(fn) table.insert(QOL._loginHandlers, fn) end

-- ─── C_Timer.After shim ────────────────────────────────────────────────────
-- 3.3.5a has no C_Timer. A single shared OnUpdate ticker drains a queue of
-- delayed callbacks — good enough for the short, low-volume delays we use.
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
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff5555QOL timer error:|r " .. tostring(err))
                end
            end
        end
        if #queue == 0 then self:Hide() end
    end)
    -- QOL.After(delay, fn) — run fn after `delay` seconds.
    function QOL.After(delay, fn)
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
        QOLAddon_DB = QOLAddon_DB or {}
        copyDefaults(QOL.defaults, QOLAddon_DB)
        QOL.db = QOLAddon_DB
    elseif event == "PLAYER_LOGIN" then
        for i, fn in ipairs(QOL._loginHandlers or {}) do
            local ok, err = pcall(fn)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555QOL login handler #" .. i .. " error:|r " .. tostring(err))
            end
        end
    end
end)

-- ─── Slash commands ────────────────────────────────────────────────────────
SLASH_QOL1 = "/qol"
SLASH_QOL2 = "/qoladdon"
SLASH_QOL3 = "/bots"
SlashCmdList["QOL"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lcmd = msg:lower()

    if lcmd == "reset" then
        QOL.db.frame, QOL.db.button = nil, nil
        copyDefaults(QOL.defaults, QOL.db)
        if QOL.RestoreMainFramePosition then QOL.RestoreMainFramePosition() end
        if QOL.RestoreButtonPosition then QOL.RestoreButtonPosition() end
        QOL.Print("positions reset.")
    elseif lcmd == "show" then
        if QOLAddon_MainFrame then QOLAddon_MainFrame:Show() end
    elseif lcmd == "hide" then
        if QOLAddon_MainFrame then QOLAddon_MainFrame:Hide() end
    elseif lcmd == "debug" then
        QOL.DumpDebug()
    else
        if QOL.Toggle then QOL.Toggle() end
    end
end

-- Module load-status dump for troubleshooting (/qol debug).
function QOL.DumpDebug()
    local c = QOL.colors
    local function pp(label, val) DEFAULT_CHAT_FRAME:AddMessage("  " .. label .. ": " .. tostring(val)) end
    DEFAULT_CHAT_FRAME:AddMessage(c.accent .. QOL.name .. " debug" .. c.reset .. "  v" .. QOL.version)
    pp("MainFrame", QOLAddon_MainFrame)
    pp("ToggleButton", QOLAddon_ToggleButton)
    pp("tabs registered", QOL.tabs and #QOL.tabs or 0)
    if QOL._mainFrameLoadError then pp("MainFrame load error", QOL._mainFrameLoadError) end
    DEFAULT_CHAT_FRAME:AddMessage("  modules:")
    for _, m in ipairs({
        { "Util",          QOL.colors },
        { "SavedVars",     QOL.PushHistory },
        { "CommandRunner", QOL.RunCommand },
        { "Specs",         QOL.Specs },
        { "ConfirmDialog", StaticPopupDialogs and StaticPopupDialogs["QOL_CONFIRM_CMD"] },
        { "Widgets",       QOL.CreateCommandRow },
        { "MainFrame",     QOL.RegisterTab },
        { "ToggleButton",  QOL.Toggle },
    }) do
        pp("    " .. m[1], m[2] and (c.good .. "ok" .. c.reset) or (c.danger .. "MISSING" .. c.reset))
    end
end
