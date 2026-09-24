-- WarbandCamp/Core/Warband.lua
-- Warband Camp state: parse the server's CHAT_MSG_SYSTEM replies to `.camp`
-- commands into a small session-cached state table the tab renders from.

local addonName, WBC = ...

local W = {
    probed  = false,   -- have we heard ANY .camp status yet this session
    enabled = nil,     -- false only after the literal not-enabled line
    hasCamp = nil,
    zone    = nil,
    privacy = nil,
    count   = nil,     -- props placed
    cap     = nil,     -- prop cap; nil = unlimited (MaxProps=0) or unknown
}
WBC.Warband = W

-- UI refresh hooks (the tab registers one).
local callbacks = {}
function W.OnChange(fn) table.insert(callbacks, fn) end
local function notify()
    for _, fn in ipairs(callbacks) do pcall(fn) end
end

local function strip(msg)
    return (msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Silent probe (no history entry). Delay lets claim/leave settle server-side.
function W.Probe(delay)
    WBC.After(delay or 0, function() SendChatMessage(".camp", "SAY") end)
end

-- Parse one system line. Returns true if it was a Warband line.
function W.ParseSystem(msg)
    if type(msg) ~= "string" then return false end
    msg = strip(msg)

    if msg:find("Warband Camps are not enabled", 1, true) then
        W.probed, W.enabled = true, false
        notify(); return true
    end
    if msg:find("You have no Warband Camp yet", 1, true) or msg:find("You have no camp%.", 1) then
        W.probed, W.enabled, W.hasCamp = true, true, false
        W.zone, W.count, W.cap, W.privacy = nil, nil, nil, nil
        notify(); return true
    end

    -- Camp status with privacy & cap
    local zoneP, privP, nP, mP = msg:match("Your Warband Camp is in (.-) %(Privacy: (.-)%), with (%d+) of (%d+) things set up")
    if zoneP then
        W.probed, W.enabled, W.hasCamp = true, true, true
        W.zone, W.privacy, W.count, W.cap = zoneP, privP, tonumber(nP), tonumber(mP)
        notify(); return true
    end

    -- Camp status with privacy unlimited
    local zonePU, privPU, nPU = msg:match("Your Warband Camp is in (.-) %(Privacy: (.-)%), with (%d+) things set up")
    if zonePU then
        W.probed, W.enabled, W.hasCamp = true, true, true
        W.zone, W.privacy, W.count, W.cap = zonePU, privPU, tonumber(nPU), nil
        notify(); return true
    end

    local zone, n, m = msg:match("Your Warband Camp is in (.-), with (%d+) of (%d+) things set up")
    if zone then
        W.probed, W.enabled, W.hasCamp = true, true, true
        W.zone, W.count, W.cap = zone, tonumber(n), tonumber(m)
        notify(); return true
    end
    local zone2, n2 = msg:match("Your Warband Camp is in (.-), with (%d+) things set up")
    if zone2 then
        W.probed, W.enabled, W.hasCamp = true, true, true
        W.zone, W.count, W.cap = zone2, tonumber(n2), nil
        notify(); return true
    end

    -- Place success: "<Label> set up (N of M)." / "<Label> set up (N so far)."
    local pn, pm = msg:match("set up %((%d+) of (%d+)%)")
    if pn then
        W.enabled, W.hasCamp = true, true
        W.count, W.cap = tonumber(pn), tonumber(pm)
        notify(); return true
    end
    local ps = msg:match("set up %((%d+) so far%)")
    if ps then
        W.enabled, W.hasCamp = true, true
        W.count = tonumber(ps)          -- cap unchanged (unlimited realms)
        notify(); return true
    end

    -- Cap reached: "Your camp is full (N things)."
    local full = msg:match("Your camp is full %((%d+) things%)")
    if full then
        W.enabled, W.hasCamp = true, true
        W.count = tonumber(full)
        if W.cap == nil then W.cap = tonumber(full) end
        notify(); return true
    end

    -- Packed away (undo / remove success)
    if msg:find("packed away", 1, true) then
        if W.count and W.count > 0 then W.count = W.count - 1 end
        notify(); return true
    end

    -- Privacy update
    local newPriv = msg:match("Camp privacy updated to: (.-)%(")
    if not newPriv then newPriv = msg:match("Camp privacy updated to: (.-)$") end
    if newPriv then
        W.privacy = WBC.Trim(newPriv)
        notify(); return true
    end

    -- Claim success: "This ground is yours. Your Warband Camp is founded ..."
    if msg:find("This ground is yours", 1, true) then
        W.enabled, W.hasCamp = true, true
        W.Probe(2)                      -- fetch zone + counts
        notify(); return true
    end

    -- Break / struck camp
    if msg:find("Your camp has been struck", 1, true) or msg:find("released its camp", 1, true) then
        W.hasCamp = false
        W.zone, W.count, W.cap, W.privacy = nil, nil, nil, nil
        notify(); return true
    end

    return false
end

-- ─── Wiring ────────────────────────────────────────────────────────────────
local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_SYSTEM")
listener:SetScript("OnEvent", function(_, _, msg) W.ParseSystem(msg) end)

-- One probe per session, shortly after login so the world is settled.
WBC.AddLogin(function() W.Probe(5) end)
