-- QOLAddon/UI/ConfirmDialog.lua
-- Confirmation dialogs for dangerous commands.

local addonName, QOL = ...

StaticPopupDialogs["QOL_CONFIRM_CMD"] = {
    text = "|cffffc94dQOL Addon|r\n\nRun this command?\n\n|cffffd100%s|r",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local line = self.data
        if line and line ~= "" then QOL._ExecuteRaw(line) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,   -- avoid UIParent taint on 3.3.5a
    showAlert = true,
}

-- Break camp is destructive and the server itself is two-step: the button has
-- already sent `.camp leave` (which prints the server's own warning); accepting
-- here sends the `confirm` form that actually destroys the camp + all props.
StaticPopupDialogs["QOL_CONFIRM_CAMP_LEAVE"] = {
    text = "|cffff4444Break camp?|r\n\nThis destroys your Warband Camp and EVERYTHING placed in it. "
        .. "It cannot be undone, and the camp belongs to your whole account.\n\nReally break it?",
    button1 = "Yes, break camp",
    button2 = CANCEL,
    OnAccept = function()
        QOL._ExecuteRaw(".camp leave confirm")
        if QOL.Warband then QOL.Warband.Probe(2) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = true,
}
