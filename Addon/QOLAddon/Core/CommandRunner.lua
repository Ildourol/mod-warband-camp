-- QOLAddon/Core/CommandRunner.lua
-- The single chokepoint for sending commands. Two kinds:
--   • dot-commands (.playerbots / .camp / .clear) → run as you
--   • bot orders ($word) → whisper one bot, or party/raid chat for all your bots

local addonName, QOL = ...

-- Deliver a dot-command. AzerothCore intercepts messages that begin with the
-- command prefix in the chat handler BEFORE they are broadcast, so
-- SendChatMessage("SAY") runs the command silently — no public SAY line appears,
-- only the server's response.
function QOL._ExecuteRaw(line)
    if QOL.IsBlank(line) then return end
    SendChatMessage(line, "SAY")
    QOL.PushHistory(line)
end

-- Public entry. opts.danger=true (and the global confirm toggle) pops the generic confirm.
-- The dialog runs _ExecuteRaw on accept.
function QOL.RunCommand(line, opts)
    if QOL.IsBlank(line) then return end
    opts = opts or {}
    local wantConfirm = opts.danger and (not QOL.db or QOL.db.confirmDanger ~= false)
    if wantConfirm then
        local dialog = StaticPopup_Show("QOL_CONFIRM_CMD", line)
        if dialog then dialog.data = line end
        return
    end
    QOL._ExecuteRaw(line)
end

-- Bot orders use the '$' command prefix and are delivered as chat:
-- PARTY/RAID to command ALL your bots at once, or WHISPER to order a single targeted bot.
--   scope "all"     → RAID if you are in a raid, else PARTY (every bot you own)
--   scope "whisper" → the targeted bot (or opts.bot)
-- Default scope comes from the shared selector (QOL.GetBotScope()).
function QOL.RunBotOrder(text, opts)
    if QOL.IsBlank(text) then return end
    opts = opts or {}
    text = QOL.Trim(text)
    if text:sub(1, 1) ~= "$" then text = "$" .. text end
    local scope = opts.scope or QOL.GetBotScope() or "all"
    if scope == "whisper" then
        local bot = opts.bot
        if QOL.IsBlank(bot) then bot = UnitName("target") end
        if QOL.IsBlank(bot) then QOL.Warn("no bot targeted - target a bot to whisper the order, or switch scope to All my bots."); return end
        SendChatMessage(text, "WHISPER", nil, bot)
    else
        local inRaid  = GetNumRaidMembers and GetNumRaidMembers() > 0
        local inParty = GetNumPartyMembers and GetNumPartyMembers() > 0
        if not inRaid and not inParty then
            QOL.Warn("you have no group - \"All my bots\" orders need your bots in your party/raid. Add bots (Party tab), or switch scope to Targeted bot (whisper).")
            return
        end
        SendChatMessage(text, inRaid and "RAID" or "PARTY")
    end
    QOL.PushHistory(text)   -- store clean so History can re-run it
end

-- Build a command string from a def + a table of arg values keyed by arg.key.
-- Returns (string) or (nil, errorMessage).
function QOL.BuildLine(def, values)
    if not def or not def.format then return nil, "no command" end
    local args = def.args or {}
    if #args == 0 then return def.format end

    local resolved = {}
    for i, arg in ipairs(args) do
        local v = QOL.ResolveArg(values and values[arg.key], arg)
        if QOL.IsBlank(v) then
            if arg.optional then
                v = arg.default or ""
            else
                return nil, "missing: " .. (arg.placeholder or arg.key)
            end
        end
        if arg.numeric and not QOL.IsBlank(v) then
            local n = tonumber(v)
            if not n then return nil, (arg.placeholder or arg.key) .. " must be a number" end
            v = tostring(n)
        end
        resolved[i] = v
    end

    -- Drop trailing blank optionals so the line stays tidy.
    while #resolved > 0 and resolved[#resolved] == "" do resolved[#resolved] = nil end

    local placeholders = 0
    for _ in def.format:gmatch("%%s") do placeholders = placeholders + 1 end

    if #resolved == placeholders then
        return string.format(def.format, unpack(resolved))
    else
        local padded = {}
        for i = 1, placeholders do padded[i] = resolved[i] or "" end
        local line = string.format(def.format, unpack(padded))
        return (line:gsub("%s+$", ""))
    end
end

-- Preview the command with <placeholders> shown for unfilled args.
function QOL.PreviewLine(def, values)
    local line = def.format or ""
    for _, arg in ipairs(def.args or {}) do
        local v = values and values[arg.key]
        local sub = (v and v ~= "" and v) or ("<" .. (arg.placeholder or arg.key) .. ">")
        line = line:gsub("%%s", sub:gsub("%%", "%%%%"), 1)
    end
    if def.send == "bot" and line:sub(1, 1) ~= "$" then line = "$" .. line end
    return line
end
