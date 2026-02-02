local frame = CreateFrame("Frame", "PaladinLightTrackerFrame", UIParent)
frame:SetSize(140, 18) -- Общий размер панели
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

-- Важно: отключаем обработку кликов по умолчанию
frame:EnableMouse(false)

-- Но включаем возможность получать события драга
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

-- Создаем фон для всей панели
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.3) -- Полупозрачный черный фон

-- Массив для хранения сегментов (полосок)
local segments = {}
local spacing = 4
local segmentWidth = (frame:GetWidth() - (spacing * 6)) / 5

for i = 1, 5 do
    local s = CreateFrame("StatusBar", nil, frame)
    s:SetSize(segmentWidth, frame:GetHeight() - 8)
    s:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    s:GetStatusBarTexture():SetHorizTile(false)
    s:SetStatusBarColor(1, 0.9, 0) -- Золотой цвет паладина
    
    -- Позиционирование сегментов в ряд
    if i == 1 then
        s:SetPoint("LEFT", frame, "LEFT", spacing, 0)
    else
        s:SetPoint("LEFT", segments[i-1], "RIGHT", spacing, 0)
    end
    
    -- Фон каждого сегмента (пустая полоска)
    local sBg = s:CreateTexture(nil, "BACKGROUND")
    sBg:SetAllPoints()
    sBg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
    
    s:SetMinMaxValues(0, 1)
    s:SetValue(0)
    segments[i] = s
end

-- Функция обновления визуальной части
local function UpdatePower()
    local power = UnitPower("player", Enum.PowerType.HolyPower)
    for i = 1, 5 do
        if i <= power then
            segments[i]:SetValue(1)
            segments[i]:SetAlpha(1)
            -- Эффект свечения, если энергии максимум
            if power >= 3 then
                segments[i]:SetStatusBarColor(1, 1, 0.5) 
            else
                segments[i]:SetStatusBarColor(0.7, 0.7, 0.7)
            end
        else
            segments[i]:SetValue(0)
            segments[i]:SetAlpha(0.5) -- Делаем пустые сегменты тусклыми
        end
    end
end

-- Обработка драга для перемещения фрейма
frame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() then
        self:StartMoving()
    end
end)

frame:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        PaladinLightTrackerDB = {point = point, relPoint = relPoint, x = x, y = y}
    end
end)

-- Регистрация событий
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == "PaladinLightTracker" then
        if PaladinLightTrackerDB then
            self:ClearAllPoints()
            self:SetPoint(PaladinLightTrackerDB.point, UIParent, PaladinLightTrackerDB.relPoint, PaladinLightTrackerDB.x, PaladinLightTrackerDB.y)
        end
        local _, class = UnitClass("player")
        if class ~= "PALADIN" then self:Hide() end
    elseif (event == "UNIT_POWER_UPDATE" and arg1 == "player" and arg2 == "HOLY_POWER") or event == "PLAYER_ENTERING_WORLD" then
        UpdatePower()
    end
end)
