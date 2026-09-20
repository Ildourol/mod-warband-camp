-- QOLAddon/UI/Tabs/Bots.lua
-- The PlayerBot command center (PLAYER_COMMANDS.md §1-§4). Two command kinds:
--   • dot-commands  .playerbots ...   (manage WHO your bots are)  → run as you
--   • bot orders    $word             (tell your bots WHAT to do)  → party/whisper
-- The scope bar at the very top decides where $ orders go: ALL my bots (party/
-- raid) or the TARGETED bot (whisper). Sub-tabs ("top tabs"): Party · Roles ·
-- Combat · Items · Dungeon.

local addonName, QOL = ...

-- def builders ---------------------------------------------------------------
local function order(id, label, word, tooltip, args, danger)   -- $ bot order
    return { id = id, label = label, format = word, send = "bot",
             group = "Bots", tooltip = tooltip, args = args, danger = danger }
end
local function pb(id, label, fmt, tooltip, args, danger)        -- .playerbots dot-command
    return { id = id, label = label, format = fmt, group = "Bots",
             tooltip = tooltip, args = args, danger = danger }
end

-- ─── PARTY: build & manage your bots (.playerbots) ─────────────────────────
local Build = {
    pb("pb_list",     "List my bots",      ".playerbots bot list",
        "Show your bots: online (+), your offline alts (-), and randoms in your group."),
    pb("pb_addclass", "Add class bot",     ".playerbots bot addclass %s %s",
        "Summon a fresh, pre-geared DISPOSABLE class bot of your faction - the fastest way to fill a party. Gender optional (male/female).\nClasses: warrior paladin hunter rogue priest dk shaman mage warlock druid. (DK needs you to meet the heroic level requirement.)",
        { {key="class",placeholder="class",choices=QOL.Specs.classes,width=90}, {key="gender",placeholder="gender",choices={"male","female"},optional=true,width=80} }),
    pb("pb_lookup",   "Classes available", ".playerbots bot lookup",
        "List the classes you can summon with Add class bot."),
    pb("pb_add",      "Add bot by name",   ".playerbots bot add %s",
        "Add your OWN character(s) as bots (you become master). Their progress persists. Comma-separate several. Blank = current target.",
        { {key="name",placeholder="Name[,Name2]",fallback="target",width=150} }),
    pb("pb_addacct",  "Add whole account", ".playerbots bot addaccount %s",
        "Add ALL characters on that account (or the named char's account) as bots at once.",
        { {key="acct",placeholder="account / char",width=150} }),
    pb("pb_login",    "Login a bot",       ".playerbots bot login %s",
        "Bring one of your offline bots online by name.",
        { {key="name",placeholder="Name",fallback="target",width=150} }),
    pb("pb_remove",   "Remove a bot",      ".playerbots bot remove %s",
        "Remove / log out one of your bots (aliases: logout, rm). Blank = current target.",
        { {key="name",placeholder="Name",fallback="target",width=150} }),
    pb("pb_remall",   "Remove ALL bots",   ".playerbots bot remove *",
        "Log out every bot you currently control.", nil, true),
}

local Manage = {
    pb("pb_init",   "Regear to my gear", ".playerbots bot init=auto %s",
        "Re-gear addclass bot(s), scaled to YOUR gear. Target a bot name, or * for all bots in your group.\n(init=auto is the player option; specific quality tiers may be GM-restricted depending on the server's AutoInitOnly setting.)",
        { {key="name",placeholder="name / *",fallback="target",width=120} }),
    pb("pb_levelup","Re-roll at level",  ".playerbots bot levelup",
        "Re-roll your bots at their current level."),
    pb("pb_refresh","Refresh gear",      ".playerbots bot refresh",
        "Re-roll your bots' consumables and gear."),
    pb("pb_random", "Full re-randomize", ".playerbots bot random",
        "Completely re-randomize your bots.", nil, true),
    pb("pb_quests", "Init instance quests", ".playerbots bot quests",
        "Initialize instance quests for your bots."),
    pb("pb_setkey", "Set account key",   ".playerbots account setKey %s",
        "Set a security key on your account so a trusted friend can link to it and command your characters.",
        { {key="key",placeholder="key",width=120} }),
    pb("pb_link",   "Link to account",   ".playerbots account link %s %s",
        "Link to a friend's account using their key, so you can add their characters as bots. Needs the server's AllowTrustedAccountBots enabled.",
        { {key="acct",placeholder="account",width=100}, {key="key",placeholder="key",width=70} }),
    pb("pb_linked", "Linked accounts",   ".playerbots account linkedAccounts",
        "List the accounts linked to yours."),
    pb("pb_unlink", "Unlink account",    ".playerbots account unlink %s",
        "Remove a link.", { {key="acct",placeholder="account",width=120} }),
}

