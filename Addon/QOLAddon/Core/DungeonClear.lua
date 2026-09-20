-- QOLAddon/Core/DungeonClear.lua
-- Dungeon Clear chat bridge.

local addonName, QOL = ...

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", function(_, _, prefix, message)
    if prefix ~= "DC" or type(message) ~= "string" then return end
    local text = message:match("^CHAT\t(.+)$")
    if not text or text == "" then return end
    DEFAULT_CHAT_FRAME:AddMessage(
        QOL.colors.brand .. "[DungeonClear]" .. QOL.colors.reset .. " " .. text)
end)
