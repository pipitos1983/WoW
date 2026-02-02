local addonName, addonTable = ...
local L = addonTable.L or setmetatable({}, { __index = function(t, k) return k end })

local frame = CreateFrame("Frame", "ResourceTrackerFrame", UIParent)
frame:SetSize(140, 18)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:SetPropagateMouseClicks(true)

local db
local defaults = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0, showMainBar = true }

-- Фон и текст-подсказка при перетаскивании
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.3)

local dragText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
dragText:SetPoint("CENTER", frame, "CENTER")
dragText:Hide()

local segments = {}
local spacing = 4
for i = 1, 10 do
    local s = CreateFrame("StatusBar", nil, frame)
    s:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local sBg = s:CreateTexture(nil, "BACKGROUND")
    sBg:SetAllPoints()
    sBg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
    s:Hide()
    segments[i] = s
end

local mainBar = CreateFrame("StatusBar", nil, frame)
mainBar:SetSize(frame:GetWidth() - (spacing * 2), 10)
mainBar:SetPoint("TOP", frame, "BOTTOM", 0, -2)
mainBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
local mbBg = mainBar:CreateTexture(nil, "BACKGROUND")
mbBg:SetAllPoints()
mbBg:SetColorTexture(0, 0, 0, 0.5)

local function GetSpecialResource()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    if class == "PALADIN" then return Enum.PowerType.HolyPower, {1, 0.9, 0}
    elseif class == "ROGUE" or (class == "DRUID" and GetShapeshiftForm() == 2) then return Enum.PowerType.ComboPoints, {1, 0.1, 0.1}
    elseif class == "MONK" then return Enum.PowerType.Chi, {0, 1, 0.8}
    elseif class == "DEATHKNIGHT" then return "RUNES", {0.6, 0.2, 1}
    elseif class == "WARLOCK" then return Enum.PowerType.SoulShards, {0.6, 0.4, 0.8}
    elseif class == "MAGE" and spec == 1 then return Enum.PowerType.ArcaneCharges, {0.1, 0.5, 1}
    elseif class == "EVOKER" then return Enum.PowerType.Essence, {0.2, 0.7, 1}
    end
    return nil
end

local function UpdatePower()
    if not db then return end
    
    local resType, color = GetSpecialResource()
    
    if resType then
        bg:Show()
        bg:SetColorTexture(0, 0, 0, 0.3)
        dragText:Hide()
        local cur, max
        if resType == "RUNES" then
            cur, max = 0, 6
            for i = 1, 6 do
                local _, _, ready = GetRuneCooldown(i)
                if ready then cur = cur + 1 end
            end
        else
            cur = UnitPower("player", resType)
            max = UnitPowerMax("player", resType)
        end

        max = (not max or max == 0) and 1 or max
        local segmentWidth = (frame:GetWidth() - (spacing * (max + 1))) / max
        for i = 1, #segments do
            if i <= max then
                segments[i]:SetSize(segmentWidth, frame:GetHeight() - 8)
                segments[i]:SetPoint("LEFT", frame, "LEFT", spacing + (i-1)*(segmentWidth + spacing), 0)
                segments[i]:SetStatusBarColor(unpack(color))
                segments[i]:SetAlpha(i <= cur and 1 or 0.2)
                segments[i]:SetValue(i <= cur and 1 or 0)
                segments[i]:Show()
            else
                segments[i]:Hide()
            end
        end
    else
        for i = 1, #segments do segments[i]:Hide() end
        
        if frame.isDragging or IsShiftKeyDown() then
            bg:Show()
            bg:SetColorTexture(1, 1, 1, 0.2)
            dragText:SetText(L["DRAG_HINT"])
            dragText:Show()
        else
            bg:Hide()
            dragText:Hide()
        end
    end

    if db.showMainBar then
        mainBar:Show()
        local pType = UnitPowerType("player")
        local pMax = UnitPowerMax("player", pType)
        mainBar:SetMinMaxValues(0, pMax > 0 and pMax or 1)
        mainBar:SetValue(UnitPower("player", pType))
        local info = GetPowerBarColor(pType)
        if info then mainBar:SetStatusBarColor(info.r, info.g, info.b) end
    else
        mainBar:Hide()
    end
end

frame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() then
        self:SetPropagateMouseClicks(false)
        self:StartMoving()
        self.isDragging = true
        UpdatePower()
    end
end)

frame:SetScript("OnMouseUp", function(self)
    if self.isDragging then
        self:StopMovingOrSizing()
        self.isDragging = false
        self:SetPropagateMouseClicks(true)
        local point, _, relPoint, x, y = self:GetPoint()
        db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
        UpdatePower()
    end
end)

frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("UNIT_MAXPOWER")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("RUNE_POWER_UPDATE")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ResourceTrackerDB = ResourceTrackerDB or {}
        
        local charKey = UnitName("player") .. " - " .. GetRealmName()
        
        if not ResourceTrackerDB[charKey] then 
            ResourceTrackerDB[charKey] = {} 
        end
        
        for k, v in pairs(defaults) do
            if ResourceTrackerDB[charKey][k] == nil then 
                ResourceTrackerDB[charKey][k] = v 
            end
        end
        
        db = ResourceTrackerDB[charKey]
        
        self:ClearAllPoints()
        self:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    end
    UpdatePower()
end)

SLASH_RESOURCETRACKER1 = "/rst"
SlashCmdList["RESOURCETRACKER"] = function(msg)
    msg = msg:lower()
    if msg == "reset" then
        db.point, db.relPoint, db.x, db.y = "CENTER", "CENTER", 0, 0
        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
        print("|cFF00FF00[RST]|r " .. L["RESET_POS"])
    elseif msg == "bar" then
        db.showMainBar = not db.showMainBar
        UpdatePower()
        local status = db.showMainBar and L["ON"] or L["OFF"]
        print("|cFF00FF00[RST]|r " .. L["BAR_TOGGLE"] .. status)
    else
        print("|cFF00FF00[RST]|r: " .. L["USAGE"])
    end
end
