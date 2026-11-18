-- WarbandCamp/Core/CommandRunner.lua
-- The single chokepoint for sending dot-commands (.camp / .gomove).

local addonName, WBC = ...

-- Deliver a dot-command. AzerothCore intercepts messages that begin with the
-- command prefix in the chat handler BEFORE they are broadcast, so
-- SendChatMessage("SAY") runs the command silently — no public SAY line appears,
-- only the server's response.
function WBC._ExecuteRaw(line)
    if WBC.IsBlank(line) then return end
    SendChatMessage(line, "SAY")
    WBC.PushHistory(line)
end

-- Public entry. opts.danger=true (and the global confirm toggle) pops the confirm dialog.
-- The dialog runs _ExecuteRaw on accept.
function WBC.RunCommand(line, opts)
    if WBC.IsBlank(line) then return end
    opts = opts or {}
    if wantConfirm then
        WBC.ShowConfirm("Run this command?\n\n|cffffd100" .. line .. "|r", function()
            WBC._ExecuteRaw(line)
        end, "Run", "Cancel")
        return
    end
    WBC._ExecuteRaw(line)
end

-- Build a command string from a def + a table of arg values keyed by arg.key.
-- Returns (string) or (nil, errorMessage).
function WBC.BuildLine(def, values)
    if not def or not def.format then return nil, "no command" end
    local args = def.args or {}
    if #args == 0 then return def.format end

    local resolved = {}
    for i, arg in ipairs(args) do
        local v = WBC.ResolveArg(values and values[arg.key], arg)
        if WBC.IsBlank(v) then
            if arg.optional then
                v = arg.default or ""
            else
                return nil, "missing: " .. (arg.placeholder or arg.key)
            end
        end
        if arg.numeric and not WBC.IsBlank(v) then
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
function WBC.PreviewLine(def, values)
    local line = def.format or ""
    for _, arg in ipairs(def.args or {}) do
        local v = values and values[arg.key]
        local sub = (v and v ~= "" and v) or ("<" .. (arg.placeholder or arg.key) .. ">")
        line = line:gsub("%%s", sub:gsub("%%", "%%%%"), 1)
    end
    return line
end
