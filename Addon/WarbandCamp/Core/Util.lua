-- WarbandCamp/Core/Util.lua
-- Theme colours, print helpers, small string/target utilities.

local addonName, WBC = ...

-- ─── Brand palette ─────────────────────────────────────────────────────────
WBC.colors = {
    brand   = "|cffffc94d",   -- Warband gold
    accent  = "|cff45d7ff",   -- Frost cyan — your own (.) commands
    good    = "|cff33ff99",
    warn    = "|cffff9933",
    danger  = "|cffff4444",
    label   = "|cffffd100",
    muted   = "|cff8899aa",
    white   = "|cffffffff",
    reset   = "|r",
}

-- RGB equivalents for SetTextColor / SetVertexColor / pip texture calls.
WBC.rgb = {
    brand  = { 1.00, 0.79, 0.30 },
    accent = { 0.27, 0.84, 1.00 },
    good   = { 0.20, 1.00, 0.60 },
    danger = { 1.00, 0.27, 0.27 },
    muted  = { 0.53, 0.60, 0.67 },
}

-- Row category metadata — a pip colour + legend name per command kind.
WBC.cats = {
    player = { name = "Command (.)", rgb = WBC.rgb.accent, color = WBC.colors.accent },
}

function WBC.CatOf(def)
    return "player"
end

-- ─── Print ─────────────────────────────────────────────────────────────────
function WBC.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(WBC.colors.brand .. "WarbandCamp" .. WBC.colors.reset .. ": " .. tostring(msg))
end

function WBC.Warn(msg)
    DEFAULT_CHAT_FRAME:AddMessage(WBC.colors.brand .. "WarbandCamp" .. WBC.colors.reset
        .. ": " .. WBC.colors.warn .. tostring(msg) .. WBC.colors.reset)
end

-- ─── String / value helpers ────────────────────────────────────────────────
function WBC.IsBlank(s)
    return s == nil or s == "" or (type(s) == "string" and s:match("^%s*$") ~= nil)
end

function WBC.Trim(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function WBC.IsGM()
    return (IsGMClient and IsGMClient()) or (UnitIsGM and UnitIsGM("player")) or false
end

-- Resolve an arg value, applying its fallback when blank.
--   fallback="target" → UnitName("target")
--   fallback="self"   → UnitName("player")
function WBC.ResolveArg(value, arg)
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
