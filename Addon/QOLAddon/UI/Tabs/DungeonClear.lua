-- QOLAddon/UI/Tabs/DungeonClear.lua
-- Dungeon Clear (new in repack v1.4.0): a TANK BOT runs the dungeon for the
-- group while you play along as a follower. Commands act on the group's
-- elected leader tank bot; any real player in its group may issue them.
-- Authored from handoffs/2026-07-14_v1.4.0_player_addon_commands.md.
--
-- The $ run controls only work INSIDE a dungeon and are forced to party/raid
-- chat (botScope="all") — that always reaches the elected tank, regardless of
-- the Bots tab's scope selector. The info/extras rows are dot-commands and
-- work anywhere. Chat announcements arrive via Core/DungeonClear.lua.

local addonName, QOL = ...

-- $ run controls (party chat; in-dungeon only).
local function dc(id, label, word, tooltip, args)
    return { id = id, label = label, format = word, send = "bot", botScope = "all",
             group = "DungeonClear", tooltip = tooltip, args = args }
end
-- Dot-commands (run as you; work anywhere in-game).
local function dcd(id, label, fmt, tooltip, args)
    return { id = id, label = label, format = fmt, group = "DungeonClear",
             tooltip = tooltip, args = args }
end

local RunControl = {
    dc("dc_on",    "Start run",      "dc on",
        "Start the run: the tank heads for the first boss and the group follows.\nRefusals are whispered honestly: Not in a dungeon / No bosses found for this map / <Name> is dead - rez and try again."),
    dc("dc_off",   "Stop run",       "dc off",
        "Stop and tear down the run. The tank halts instantly; followers return to you."),
    dc("dc_pause", "Pause / resume", "dc pause",
        "Toggle: pause holds everyone in place (progress kept; a fight in progress finishes first). The same command resumes - refused while anyone is dead. Door-gated auto-pauses resume themselves when a player opens the door."),
    dc("dc_skip",  "Skip objective", "dc skip",
        "Skip the current objective - a due gating event first, otherwise the boss: Skipped <boss>. Heading to <next>."),
    dc("dc_pull",  "Pull mode",      "dc pull %s",
        "How the tank pulls: on = Advanced camp-pull, off = Leeroy, dynamic = per-pack auto (recommended).\nLeave empty to cycle modes. Can be set before starting the run.",
        { {key="mode",placeholder="mode (opt)",choices={"on","off","dynamic"},optional=true,width=100} }),
}

local InfoRows = {
    dcd("dcd_status", "Status",            ".dc status",
        "Dungeon clear: on/off, next boss, skipped count - plus the stall reason if the run is stuck. Works while off, and from anywhere ($dc status works in-dungeon too)."),
    dcd("dcd_bosses", "Boss roster",       ".dc bosses",
        "The full boss/objective/event roster with live alive/dead/skipped state. Works while off."),
    dcd("dcd_go",     "Send tank to boss", ".dc go %s",
        "Send the tank to a specific boss by name substring or entry, e.g. .dc go herod. Dot-command only - there is no $dc go.",
        { {key="boss",placeholder="boss name / entry",width=130} }),
    dcd("dcd_config", "Show settings",     ".dc config",
        "Print every DungeonClear setting as the server reads it right now."),
    dcd("dcd_spectate","Spectate",         ".dc spectate",
        "Free-fly spectator camera while your character keeps playing under bot AI. In-dungeon only; run it again to toggle off. (The server can disable this.)"),
}

local function dcBuilder(parent)
    local info = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    info:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    info:SetJustifyH("LEFT")
    info:SetText(QOL.colors.muted ..
        "New in v1.4.0: a TANK BOT runs the dungeon while you play along as a follower. Commands drive your group's "
        .. "elected tank bot (any real player in its group can issue them); you can't manually steer the tank while a "
        .. "run is on. Run controls work inside the dungeon; the dot-commands on the right work anywhere."
        .. QOL.colors.reset)

    local yTop = 8 + info:GetStringHeight() + 14
    local usedL = QOL.LayoutRows(parent, RunControl, { yTop = yTop, x = 8,   columnWidth = 360,
        sectionTitle = "Run control ($ - sent to party chat)" })
    local usedR = QOL.LayoutRows(parent, InfoRows,   { yTop = yTop, x = 380, columnWidth = 368,
        sectionTitle = "Info & extras (. - work anywhere)" })

    local notes = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notes:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -(math.max(usedL, usedR) + 12))
    notes:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -(math.max(usedL, usedR) + 12))
    notes:SetJustifyH("LEFT")
    notes:SetText(
        QOL.colors.good .. "This addon prints the tank's run announcements in your chat as [DungeonClear] lines"
        .. QOL.colors.reset .. QOL.colors.muted .. " - they ride a hidden addon channel a stock client never shows. "
        .. "Error refusals arrive as normal whispers either way.\nIf the server has Dungeon Clear disabled "
        .. "(DungeonClear.Enable = 0 in mod_dungeon_clear.conf), .dc refuses with an honest message and the chat "
        .. "commands do nothing." .. QOL.colors.reset)
end

QOL.RegisterTab({
    id = "dungeonclear", label = "Dungeon Clear",
    builder = dcBuilder,
})