local function partyBuilder(parent)
    QOL.LayoutRows(parent, Build,  { yTop = 8, x = 8,   columnWidth = 360, sectionTitle = "Build your party (.playerbots)" })
    QOL.LayoutRows(parent, Manage, { yTop = 8, x = 380, columnWidth = 368, sectionTitle = "Re-gear & account linking" })
end

-- ─── ROLES: a bot's role = its spec ($talents) ─────────────────────────────
local Roles = {
    order("r_report",  "Current spec",   "talents",           "Report the bot's current spec + help."),
    order("r_list",    "List specs",     "talents spec list", "List this class's premade specs (point spreads)."),
    order("r_set",     "Set spec",       "talents spec %s",
        "Switch to a spec by its PREMADE build name - e.g. arms pve, prot pve, holy pvp - exactly as listed (lowercase, spaces).\nThe tree name the bot REPORTS does not work here: 'protection' alone fails with 'Spec not found'. Use the dropdown above for the right names, or List specs for the bot's own list.",
        { {key="spec",placeholder="premade name",width=160} }),
    order("r_switch",  "Dual-spec",      "talents switch %s", "Activate primary (1) or secondary (2) dual-spec.",
        { {key="n",placeholder="1 or 2",choices={"1","2"},width=70} }),
    order("r_autopick","Auto-pick tree", "talents autopick",  "Auto-pick a full talent tree for the level."),
    order("r_apply",   "Apply talent link","talents apply %s","Apply a specific talent link (shift-click a talent calculator link into the box).",
        { {key="link",placeholder="talent link",width=160} }),
}

