local _, addonTable = ...
if GetLocale() ~= "esES" and GetLocale() ~= "esMX" then return end

local L = addonTable.L or setmetatable({}, { __index = function(t, k) return k end })
addonTable.L = L

L["SETTINGS"] = "Configuración"
L["ADDON_DESCRIPTION"] = "Atajos de Wowhead y automatización cómoda para misiones."

L["AUTO_ACCEPT_TITLE"] = "Auto-Aceptar misiones de PNJ"
L["AUTO_COMPLETE_TITLE"] = "Auto-Completar misiones al hablar con el PNJ"
L["AUTO_REWARD_TITLE"] = "Auto-elegir la recompensa más cara (mayor precio de venta)"
L["CHAT_LINK_TITLE"] = "Mostrar enlace en el chat al abrir ventana de Wowhead"
L["ALT_CHAT_TITLE"] = "Alt + Clic en enlace de misión del chat abre Wowhead"
L["ALT_TRACKER_TITLE"] = "Alt + Clic en misión del rastreador abre Wowhead"

L["TIP"] = "Consejo"
L["SHIFT_PAUSE_NOTE"] = "Mantén pulsado |cffffffffShift, Ctrl o Alt|r al hablar con un PNJ para pausar el auto-aceptar temporalmente."

L["NO_QUEST_SELECTED"] = "No hay misión seleccionada. Usa: "
L["NAME"] = "nombre"

L["LOADED_SUCCESSFULLY"] = "Cargado con éxito. Usa "
L["OR"] = "o"
