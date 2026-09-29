-- ========================================================================
-- Quest Help (BetterQuestHelp) v2.0.0
-- Author: DarkAce
-- ========================================================================

-- Localization vars
local _, addonTable = ...
local L = addonTable.L or setmetatable({}, { __index = function(t, k) return k end })
-- 

local ADDON_NAME, ns = ...
local BQH = {}
_G.BetterQuestHelp = BQH

-- Configuración por defecto
local DB_DEFAULTS = {
    autoAccept = false,
    autoComplete = false,
    autoReward = false,         -- Auto-elegir la recompensa con mayor valor de venta
    wowheadLocale = "auto",    -- "auto", "es", "en", "de", "fr", "ru", "pt", "it"
    showChatLink = true,       -- Mostrar enlace en el chat al abrir el popup
    altClickChat = true,       -- Alt+Click en links de misión en el chat abre Wowhead
    altClickTracker = true,    -- Alt+Click en el rastreador de misiones abre Wowhead
}

-- Mapeo de idiomas de WoW a subdominios de Wowhead
local LOCALE_SUBDOMAINS = {
    esES = "es",
    esMX = "es",
    deDE = "de",
    frFR = "fr",
    ruRU = "ru",
    ptBR = "pt",
    itIT = "it",
    koKR = "ko",
    zhCN = "cn",
    zhTW = "cn",
    enUS = "www",
    enGB = "www",
}

------------------------------------------------------------------------
-- Utilidades de Enlaces de Wowhead
------------------------------------------------------------------------

local function GetResolvedLocaleSubdomain()
    local setting = BetterQuestHelpDB.wowheadLocale or "auto"
    if setting ~= "auto" and setting ~= "" then
        return setting == "en" and "www" or setting
    end

    local clientLocale = GetLocale and GetLocale() or "enUS"
    return LOCALE_SUBDOMAINS[clientLocale] or "www"
end

local function WowheadQuestURL(questID)
    if not questID then return nil end
    local sub = GetResolvedLocaleSubdomain()

    -- Detección de versión de WoW
    local isClassic = false
    local isCata = false
    if _G.WOW_PROJECT_ID then
        if _G.WOW_PROJECT_ID == _G.WOW_PROJECT_CLASSIC then
            isClassic = true
        elseif _G.WOW_PROJECT_ID == (_G.WOW_PROJECT_CATACLYSM_CLASSIC or 14) or _G.WOW_PROJECT_ID == (_G.WOW_PROJECT_WRATH_CLASSIC or 11) then
            isCata = true
        end
    end

    if isClassic then
        return ("https://%s.wowhead.com/classic/quest=%d"):format(sub, questID)
    elseif isCata then
        return ("https://%s.wowhead.com/cata/quest=%d"):format(sub, questID)
    else
        return ("https://%s.wowhead.com/quest=%d"):format(sub, questID)
    end
end

------------------------------------------------------------------------
-- Diálogo Popup para Copiar Enlaces
------------------------------------------------------------------------

StaticPopupDialogs["BQH_COPY_URL"] = {
    text = "|cff00ff88[Quest Help]|r Copiar enlace de Wowhead (Ctrl+C):",
    button1 = OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    hasEditBox = true,
    preferredIndex = 3,
    OnShow = function(self, data)
        local box = self.editBox or self.EditBox
        if not box then return end
        box:SetWidth(280)
        box:SetText(data or "")
        box:HighlightText()
        box:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    OnAccept = function() end,
}

local function ShowWowheadLink(questID, questTitle, silent)
    if not questID or questID <= 0 then
        if not silent then
            print("|cffff5555[Quest Help]|r No se pudo determinar el ID de la misión.")
        end
        return
    end

    local url = WowheadQuestURL(questID)
    if not url then return end

    if BetterQuestHelpDB.showChatLink and not silent then
        local titleText = questTitle and (" (|cffffd100%s|r)"):format(questTitle) or ""
        print(("|cff00ff88[Quest Help]|r Misión #%d%s: |cff00ccff%s|r"):format(questID, titleText, url))
    end

    StaticPopup_Show("BQH_COPY_URL", nil, nil, url)
end
BQH.ShowWowheadLink = ShowWowheadLink

------------------------------------------------------------------------
-- Obtención Segura de QuestID (Retail + Classic)
------------------------------------------------------------------------

