local _, ns = ...

local M = ns.RegisterModule("HealthBars", {
    label = "Health bars",
    defaults = { enabled = true, raidFrames = true },
})

-- Recolors health bars that Blizzard shows green (or as its built-in green
-- art with a white vertex color) to the theme's health color. Other colors
-- Blizzard sets (class colors, tapped grey, disconnected, etc.) are kept.
-- The bar texture is desaturated before tinting so the theme color replaces
-- Blizzard's green instead of multiplying with it.
-- Bars are only recolored; health values are never read.

local UNIT_FRAMES = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "TargetFrameToT", "FocusFrameToT",
    "Boss1TargetFrame", "Boss2TargetFrame", "Boss3TargetFrame", "Boss4TargetFrame", "Boss5TargetFrame",
    "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4",
}

local bars = {} -- StatusBar -> { color = {r, g, b, a}, desaturated = bool }
local busy = false
local raidHooked = false

local function IsGreen(r, g, b)
    return g > 0.7 and r < 0.35 and b < 0.35
end

local function IsWhite(r, g, b)
    return r > 0.95 and g > 0.95 and b > 0.95
end

local function Paint(bar)
    local info = bars[bar]
    local tex = bar:GetStatusBarTexture()
    if not (info and tex) then return end
    local r, g, b, a = unpack(info.color)
    local health = M.active and ns.db.theme.health
    busy = true
    if health and (IsGreen(r, g, b) or IsWhite(r, g, b)) then
        tex:SetDesaturated(true)
        bar:SetStatusBarColor(health.r, health.g, health.b, a or 1)
    else
        tex:SetDesaturated(info.desaturated)
        bar:SetStatusBarColor(r, g, b, a or 1)
    end
    busy = false
end

local function Watch(bar)
    if not (bar and bar.GetStatusBarTexture) then return end
    if bars[bar] then
        Paint(bar)
        return
    end
    local tex = bar:GetStatusBarTexture()
    bars[bar] = {
        color = { bar:GetStatusBarColor() },
        desaturated = tex and tex.IsDesaturated and tex:IsDesaturated() or false,
    }
    hooksecurefunc(bar, "SetStatusBarColor", function(self, r, g, b, a)
        if busy then return end
        bars[self].color = { r, g, b, a }
        Paint(self)
    end)
    hooksecurefunc(bar, "SetStatusBarTexture", function(self)
        if not busy then Paint(self) end
    end)
    Paint(bar)
end

local function UnitFrameBar(frame)
    return frame and (frame.healthbar or frame.HealthBar)
end

local function WatchUnitFrames()
    for _, name in ipairs(UNIT_FRAMES) do
        Watch(UnitFrameBar(_G[name]))
    end
    -- Party frames on newer clients live in a pool under PartyFrame.
    local party = _G.PartyFrame
    if party then
        for _, child in ipairs({ party:GetChildren() }) do Watch(UnitFrameBar(child)) end
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function() if M.active then WatchUnitFrames() end end)

function M:Enable()
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UNIT_PET" }) do
        events:RegisterEvent(event)
    end
    if not raidHooked and CompactUnitFrame_UpdateHealthColor then
        raidHooked = true
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
            if M.active and ns.db.modules.HealthBars.raidFrames and frame and frame.healthBar then
                Watch(frame.healthBar)
            end
        end)
    end
end

function M:Apply()
    WatchUnitFrames()
    for bar in pairs(bars) do Paint(bar) end
end

function M:Disable()
    events:UnregisterAllEvents()
    for bar in pairs(bars) do Paint(bar) end
end

function M:Audit()
    local found = {}
    for _, name in ipairs(UNIT_FRAMES) do
        if UnitFrameBar(_G[name]) then found[#found + 1] = name end
    end
    local count = 0
    for _ in pairs(bars) do count = count + 1 end
    ns.Print(("  Health bars: %d watched; unit frames with bars: %s; raid hook %s"):format(
        count, #found > 0 and table.concat(found, ", ") or "|cffff5555none|r",
        raidHooked and "installed" or "|cffff5555missing|r"))
end