-- ─── Per-bot spec dropdown (v1.4.0) ────────────────────────────────────────
-- Target a bot -> the dropdown lists THAT class's premade builds (friendly
-- labels, Tank/Healer tagged). Picking one whispers `$talents spec <premade>`
-- to the bot, then `$autogear` right after - a spec change alone does NOT
-- re-gear, so a fresh tank would have no shield. Names from Data/Specs.lua
-- (verified against the live playerbots.conf).
local function buildSpecPicker(parent)
    local hdr = QOL.CreateSectionHeader(parent, "Set spec per bot (pick from the list)")
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)

    local targetFS = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetFS:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -(8 + hdr:GetHeight() + 8))

    local dd = QOL.CreateChoice(parent, 190, 24, {}, "target a bot first")
    dd:SetPoint("LEFT", targetFS, "RIGHT", 12, 0)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", targetFS, "BOTTOMLEFT", 0, -8)
    hint:SetText("Sends $talents spec <premade name>, then $autogear so the bot re-gears for the new spec.\n"
        .. "Death knights: any tree tanks via Frost Presence + gear - no single tank build, so none is tagged.")

    -- Refresh label + choices for the current target.
    local function refresh()
        local name = UnitName("target")
        local isPlayer = UnitIsPlayer and UnitIsPlayer("target")
        local _, token = UnitClass("target")
        local choices = (name and isPlayer) and QOL.Specs.PremadeChoices(token) or nil
        if choices then
            targetFS:SetText(QOL.colors.label .. "Bot: " .. QOL.colors.reset
                .. QOL.colors.accent .. name .. QOL.colors.reset
                .. QOL.colors.muted .. "  (" .. (UnitClass("target") or "?") .. ")" .. QOL.colors.reset)
            dd.SetChoices(choices)
        else
            targetFS:SetText(QOL.colors.muted .. "Bot: target one of your bots" .. QOL.colors.reset)
            dd.SetChoices({})
        end
        dd.SetValue(nil)
    end

    dd:HookScript("OnClick", function()
        -- Opening with no valid target: say why the list is empty.
        if not (UnitName("target") and UnitIsPlayer and UnitIsPlayer("target")) then
            QOL.Warn("target one of your bots first - the list shows that class's builds.")
        end
    end)

    -- The onSelect callback wasn't passed at creation (choices are dynamic),
    -- so wire the selection through SetValue.
    local origSetValue = dd.SetValue
    dd.SetValue = function(v)
        origSetValue(v)
        if not v then return end
        local bot = UnitName("target")
        if QOL.IsBlank(bot) then QOL.Warn("no bot targeted."); return end
        local _, token = UnitClass("target")
        QOL.RunBotOrder("talents spec " .. v, { scope = "whisper", bot = bot })
        QOL.RunBotOrder("autogear",           { scope = "whisper", bot = bot })
        QOL.Print("sent " .. QOL.colors.brand .. QOL.Specs.PremadeLabel(token, v) .. QOL.colors.reset
            .. " to " .. QOL.colors.accent .. bot .. QOL.colors.reset .. " (+ autogear).")
    end

    local watcher = CreateFrame("Frame", nil, parent)
    watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
    watcher:SetScript("OnEvent", refresh)
    parent:HookScript("OnShow", refresh)
    refresh()

    return 8 + hdr:GetHeight() + 8 + 24 + 8 + 28   -- height used by the picker block
end

local function rolesBuilder(parent)
    local pickerUsed = buildSpecPicker(parent)

    local used = QOL.LayoutRows(parent, Roles, { yTop = pickerUsed + 10,
        sectionTitle = "Spec commands ($talents)" })

    -- Premade-name -> role reference (names verified against playerbots.conf).
    -- LayoutRows' return already spans from the panel top (it includes yTop).
    local y = -(used + 8)
    local ref = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ref:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    ref:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    ref:SetJustifyH("LEFT")
    ref:SetText(
        QOL.colors.label .. "Pick a tank, a healer, and some DPS (premade names):" .. QOL.colors.reset .. "\n"
        .. QOL.colors.accent .. "Tank" .. QOL.colors.reset .. " = prot pve (warrior/paladin), bear pve (druid) - DKs tank in any tree via Frost Presence + gear\n"
        .. QOL.colors.good   .. "Heal" .. QOL.colors.reset .. " = holy pve / disc pve (paladin, priest), resto pve (druid/shaman)\n"
        .. QOL.colors.muted  .. "Everything else is DPS; each build also has a pvp variant (arms pvp, resto pvp, ...). The dropdown above sends these exact names for you."
        .. QOL.colors.reset)
end