local function SafeGetQuestIDFromLogIndex(index)
    if not index or index <= 0 then return nil end

    -- Retail moderno
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(index)
        if info and info.questID and info.questID > 0 then
            return info.questID, info.title
        end
    end

    -- Classic: link "quest:12345:"
    if GetQuestLink then
        local link = GetQuestLink(index)
        if link then
            local id = link:match("quest:(%d+)")
            if id then
                local title = GetQuestLogTitle and select(1, GetQuestLogTitle(index)) or nil
                return tonumber(id), title
            end
        end
    end

    -- Classic selección
    if GetQuestLogTitle then
        local title, _, _, _, _, _, _, questID = GetQuestLogTitle(index)
        if questID and questID > 0 then
            return questID, title
        end
    end

    return nil, nil
end

local function GetQuestID_Selected()
    -- Retail
    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        local qid = C_QuestLog.GetSelectedQuest()
        if qid and qid > 0 then
            local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid) or nil
            return qid, title
        end
    end

    -- QuestFrame abierta con PNJ
    if GetQuestID then
        local qid = GetQuestID()
        if qid and qid > 0 then
            local title = GetTitleText and GetTitleText() or nil
            return qid, title
        end
    end

    -- Classic QuestLog selection
    if GetQuestLogSelection then
        local idx = GetQuestLogSelection()
        if idx and idx > 0 then
            return SafeGetQuestIDFromLogIndex(idx)
        end
    end

    return nil, nil
end

------------------------------------------------------------------------
-- Integración con Chat (Alt+Click en enlaces de misión)
------------------------------------------------------------------------

local orig_SetItemRef = SetItemRef
hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
    if not BetterQuestHelpDB.altClickChat then return end
    if not IsAltKeyDown() then return end
    if not link then return end

    local linkType, id = link:match("^(%a+):(%d+)")
    if linkType == "quest" and id then
        local qid = tonumber(id)
        if qid then
            ShowWowheadLink(qid)
        end
    end
end)

------------------------------------------------------------------------
-- Integración con Rastreador de Misiones (Objective Tracker)
------------------------------------------------------------------------

local function HookObjectiveTracker()
    -- Retail 10.0+ / 11.x Objective Tracker
    if ObjectiveTrackerManager and ObjectiveTrackerManager.GetFocusedQuestID then
        -- Retail moderno
    end

    -- Hook genérico de clics en bloques del tracker (Retail y Classic)
    local function HandleTrackerClick(block, questID)
        if not BetterQuestHelpDB.altClickTracker then return end
        if IsAltKeyDown() and questID then
            ShowWowheadLink(questID)
        end
    end

    -- Retail QuestObjectiveTracker
    if QuestObjectiveTracker and QuestObjectiveTracker.ContentsFrame then
        hooksecurefunc(QuestObjectiveTracker, "OnBlockHeaderClick", function(self, block)
            if block and block.id and IsAltKeyDown() then
                ShowWowheadLink(block.id)
            end
        end)
    end
end

------------------------------------------------------------------------
-- Botones en la Interfaz de Misiones
-- ------------------------------------------------------------------------

