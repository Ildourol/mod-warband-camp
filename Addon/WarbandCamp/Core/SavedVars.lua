-- WarbandCamp/Core/SavedVars.lua
-- Frame-position persistence, history ring buffer, favorites, and input cache.

local addonName, WBC = ...

local HISTORY_MAX = 30

local function db() return WBC.db or WarbandCampDB end

-- ─── Frame positions ───────────────────────────────────────────────────────
function WBC.SaveFramePoint(frame, key)
    if not frame or not key then return end
    local point, _, relPoint, x, y = frame:GetPoint()
    if not point then return end
    local d = db()
    d[key] = d[key] or {}
    d[key].point, d[key].relPoint, d[key].x, d[key].y = point, relPoint, x, y
end

function WBC.RestoreFramePoint(frame, key, fallback)
    if not frame then return end
    local saved = db() and db()[key]
    frame:ClearAllPoints()
    if saved and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
    elseif fallback then
        frame:SetPoint(fallback.point or "CENTER", UIParent, fallback.relPoint or fallback.point or "CENTER",
            fallback.x or 0, fallback.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- ─── History (newest first, deduped against most-recent entry) ─────────────
function WBC.PushHistory(line)
    if WBC.IsBlank(line) then return end
    local d = db()
    d.history = d.history or {}
    if d.history[1] == line then return end
    table.insert(d.history, 1, line)
    while #d.history > HISTORY_MAX do table.remove(d.history) end
    if WBC.RefreshHistoryTab then WBC.RefreshHistoryTab() end
end

function WBC.GetHistory()
    local d = db()
    return (d and d.history) or {}
end

function WBC.ClearHistory()
    local d = db()
    if not d then return end
    d.history = {}
    if WBC.RefreshHistoryTab then WBC.RefreshHistoryTab() end
end

-- ─── Favorites (keyed by group:id so duplicates across tabs collapse) ───────
local function favKey(def) return (def.group or "?") .. ":" .. (def.id or def.label or "?") end

function WBC.IsFavorite(def)
    local d = db(); d.favorites = d.favorites or {}
    return d.favorites[favKey(def)] ~= nil
end

function WBC.ToggleFavorite(def)
    local d = db(); d.favorites = d.favorites or {}
    local k = favKey(def)
    if d.favorites[k] then
        d.favorites[k] = nil
        WBC.Print("unpinned " .. (def.label or k))
    else
        local copy = {}
        for ck, cv in pairs(def) do
            if type(cv) ~= "function" then copy[ck] = cv end
        end
        d.favorites[k] = copy
        WBC.Print("pinned " .. WBC.colors.brand .. (def.label or k) .. WBC.colors.reset .. " to Favorites")
    end
    if WBC.RefreshFavoritesTab then WBC.RefreshFavoritesTab() end
end

function WBC.GetFavorites()
    local d = db(); d.favorites = d.favorites or {}
    local list = {}
    for _, def in pairs(d.favorites) do table.insert(list, def) end
    table.sort(list, function(a, b) return (a.label or "") < (b.label or "") end)
    return list
end

-- ─── Per-input remembered values ───────────────────────────────────────────
function WBC.GetInputCache(rowKey, argKey)
    local d = db(); d.inputs = d.inputs or {}
    local row = d.inputs[rowKey]
    return row and row[argKey] or nil
end

function WBC.SetInputCache(rowKey, argKey, value)
    local d = db(); d.inputs = d.inputs or {}
    d.inputs[rowKey] = d.inputs[rowKey] or {}
    d.inputs[rowKey][argKey] = value
end