-- ─── COMBAT: movement + combat orders ($) ──────────────────────────────────
local Movement = {
    order("o_follow",   "Follow",    "follow",   "Follow you."),
    order("o_stay",     "Stay",      "stay",     "Hold current position."),
    order("o_summon",   "Summon",    "summon",   "Pull the bot(s) to you (e.g. into a dungeon)."),
    order("o_flee",     "Flee",      "flee",     "Fall back / flee toward you."),
    order("o_runaway",  "Run away",  "runaway",  "Run away from the group / kite."),
    order("o_grind",    "Grind",     "grind",    "Resume roaming / grinding."),
    order("o_disperse", "Disperse",  "disperse", "Spread out."),
    order("o_home",     "Home",      "home",     "Set / return to home (selected innkeeper)."),
    order("o_taxi",     "Take taxi", "taxi",     "Take a flight path."),
    order("o_tele",     "Teleport",  "teleport", "Teleport (e.g. to you)."),
    order("o_go",       "Go to",     "go %s",    "Travel to a named place or coords.",
        { {key="where",placeholder="place / coords",width=150} }),
    order("o_hearth",   "Hearthstone","hearthstone",
        "The bot really casts its Hearthstone (interruptible cast). In party scope this is the whole squad's everyone-hearth button. Silent if the stone is missing or on cooldown - the spoken order 'go home' answers 'My hearthstone is still cooling down.' instead. Not usable in battlegrounds. (New in v1.4.0.)"),
    order("o_guidestop","Guide: stop","wl stop",
        "Cancel an active guide escort ('take me to ...'). Follow or Stay also cancel it. (New in v1.4.0.)"),
}
local Combat = {
    order("o_attack",   "Attack",        "attack",       "Attack your current target."),
    order("o_tankatk",  "Tank attack",   "tank attack",  "The tank engages your target."),
    order("o_pull",     "Pull",          "pull",         "Pull your target."),
    order("o_maxdps",   "Max DPS",       "max dps",      "Switch to maximum-DPS posture."),
    order("o_focus",    "Focus heal",    "focus heal %s","Tell healers which target(s) to prioritize. Blank = your target.",
        { {key="who",placeholder="player (opt)",optional=true,width=120} }),
    order("o_cast",     "Cast spell",    "cast %s",      "Cast a named spell (optionally on a target).",
        { {key="spell",placeholder="spell [target]",width=150} }),
    order("o_savemana", "Save mana",     "save mana",    "Healers conserve mana / use efficient spells."),
    order("o_drink",    "Drink",         "drink",        "Sit and restore mana / health."),
    order("o_rti",      "Set raid icon", "rti %s",       "Set / report the raid-target icon the bot focuses.",
        { {key="icon",placeholder="icon (opt)",choices={"skull","cross","circle","star","square","triangle","diamond","moon"},optional=true,width=100} }),
    order("o_release",  "Release",       "release",      "Corpse run after death."),
    order("o_revive",   "Revive",        "revive",       "Resurrect at the spirit healer."),
    order("o_reset",    "Reset AI",      "reset botAI",  "Reset the bot's AI state.", nil, true),
}

local function combatBuilder(parent)
    QOL.LayoutRows(parent, Movement, { yTop = 8, x = 8,   columnWidth = 360, sectionTitle = "Movement & position" })
    QOL.LayoutRows(parent, Combat,   { yTop = 8, x = 372, columnWidth = 376, sectionTitle = "Combat" })
end

-- ─── ITEMS: gear, loot & vendor orders ($) ─────────────────────────────────
local Gear = {
    order("i_autogear",  "Auto-gear",      "autogear",       "Equip the best available gear the bot has."),
    order("i_autogearb", "Auto-gear BiS",  "autogear bis",   "Equip best-in-slot."),
    order("i_upgrade",   "Equip upgrades", "equip upgrade",  "Equip any upgrades sitting in the bot's bags."),
    order("i_equip",     "Equip item",     "equip %s",       "Equip a linked item (shift-click it into the box).",
        { {key="item",placeholder="[item]",width=150} }),
    order("i_unequip",   "Unequip item",   "unequip %s",     "Take off a linked item.",
        { {key="item",placeholder="[item]",width=150} }),
    order("i_use",       "Use item",       "use %s",         "Use / consume a linked item.",
        { {key="item",placeholder="[item]",width=150} }),
    order("i_repair",    "Repair gear",    "repair",         "Repair the bot's gear at a vendor."),
    order("i_maint",     "Maintenance",    "maintenance",    "Learn spells/skills, top up consumables, enchant, repair, sell junk."),
    order("i_buff",      "Buff",           "buff %s",        "Cast buffs (optionally a class's set).",
        { {key="class",placeholder="class (opt)",choices=QOL.Specs.classes,optional=true,width=110} }),
    order("i_trainer",   "Trainer",        "trainer",        "Show what the bot can learn from the selected trainer."),
}
local Loot = {
    order("l_lootall",  "Loot all",     "loot all",  "Loot everything nearby (works in a party)."),
    order("l_roll",     "Loot roll",    "roll %s",   "Set loot-roll behaviour for linked item or all.",
        { {key="how",placeholder="pass/need/greed",choices={"pass","need","greed"},width=120} }),
    order("l_sell",     "Sell item",    "sell %s",   "Sell a linked item to the vendor (s * = all greys).",
        { {key="item",placeholder="[item] / *",width=130} }),
    order("l_buy",      "Buy item",     "buy %s",    "Buy a linked item from the vendor.",
        { {key="item",placeholder="[item]",width=130} }),
    order("l_open",     "Open items",   "open items","Open lootable containers in the bot's bags."),
    order("l_destroy",  "Destroy item", "destroy %s","Destroy a linked item.",
        { {key="item",placeholder="[item]",width=130} }, true),
}

