-- Инициализация базы данных и фрейма событий
local addonName, addon = ...
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UPDATE_INSTANCE_INFO")

-- Таблица для сопоставления. Слева: поисковое слово из системного имени КД, Справа: красивое название для вывода в таблице
local SEASON_DUNGEONS = {
    { keyword = "Клыков", name = "Алтарь Клыков" },
    { keyword = "душегубов", name = "Закоулок душегубов" },
    { keyword = "Налоракка", name = "Пещера Налоракка" },
    { keyword = "долина", name = "Слепящая долина" },
    { keyword = "Бездны", name = "Арена Шрама Бездны" },
    { keyword = "омуты", name = "Рубиновые омуты жизни" },
    { keyword = "Королей", name = "Гробница Королей" },
    { keyword = "Сетралисс", name = "Храм Сетралисс" }
}

-- Создание кнопки на миникарте
local minimapButton = CreateFrame("Button", "SavedMythicsMinimapButton", Minimap)
minimapButton:SetSize(31, 31)
minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 1)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- 1. ПУТЬ К ВАШЕЙ ИКОНКЕ
local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\AddOns\\SavedMythics\\Media\\icon") 
icon:SetSize(21, 21)
icon:SetPoint("CENTER", 0, 0)
icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)

local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT", 0, 0)

-- Перемещение кнопки
minimapButton:SetMovable(true)
minimapButton:RegisterForDrag("LeftButton")

local function UpdateMinimapButtonPosition(angle)
    -- 2. РАДИУС ВРАЩЕНИЯ СТРОГО 100
    local radius = 100 
    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(self)
        local mx, my = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        local angle = math.deg(math.atan2((my/scale) - cy, (mx/scale) - cx))
        if angle < 0 then angle = angle + 360 end
        
        if not SavedMythicsDB then SavedMythicsDB = {} end
        SavedMythicsDB.buttonAngle = angle
        UpdateMinimapButtonPosition(angle)
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

minimapButton:RegisterForClicks("LeftButtonUp")

-- Тултип
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("SavedMythics", 1, 1, 1)
    GameTooltip:AddLine("Нажмите, чтобы открыть окно КД подземелий", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Создание главного окна
local mainFrame = CreateFrame("Frame", "SavedMythicsMainFrame", UIParent, "DefaultPanelTemplate")
mainFrame:SetSize(450, 420)
mainFrame:SetPoint("CENTER")
mainFrame:Hide()

if mainFrame.TitleContainer and mainFrame.TitleContainer.TitleText then
    mainFrame.TitleContainer.TitleText:SetText("Сохранения эпохальных подземелий")
end

mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -4, -4)

-- Область прокрутки
local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -30)
scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -35, 15)

local scrollContent = CreateFrame("Frame", nil, scrollFrame)
scrollContent:SetSize(400, 1500)
scrollFrame:SetScrollChild(scrollContent)

-- Обновление КД текущего персонажа (Улучшенный поиск по вхождению строки)
local function UpdateLockoutData()
    if not SavedMythicsDB then SavedMythicsDB = {} end
    if not SavedMythicsDB.characters then SavedMythicsDB.characters = {} end
    
    local charKey = UnitName("player") .. " - " .. GetRealmName()
    SavedMythicsDB.characters[charKey] = {}
    
    local numSaved = GetNumSavedInstances()
    for i = 1, numSaved do
        local name, _, _, _, locked = GetSavedInstanceInfo(i)
        
        -- Если сохранение активно и имя существует
        if locked and name then
            -- Переводим имя подземелья от сервера в нижний регистр
            local lowerName = string.lower(name)
            
            for _, seasonDungeon in ipairs(SEASON_DUNGEONS) do
                -- Переводим ключевое слово в нижний регистр для надежности
                local lowerKeyword = string.lower(seasonDungeon.keyword)
                
                -- Ищем совпадение. Флаг true отключает регулярные выражения (простой поиск текста)
                if string.find(lowerName, lowerKeyword, 1, true) then
                    SavedMythicsDB.characters[charKey][seasonDungeon.name] = true
                end
            end
        end
    end
end

-- Генерация таблицы с разделением по цветам
-- Генерация таблицы с разделением по цветам (Текущий персонаж всегда первый)
local function RenderTable()
    -- Очистка старых строк
    for _, child in ipairs({scrollContent:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    if not SavedMythicsDB or not SavedMythicsDB.characters then return end
    
    local yOffset = -10
    local currentPlayerKey = UnitName("player") .. " - " .. GetRealmName()
    
    -- Вспомогательная функция для отрисовки одного персонажа
    local function DrawCharacter(charName, lockedDungeons)
        -- Имя персонажа
        local header = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)
        
        -- Выделяем текущего персонажа в списке (например, добавляем метку ТЕКУЩИЙ)
        if charName == currentPlayerKey then
            header:SetText(charName)
            header:SetTextColor(1, 0.82, 0, 1) -- Золотой цвет для себя
        else
            header:SetText(charName)
            header:SetTextColor(1, 0.82, 0.6, 1) -- Обычный цвет для твинков
        end
        yOffset = yOffset - 22
        
        -- Построение списка подземелий
        for _, dungeon in ipairs(SEASON_DUNGEONS) do
            local txt = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            txt:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 25, yOffset)
            
            if lockedDungeons[dungeon.name] then
                txt:SetText("• " .. dungeon.name .. " (Пройдено)")
                txt:SetTextColor(0, 1, 0, 1) -- Зеленый
            else
                txt:SetText("• " .. dungeon.name .. " (Доступно)")
                txt:SetTextColor(1, 1, 1, 1) -- Белый
            end
            yOffset = yOffset - 16
        end
        yOffset = yOffset - 15 
    end

    -- 1. Сначала принудительно выводим текущего персонажа
    if SavedMythicsDB.characters[currentPlayerKey] then
        DrawCharacter(currentPlayerKey, SavedMythicsDB.characters[currentPlayerKey])
    end

    -- 2. Затем выводим всех остальных (альтов)
    for charName, lockedDungeons in pairs(SavedMythicsDB.characters) do
        if charName ~= currentPlayerKey then
            DrawCharacter(charName, lockedDungeons)
        end
    end
end


-- Клик по кнопке миникарты
minimapButton:SetScript("OnClick", function()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        RenderTable()
        mainFrame:Show()
    end
end)

-- Отслеживание событий
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        if not SavedMythicsDB then SavedMythicsDB = {} end
        if not SavedMythicsDB.characters then SavedMythicsDB.characters = {} end
        if not SavedMythicsDB.buttonAngle then SavedMythicsDB.buttonAngle = 45 end
        
        UpdateMinimapButtonPosition(SavedMythicsDB.buttonAngle)
        mainFrame:Hide()
        UpdateLockoutData()
    elseif event == "UPDATE_INSTANCE_INFO" then
        UpdateLockoutData()
    end
end)
