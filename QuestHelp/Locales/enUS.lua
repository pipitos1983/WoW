local _, addonTable = ...
addonTable.L = addonTable.L or setmetatable({}, { __index = function(t, k) return k end })
local L = addonTable.L

L["SETTINGS"] = "Settings"
L["ADDON_DESCRIPTION"] = "Wowhead shortcuts and convenient automation for quests."

L["AUTO_ACCEPT_TITLE"] = "Auto-accept NPC quests"
L["AUTO_COMPLETE_TITLE"] = "Auto-complete quests when talking to NPCs"
L["AUTO_REWARD_TITLE"] = "Auto-choose the highest selling value reward"
L["CHAT_LINK_TITLE"] = "Show chat link when opening Wowhead window"
L["ALT_CHAT_TITLE"] = "Alt + Click on quest link in chat opens Wowhead"
L["ALT_TRACKER_TITLE"] = "Alt + Click on quest in tracker opens Wowhead"

L["TIP"] = "Tip"
L["SHIFT_PAUSE_NOTE"] = "Hold |cffffffffShift, Ctrl or Alt|r when talking to an NPC to temporarily pause auto-accept."

L["NO_QUEST_SELECTED"] = "No quest selected. Use: "
L["NAME"] = "Name"

L["LOADED_SUCCESSFULLY"] = "Loaded successfully. Use "
L["OR"] = "or"
