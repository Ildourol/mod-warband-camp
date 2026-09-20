-- QOLAddon/Data/Specs.lua
-- Class / race / spec reference for .playerbots bot commands.

local addonName, QOL = ...

local S = {}
QOL.Specs = S

-- Classes for .playerbots bot addclass.
S.classes = { "warrior", "paladin", "hunter", "rogue", "priest", "dk", "shaman", "mage", "warlock", "druid" }

S.classLabel = {
    warrior = "Warrior", paladin = "Paladin", hunter = "Hunter", rogue = "Rogue",
    priest = "Priest", dk = "Death Knight", shaman = "Shaman", mage = "Mage",
    warlock = "Warlock", druid = "Druid",
}


-- ─── Premade specs per class ───────────────────────────────────────────────
-- Keyed by the class token from select(2, UnitClass("unit")). Each entry:
--   label = friendly dropdown text · send = the exact `$talents spec` name ·
--   role  = "Tank" / "Healer" (marked in the dropdown; DPS left unmarked).
-- PvE builds first, then the PvP builds — same order as the handoff.
-- DK note: WotLK death knights tank in ANY tree (Frost Presence + gear), so
-- DK entries carry no role tag on purpose.
local T, H = "Tank", "Healer"
S.premade = {
    WARRIOR = {
        { label = "Arms",             send = "arms pve" },
        { label = "Fury",             send = "fury pve" },
        { label = "Protection",       send = "prot pve", role = T },
        { label = "Arms (PvP)",       send = "arms pvp" },
        { label = "Fury (PvP)",       send = "fury pvp" },
        { label = "Protection (PvP)", send = "prot pvp", role = T },
    },
    PALADIN = {
        { label = "Holy",              send = "holy pve", role = H },
        { label = "Protection",        send = "prot pve", role = T },
        { label = "Retribution",       send = "ret pve" },
        { label = "Holy (PvP)",        send = "holy pvp", role = H },
        { label = "Protection (PvP)",  send = "prot pvp", role = T },
        { label = "Retribution (PvP)", send = "ret pvp" },
    },
    HUNTER = {
        { label = "Beast Mastery",       send = "bm pve" },
        { label = "Marksmanship",        send = "mm pve" },
        { label = "Survival",            send = "surv pve" },
        { label = "Beast Mastery (PvP)", send = "bm pvp" },
        { label = "Marksmanship (PvP)",  send = "mm pvp" },
        { label = "Survival (PvP)",      send = "surv pvp" },
    },
    ROGUE = {
        { label = "Assassination",       send = "as pve" },
        { label = "Combat",              send = "combat pve" },
        { label = "Subtlety",            send = "subtlety pve" },
        { label = "Assassination (PvP)", send = "as pvp" },
        { label = "Combat (PvP)",        send = "combat pvp" },
        { label = "Subtlety (PvP)",      send = "subtlety pvp" },
    },
    PRIEST = {
        { label = "Discipline",       send = "disc pve",   role = H },
        { label = "Holy",             send = "holy pve",   role = H },
        { label = "Shadow",           send = "shadow pve" },
        { label = "Discipline (PvP)", send = "disc pvp",   role = H },
        { label = "Holy (PvP)",       send = "holy pvp",   role = H },
        { label = "Shadow (PvP)",     send = "shadow pvp" },
    },
    DEATHKNIGHT = {
        { label = "Blood",               send = "blood pve" },
        { label = "Frost",               send = "frost pve" },
        { label = "Unholy",              send = "unholy pve" },
        { label = "Blood (Double Aura)", send = "double aura blood pve" },
        { label = "Blood (PvP)",         send = "blood pvp" },
        { label = "Frost (PvP)",         send = "frost pvp" },
        { label = "Unholy (PvP)",        send = "unholy pvp" },
    },
    SHAMAN = {
        { label = "Elemental",         send = "ele pve" },
        { label = "Enhancement",       send = "enh pve" },
        { label = "Restoration",       send = "resto pve", role = H },
        { label = "Elemental (PvP)",   send = "ele pvp" },
        { label = "Enhancement (PvP)", send = "enh pvp" },
        { label = "Restoration (PvP)", send = "resto pvp", role = H },
    },
    MAGE = {
        { label = "Arcane",       send = "arcane pve" },
        { label = "Fire",         send = "fire pve" },
        { label = "Frost",        send = "frost pve" },
        { label = "Frostfire",    send = "frostfire pve" },
        { label = "Arcane (PvP)", send = "arcane pvp" },
        { label = "Fire (PvP)",   send = "fire pvp" },
        { label = "Frost (PvP)",  send = "frost pvp" },
    },
    WARLOCK = {
        { label = "Affliction",        send = "affli pve" },
        { label = "Demonology",        send = "demo pve" },
        { label = "Destruction",       send = "destro pve" },
        { label = "Affliction (PvP)",  send = "affli pvp" },
        { label = "Demonology (PvP)",  send = "demo pvp" },
        { label = "Destruction (PvP)", send = "destro pvp" },
    },
    DRUID = {
        { label = "Balance",           send = "balance pve" },
        { label = "Feral (Bear)",      send = "bear pve",  role = T },
        { label = "Feral (Cat)",       send = "cat pve" },
        { label = "Restoration",       send = "resto pve", role = H },
        { label = "Balance (PvP)",     send = "balance pvp" },
        { label = "Feral (Cat) (PvP)", send = "cat pvp" },
        { label = "Restoration (PvP)", send = "resto pvp", role = H },
    },
}

-- Dropdown-ready {text, value} choices for a class token ("WARRIOR", ...).
-- Tank/Healer builds are tagged in the text; returns nil for unknown tokens.
function S.PremadeChoices(classToken)
    local list = S.premade[classToken or ""]
    if not list then return nil end
    local out = {}
    for i, e in ipairs(list) do
        local text = e.label
        if e.role then text = text .. " - " .. e.role end
        out[i] = { text = text, value = e.send }
    end
    return out
end

-- Friendly label for an exact premade send-name (for confirmations).
function S.PremadeLabel(classToken, send)
    for _, e in ipairs(S.premade[classToken or ""] or {}) do
        if e.send == send then return e.label end
    end
    return send
end