local function itemsBuilder(parent)
    QOL.LayoutRows(parent, Gear, { yTop = 8, x = 8,   columnWidth = 360, sectionTitle = "Gear (whisper a bot)" })
    QOL.LayoutRows(parent, Loot, { yTop = 8, x = 372, columnWidth = 376, sectionTitle = "Loot & vendor" })
end

-- ─── DUNGEON: the guided run flow (§4) ─────────────────────────────────────
local function dungeonBuilder(parent)
    local info = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    info:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    info:SetJustifyH("LEFT")
    info:SetText(QOL.colors.muted ..
        "The Dungeon Finder won't drag your bots inside - you summon them. Flow: build a party (Party tab) -> "
        .. "set roles (Roles tab: a tank, a healer, dps) -> gear up -> walk in -> Summon party -> drive the fight. "
        .. "On this realm bots usually auto-summon a few seconds after the leader zones in; Summon is the manual backup."
        .. QOL.colors.reset .. "\n" .. QOL.colors.label
        .. "Prefer hands-off? New in v1.4.0: the Dungeon Clear tab lets a tank bot run the whole dungeon for you."
        .. QOL.colors.reset)

    local Steps = {
        pb("d_gear",   "1. Gear party to my gear", ".playerbots bot init=auto *",
            "Re-gear all bots in your group, scaled to your gear, before you go in."),
        pb("d_quests", "1b. Init instance quests", ".playerbots bot quests",
            "Initialize the dungeon's quests on your bots."),
        order("d_summon", "2. Summon party in", "summon",
            "Pull your whole party to you. Say this in party scope once you're at the entrance."),
    }
    local Drive = {
        order("d_tankatk", "Tank, pull/attack", "tank attack", "Send the tank in on your target."),
        order("d_attack",  "Everyone attack",   "attack",      "DPS attack your target."),
        order("d_pull",    "Pull",              "pull",        "Pull your target."),
        order("d_focus",   "Focus heal target", "focus heal %s","Healers prioritize this target. Blank = your target.",
            { {key="who",placeholder="player (opt)",optional=true,width=120} }),
        order("d_maxdps",  "Max DPS",           "max dps",     "Maximum-DPS posture for the burn."),
    }
    local Recover = {
        order("d_follow",  "Follow",  "follow",  "Regroup on you between packs."),
        order("d_stay",    "Stay",    "stay",    "Hold position (e.g. while you skip a pack)."),
        order("d_revive",  "Revive",  "revive",  "Resurrect at the spirit healer after a wipe."),
        order("d_release", "Release", "release", "Corpse run after death."),
    }

    local y = 8 + info:GetStringHeight() + 14
    local used = QOL.LayoutRows(parent, Steps, { yTop = y, x = 8, columnWidth = 360, sectionTitle = "Get in" })
    QOL.LayoutRows(parent, Drive,   { yTop = y, x = 372, columnWidth = 376, sectionTitle = "Drive the fight" })
    QOL.LayoutRows(parent, Recover, { yTop = y + used + 6, x = 8, columnWidth = 360, sectionTitle = "Regroup & recover" })
