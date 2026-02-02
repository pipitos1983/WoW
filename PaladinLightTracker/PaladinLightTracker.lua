-- Создание основного фрейма
local frame = CreateFrame("Frame", "PaladinLightTrackerFrame", UIParent)
frame:SetSize(140, 18)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)

-- КЛЮЧЕВАЯ ФУНКЦИЯ: Позволяет кликам проходить сквозь фрейм в игру
frame:SetPropagateMouseClicks(true)

-- Фон панели
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.3)

-- Создание сегментов энергии
local segments = {}
local spacing = 4
local segmentWidth = (frame:GetWidth() - (spacing * 6)) / 5

for i = 1, 5 do
    local s = CreateFrame("StatusBar", nil, frame)
    s:SetSize(segmentWidth, frame:GetHeight() - 8)
    s:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    s:GetStatusBarTexture():SetHorizTile(false)
    
    if i == 1 then
        s:SetPoint("LEFT", frame, "LEFT", spacing, 0)
    else
        s:SetPoint("LEFT", segments[i-1], "RIGHT", spacing, 0)
    end
    
    local sBg = s:CreateTexture(nil, "BACKGROUND")
    sBg:SetAllPoints()
    sBg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
    
    s:SetMinMaxValues(0, 1)
    s:SetValue(0)
    segments[i] = s
end

-- Логика обновления энергии
local function UpdatePower()
    local power = UnitPower("player", Enum.PowerType.HolyPower)
    local maxPower = UnitPowerMax("player", Enum.PowerType.HolyPower)
    
    for i = 1, 5 do
        if i <= power then
            segments[i]:SetValue(1)
            segments[i]:SetAlpha(1)
            -- Подсветка: ярко-желтый при накоплении 3+ или 5 (зависит от предпочтений)
            if power >= 3 then
                segments[i]:SetStatusBarColor(1, 0.9, 0) -- Золотой
            else
                segments[i]:SetStatusBarColor(0.7, 0.7, 0.7) -- Серый (накопление)
            end
        else
            segments[i]:SetValue(0)
            segments[i]:SetAlpha(0.3)
        end
    end
end

-- Перемещение фрейма (Shift + ЛКМ)
frame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() then
        self:SetPropagateMouseClicks(false) -- Отключаем прокликивание на время драга
        self:StartMoving()
        self.isDragging = true
    end
end)

frame:SetScript("OnMouseUp", function(self, button)
    if self.isDragging then
        self:StopMovingOrSizing()
        self.isDragging = false
        self:SetPropagateMouseClicks(true) -- Возвращаем прокликивание
        
        -- Сохранение позиции
        local point, _, relPoint, x, y = self:GetPoint()
        PaladinLightTrackerDB = {point = point, relPoint = relPoint, x = x, y = y}
    end
end)

frame:SetScript("OnHide", function(self)
    if self.isDragging then
        self:StopMovingOrSizing()
        self.isDragging = false
    end
end)

-- Обработка событий
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == "PaladinLightTracker" then
        -- Загрузка позиции
        if PaladinLightTrackerDB then
            self:ClearAllPoints()
            self:SetPoint(PaladinLightTrackerDB.point, UIParent, PaladinLightTrackerDB.relPoint, PaladinLightTrackerDB.x, PaladinLightTrackerDB.y)
        end
        -- Проверка класса
        local _, class = UnitClass("player")
        if class ~= "PALADIN" then 
            self:UnregisterAllEvents()
            self:Hide() 
        end
    elseif (event == "UNIT_POWER_UPDATE" and arg1 == "player" and arg2 == "HOLY_POWER") 
        or event == "PLAYER_ENTERING_WORLD" 
        or event == "PLAYER_TALENT_UPDATE" then
        UpdatePower()
    end
end)