local function CreateHelpButton_Retail()
    if not QuestMapFrame or not QuestMapFrame.DetailsFrame then return end
    if BQH.DetailsButton then return end

    local parent = QuestMapFrame.DetailsFrame
    local btn = CreateFrame("Button", "BQH_DetailsHelpButton", parent, "UIPanelButtonTemplate")
    btn:SetSize(75, 22)
    btn:SetText("Wowhead")
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -12)

    btn:SetScript("OnClick", function()
        local qid, title = GetQuestID_Selected()
        ShowWowheadLink(qid, title)
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cff00ff88Quest Help|r", 1, 1, 1)
        GameTooltip:AddLine("Clic: Copiar enlace de Wowhead para esta misión.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Atajo: Usa /qh config para opciones.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    BQH.DetailsButton = btn
end

local function CreateHelpButton_ClassicQuestFrame()
    if not QuestFrame then return end

    local function AttachToPanel(panel, btnName, point, x, y)
        if not panel or panel[btnName] then return end
        local btn = CreateFrame("Button", btnName, panel, "UIPanelButtonTemplate")
        btn:SetSize(80, 22)
        btn:SetText("Wowhead")
        btn:SetPoint(point or "TOPRIGHT", panel, point or "TOPRIGHT", x or -30, y or -30)

        btn:SetScript("OnClick", function()
            local qid, title = GetQuestID() or GetQuestID_Selected()
            ShowWowheadLink(qid, title)
        end)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cff00ff88Quest Help|r", 1, 1, 1)
            GameTooltip:AddLine("Copiar enlace de Wowhead para esta misión.", 0.9, 0.9, 0.9)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        panel[btnName] = btn
    end

    if QuestFrameDetailPanel then AttachToPanel(QuestFrameDetailPanel, "BQH_DetailBtn", "TOPRIGHT", -30, -30) end
    if QuestFrameRewardPanel then AttachToPanel(QuestFrameRewardPanel, "BQH_RewardBtn", "TOPRIGHT", -30, -30) end
    if QuestLogFrame then AttachToPanel(QuestLogFrame, "BQH_ClassicLogBtn", "TOPRIGHT", -35, -40) end
end

------------------------------------------------------------------------
-- Lógica Inteligente de Auto-Aceptar y Auto-Completar
------------------------------------------------------------------------

local function IsModifierActive()
    return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

-- Selección de la recompensa con mayor valor en mercader
local function SelectBestQuestReward()
    local numChoices = GetNumQuestChoices()
    if numChoices == 0 then
        GetQuestReward()
        return
    elseif numChoices == 1 then
        GetQuestReward(1)
        return
    end

    -- Si hay más de 1 opción y está activado autoReward
    if BetterQuestHelpDB.autoReward then
        local bestIndex = 1
        local highestValue = -1

        for i = 1, numChoices do
            local link = GetQuestItemLink("choice", i)
            local sellPrice = 0
            if link then
                if C_Item and C_Item.GetItemInfo then
                    sellPrice = select(11, C_Item.GetItemInfo(link)) or 0
                elseif GetItemInfo then
                    sellPrice = select(11, GetItemInfo(link)) or 0
                end
            end
            if sellPrice > highestValue then
                highestValue = sellPrice
                bestIndex = i
            end
        end

        GetQuestReward(bestIndex)
    end
end

local function OnQuestDetail()
    if not BetterQuestHelpDB or not BetterQuestHelpDB.autoAccept then return end
    if IsModifierActive() then return end

    if AcceptQuest then
        AcceptQuest()
    end
end

local function OnQuestProgress()
    if not BetterQuestHelpDB or not BetterQuestHelpDB.autoComplete then return end
    if IsModifierActive() then return end

    if IsQuestCompletable and IsQuestCompletable() then
        CompleteQuest()
    end
end

local function OnQuestComplete()
    if not BetterQuestHelpDB or not BetterQuestHelpDB.autoComplete then return end
    if IsModifierActive() then return end

    SelectBestQuestReward()
end

local function OnGossipShow()
    if not BetterQuestHelpDB then return end
    if IsModifierActive() then return end

    -- Auto Aceptar (Misiones disponibles)
    if BetterQuestHelpDB.autoAccept then
        if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
            local quests = C_GossipInfo.GetAvailableQuests()
            if quests and #quests > 0 then
                for _, quest in ipairs(quests) do
                    if not quest.isTrivial or BetterQuestHelpDB.autoAcceptTrivial then
                        C_GossipInfo.SelectAvailableQuest(quest.questID)
                        break
                    end
                end
            end
        elseif GetGossipAvailableQuests then
            local numQuests = GetNumGossipAvailableQuests()
            if numQuests > 0 then
                SelectGossipAvailableQuest(1)
            end
        end
    end

    -- Auto Completar (Misiones activas listas para entregar)
    if BetterQuestHelpDB.autoComplete then
        if C_GossipInfo and C_GossipInfo.GetActiveQuests then
            local quests = C_GossipInfo.GetActiveQuests()
            if quests and #quests > 0 then
                for _, quest in ipairs(quests) do
                    if quest.isComplete then
                        C_GossipInfo.SelectActiveQuest(quest.questID)
                        break
                    end
                end
            end
        elseif GetGossipActiveQuests then
            local numActive = GetNumGossipActiveQuests()
            if numActive > 0 then
                SelectGossipActiveQuest(1)
            end
        end
    end
end

local function OnQuestGreeting()
    if not BetterQuestHelpDB then return end
    if IsModifierActive() then return end

    if BetterQuestHelpDB.autoComplete then
        local numActive = GetNumActiveQuests()
        if numActive > 0 then
            SelectActiveQuest(1)
            return
        end
    end

    if BetterQuestHelpDB.autoAccept then
        local numAvailable = GetNumAvailableQuests()
        if numAvailable > 0 then
            SelectAvailableQuest(1)
        end
    end
end

------------------------------------------------------------------------
-- Panel de Opciones Integrado en Blizzard Settings
------------------------------------------------------------------------

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "BQH_OptionsPanel", UIParent)
    panel.name = "Quest Help"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff88Quest Help|r - " .. L["SETTINGS"])

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText(L["ADDON_DESCRIPTION"])

    local function CreateCheck(name, labelText, dbKey, relativeTo, yOffset)
        local cb = CreateFrame("CheckButton", "BQH_Check_" .. name, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", 0, yOffset or -10)
        _G[cb:GetName() .. "Text"]:SetText(labelText)
        cb:SetChecked(BetterQuestHelpDB[dbKey])
        cb:SetScript("OnClick", function(self)
            BetterQuestHelpDB[dbKey] = self:GetChecked()
        end)
        return cb
    end

    local cbAutoAccept = CreateCheck("AutoAccept", L["AUTO_ACCEPT_TITLE"], "autoAccept", desc, -16)
    local cbAutoComplete = CreateCheck("AutoComplete", L["AUTO_COMPLETE_TITLE"], "autoComplete", cbAutoAccept, -10)
    local cbAutoReward = CreateCheck("AutoReward", L["AUTO_REWARD_TITLE"], "autoReward", cbAutoComplete, -10)
    local cbChatLink = CreateCheck("ChatLink", L["CHAT_LINK_TITLE"], "showChatLink", cbAutoReward, -10)
    local cbAltChat = CreateCheck("AltChat", L["ALT_CHAT_TITLE"], "altClickChat", cbChatLink, -10)
    local cbAltTracker = CreateCheck("AltTracker", L["ALT_TRACKER_TITLE"], "altClickTracker", cbAltChat, -10)



    -- Nota sobre pausar automatización
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", cbAltTracker, "BOTTOMLEFT", 0, -20)
    note:SetText("|cffffcc00" .. L["TIP"] .. ":|r " .. L["SHIFT_PAUSE_NOTE"])

    -- Registro en el menú de opciones (Retail 10.0+ / Classic)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category, layout = Settings.RegisterCanvasLayoutCategory(panel, "Quest Help")
        Settings.RegisterAddOnCategory(category)
        BQH.SettingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        BQH.OptionsPanel = panel
    end
end

function BQH.OpenSettings()
    if Settings and Settings.OpenToCategory and BQH.SettingsCategory then
        Settings.OpenToCategory(BQH.SettingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and BQH.OptionsPanel then
        InterfaceOptionsFrame_OpenToCategory(BQH.OptionsPanel)
    else
        print("|cff00ff88[Quest Help]|r Usa /qh para ver los comandos disponibles.")
    end
end

------------------------------------------------------------------------
-- Comandos Slash (/qh, /questhelp)
------------------------------------------------------------------------

SLASH_BETTERQUESTHELP1 = "/qh"
SLASH_BETTERQUESTHELP2 = "/questhelp"
SlashCmdList["BETTERQUESTHELP"] = function(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""

    if msg == "" then
        local qid, title = GetQuestID_Selected()
        if qid then
            ShowWowheadLink(qid, title)
        else
            print("|cffff5555[Quest Help]|r" .. L["NO_QUEST_SELECTED"] .. "|cff00ccff/qh <ID>|r" .. L["OR"] .. "|cff00ccff/qh find <".. L["NAME"] ..">|r")
        end
        return
    end

    -- /qh config / opt
    if msg:lower() == "config" or msg:lower() == "opt" or msg:lower() == "options" then
        BQH.OpenSettings()
        return
    end

    -- /qh <ID>
    local num = tonumber(msg)
    if num then
        ShowWowheadLink(num)
        return
    end

    -- /qh find <nombre>
    local cmd, rest = msg:match("^(%S+)%s+(.+)$")
    if cmd and cmd:lower() == "find" and rest and rest ~= "" then
        local matchedQID, matchedTitle = nil, nil
        if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
            local numEntries = C_QuestLog.GetNumQuestLogEntries()
            for i = 1, numEntries do
                local info = C_QuestLog.GetInfo(i)
                if info and not info.isHeader and info.title and info.title:lower():find(rest:lower(), 1, true) then
                    matchedQID = info.questID
                    matchedTitle = info.title
                    break
                end
            end
        else
            local numEntries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
            for i = 1, numEntries do
                local title = GetQuestLogTitle and select(1, GetQuestLogTitle(i))
                if title and title:lower():find(rest:lower(), 1, true) then
                    matchedQID = SafeGetQuestIDFromLogIndex(i)
                    matchedTitle = title
                    break
                end
            end
        end

        if matchedQID then
            ShowWowheadLink(matchedQID, matchedTitle)
        else
            print("|cffff5555[Quest Help]|r No se encontró ninguna misión en tu registro que contenga: " .. rest)
        end
        return
    end

    -- /qh auto
    if msg:lower() == "auto" then
        BetterQuestHelpDB.autoAccept = not BetterQuestHelpDB.autoAccept
        print("|cff00ff88[Quest Help]|r Auto-Aceptar: " .. (BetterQuestHelpDB.autoAccept and "|cff00ff00ACTIVADO|r" or "|cffff0000DESACTIVADO|r"))
        return
    end

    -- /qh complete
    if msg:lower() == "complete" then
        BetterQuestHelpDB.autoComplete = not BetterQuestHelpDB.autoComplete
        print("|cff00ff88[Quest Help]|r Auto-Completar: " .. (BetterQuestHelpDB.autoComplete and "|cff00ff00ACTIVADO|r" or "|cffff0000DESACTIVADO|r"))
        return
    end

    -- /qh reward
    if msg:lower() == "reward" then
        BetterQuestHelpDB.autoReward = not BetterQuestHelpDB.autoReward
        print("|cff00ff88[Quest Help]|r Auto-elegir mejor recompensa: " .. (BetterQuestHelpDB.autoReward and "|cff00ff00ACTIVADO|r" or "|cffff0000DESACTIVADO|r"))
        return
    end

    -- Ayuda de comandos
    print("|cff00ff88[Quest Help v2.0]|r Comandos:")
    print("  |cff00ccff/qh|r                  -> Copiar enlace de la misión seleccionada")
    print("  |cff00ccff/qh <ID>|r             -> Copiar enlace de una misión por su ID")
    print("  |cff00ccff/qh find <texto>|r     -> Buscar misión en tu registro por nombre")
    print("  |cff00ccff/qh auto|r             -> Alternar auto-aceptar misiones")
    print("  |cff00ccff/qh complete|r         -> Alternar auto-completar misiones")
    print("  |cff00ccff/qh reward|r           -> Alternar elección de la mejor recompensa")
    print("  |cff00ccff/qh config|r           -> Abrir menú de configuración")
    print("  |cffffd100Atajo:|r Alt + Clic en un enlace de misión del chat para abrir Wowhead.")
end

------------------------------------------------------------------------
-- Inicialización y Gestión de Eventos
------------------------------------------------------------------------

local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("QUEST_DETAIL")
mainFrame:RegisterEvent("GOSSIP_SHOW")
mainFrame:RegisterEvent("QUEST_GREETING")
mainFrame:RegisterEvent("QUEST_PROGRESS")
mainFrame:RegisterEvent("QUEST_COMPLETE")

mainFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            -- Inicializar Base de Datos con valores por defecto
            if not BetterQuestHelpDB then BetterQuestHelpDB = {} end
            for k, v in pairs(DB_DEFAULTS) do
                if BetterQuestHelpDB[k] == nil then
                    BetterQuestHelpDB[k] = v
                end
            end
            CreateOptionsPanel()
        end

        if arg1 == "Blizzard_WorldMap" or arg1 == "Blizzard_QuestNavigation" then
            CreateHelpButton_Retail()
        end

    elseif event == "PLAYER_LOGIN" then
        CreateHelpButton_Retail()
        CreateHelpButton_ClassicQuestFrame()
        HookObjectiveTracker()

        -- Hook en QuestMapFrame si se abre después
        if QuestMapFrame then
            QuestMapFrame:HookScript("OnShow", CreateHelpButton_Retail)
        end

        print("|cff00ff88[Quest Help v2.0]|r " .. L["LOADED_SUCCESSFULLY"] .. "|cff00ccff/qh|r " .. L["OR"] .. " |cff00ccff/qh config|r.")


    elseif event == "QUEST_DETAIL" then
        OnQuestDetail()
    elseif event == "GOSSIP_SHOW" then
        OnGossipShow()
    elseif event == "QUEST_GREETING" then
        OnQuestGreeting()
    elseif event == "QUEST_PROGRESS" then
        OnQuestProgress()
    elseif event == "QUEST_COMPLETE" then
        OnQuestComplete()
    end
end)