end

-- ─── SPEAK: plain-English orders, the Guide & the Sage (v1.4.0) ────────────
-- Documentation panel: these are things you TYPE or SAY to your bots, not
-- buttons. Exact phrases are deterministic (work with NO AI configured);
-- free-form sentences need an AI backend. Gated by AiCommand.Enabled.
local function speakBuilder(parent)
    local c = QOL.colors
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    fs:SetJustifyH("LEFT")
    fs:SetText(
        c.muted .. "New in v1.4.0: talk to your bots in plain English - no $ needed. The exact phrases below always work, "
        .. "even with no AI configured; free-form sentences need an AI backend (Ollama / API key / hosted). "
        .. "$ orders keep working regardless." .. c.reset .. "\n"
        .. c.warn .. "Server gate: AiCommand.Enabled = 1 in playerbot configuration - it ships OFF by default "
        .. "(the PTR has it ON)." .. c.reset .. "\n\n"
        .. c.label .. "Whisper a bot (no $):" .. c.reset .. "\n"
        .. "  follow / stay / attack / flee / drink / eat / come here / go home\n"
        .. "  attack the <mob name>  - finds the mob near YOU and targets it\n"
        .. c.muted .. "  One ack whisper ('On it - right behind you.') or an honest refusal\n"
        .. "  ('Pulling is a tank's job - I'm not built for it.')" .. c.reset .. "\n\n"
        .. c.label .. "Say it to the group (party/raid/say/yell):" .. c.reset .. "\n"
        .. "  everyone follow me / all of you attack the kobold miner / bots go home / you guys stay here\n"
        .. c.muted .. "  One bot answers for the squad. Big calls (everyone go home, everyone grind) ask you to\n"
        .. "  repeat within 45 s to confirm." .. c.reset .. "\n\n"
        .. c.label .. "The Guide - walked escorts:" .. c.reset .. "\n"
        .. "  take me to booty bay / guide me to the wailing caverns / take me to my quest\n"
        .. "  lead me to an innkeeper / my trainer / a repair vendor / the auction house / a flight master\n"
        .. c.muted .. "  The bot walks you there on roads (no teleport), yells if you fall behind, comes back for you.\n"
        .. "  Same continent only. Cancel with $wl stop (or $follow / $stay)." .. c.reset .. "\n\n"
        .. c.label .. "The Sage - ask real data questions in a whisper:" .. c.reset .. "\n"
        .. "  who sells Refreshing Spring Water? / where is Mankrik? / what does [linked quest] reward?\n"
        .. "  price of the Bronze Tube?\n"
        .. c.muted .. "  Answers are grounded in this server's actual vendors, prices and spawns.\n"
        .. "  Needs AI chat configured; the Sage itself is free and on by default." .. c.reset .. "\n\n"
        .. c.muted .. "Also new in v1.4.0, no commands needed: healers now save YOU first (Triage Healer), per-bot\n"
        .. "voice personalities (Voice Cards), no more chat spam (Speech Governor), and bots walk real roads\n"
        .. "world-wide (Road travel)." .. c.reset)
end

-- ─── Tab assembly: scope bar + sub-tabs ────────────────────────────────────
QOL.RegisterTab({
    id = "bots", label = "Bots",
    builder = function(parent)
        local bar = QOL.MakeScopeSelector(parent)
        bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
        bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)

        local body = CreateFrame("Frame", nil, parent)
        body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
        body:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

        QOL.BuildSubTabs(body, {
            { label = "Party",   builder = partyBuilder },
            { label = "Roles",   builder = rolesBuilder },
            { label = "Combat",  builder = combatBuilder },
            { label = "Items",   builder = itemsBuilder },
            { label = "Dungeon", builder = dungeonBuilder },
            { label = "Speak",   builder = speakBuilder },
        }, "bots")
    end,
})
