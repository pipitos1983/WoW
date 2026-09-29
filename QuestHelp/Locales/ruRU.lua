local _, addonTable = ...
if GetLocale() ~= "ruRU" then return end

local L = addonTable.L
if not L then return end

L["SETTINGS"] = "Настройки"
L["ADDON_DESCRIPTION"] = "Горячие клавиши Wowhead и удобная автоматизация для заданий."

L["AUTO_ACCEPT_TITLE"] = "Автоматически принимать задания у НИП"
L["AUTO_COMPLETE_TITLE"] = "Автоматически сдавать задания при разговоре с НИП"
L["AUTO_REWARD_TITLE"] = "Автоматически выбирать самую дорогую награду (для продажи)"
L["CHAT_LINK_TITLE"] = "Показывать ссылку в чате при открытии окна Wowhead"
L["ALT_CHAT_TITLE"] = "Alt + клик по заданию в чате открывает Wowhead"
L["ALT_TRACKER_TITLE"] = "Alt + клик по заданию в трекере открывает Wowhead"

L["TIP"] = "Совет"
L["SHIFT_PAUSE_NOTE"] = "Удерживайте |cffffffffShift, Ctrl или Alt|r при разговоре с НИП, чтобы временно приостановить автопринятие."

L["NO_QUEST_SELECTED"] = "Задание не выбрано. Используйте: "
L["NAME"] = "Название"

L["LOADED_SUCCESSFULLY"] = "успешно загружен. Используйте "
L["OR"] = "или"
