-- QOLAddon/Core/Util.lua
-- Theme colours, print helpers, small string/target utilities.

local addonName, QOL = ...

-- ─── Brand palette ─────────────────────────────────────────────────────────
QOL.colors = {
    brand   = "|cffffc94d",   -- QOL gold
    accent  = "|cff45d7ff",   -- Frost cyan (Wrath) — your own (.) commands
    bot     = "|cffe6cc80",   -- Bot tan — $ orders to your bots
    good    = "|cff33ff99",
    warn    = "|cffff9933",
    danger  = "|cffff4444",
    label   = "|cffffd100",
    muted   = "|cff8899aa",
    white   = "|cffffffff",
    reset   = "|r",
}

-- RGB equivalents for SetTextColor / SetVertexColor / pip texture calls.
QOL.rgb = {
    brand  = { 1.00, 0.79, 0.30 },
    accent = { 0.27, 0.84, 1.00 },
    bot    = { 0.90, 0.80, 0.50 },
    good   = { 0.20, 1.00, 0.60 },
    danger = { 1.00, 0.27, 0.27 },
    muted  = { 0.53, 0.60, 0.67 },
}

-- Row category metadata — a pip colour + legend name per command kind.
QOL.cats = {
    player = { name = "Your command (.)",   rgb = QOL.rgb.accent, color = QOL.colors.accent },
    bot    = { name = "Bot order ($)",       rgb = QOL.rgb.bot,    color = QOL.colors.bot },
}

-- Pick the category for a command def (used for the row pip + tooltip line).
function QOL.CatOf(def)
    if def.send == "bot" then return "bot" end
    return "player"
end

-- ─── Print ─────────────────────────────────────────────────────────────────
function QOL.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(QOL.colors.brand .. "QOL" .. QOL.colors.reset .. ": " .. tostring(msg))
end

function QOL.Warn(msg)
    DEFAULT_CHAT_FRAME:AddMessage(QOL.colors.brand .. "QOL" .. QOL.colors.reset
        .. ": " .. QOL.colors.warn .. tostring(msg) .. QOL.colors.reset)
end

-- ─── String / value helpers ────────────────────────────────────────────────
function QOL.IsBlank(s)
    return s == nil or s == "" or (type(s) == "string" and s:match("^%s*$") ~= nil)
end

function QOL.Trim(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Resolve an arg value, applying its fallback when blank.
--   fallback="target" → UnitName("target")
--   fallback="self"   → UnitName("player")
function QOL.ResolveArg(value, arg)
    if value == nil or value == "" then
        if arg and arg.fallback == "target" then
            local n = UnitName("target")
            if n and n ~= "" then return n end
        elseif arg and arg.fallback == "self" then
            return UnitName("player")
        end
        return nil
    end
    return value
end
