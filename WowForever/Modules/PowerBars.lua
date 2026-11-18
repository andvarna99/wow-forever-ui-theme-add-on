local _, ns = ...

local M = ns.RegisterModule("PowerBars", {
    label = "Power bars (mana, rage, energy)",
    defaults = { enabled = true, raidFrames = true },
})

-- Recolors mana, rage, and energy bars with theme.power. Blizzard's bar art
-- is dark once desaturated, which turns pastel tints grey, so themed bars use
-- the plain status bar texture with the theme color instead. Blizzard's own
-- texture and color are remembered and restored when a bar shows another
-- power type or the module is turned off.
-- Bars are only recolored; power values are never read.

local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- Enum.PowerType values: 0 = Mana, 1 = Rage, 3 = Energy.
local THEMED_POWER = { [0] = true, [1] = true, [3] = true }

local UNIT_FRAMES = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "TargetFrameToT", "FocusFrameToT",
    "Boss1TargetFrame", "Boss2TargetFrame", "Boss3TargetFrame", "Boss4TargetFrame", "Boss5TargetFrame",
}

-- Standalone bars that always show mana (druid forms, shadow priests, etc.).
local MANA_BARS = { "PlayerFrameAlternateManaBar", "AlternatePowerBar" }

local bars = {}   -- StatusBar -> { texture = atlas/file, color = {r, g, b, a}, alwaysMana = bool }
local themed = {} -- StatusBar -> true while showing the theme look
local busy = false
local raidHooked = false

local function PowerType(bar)
    if bars[bar].alwaysMana then return 0 end
    if bar.powerType ~= nil then return bar.powerType end
    local unit = bar.unit or (bar:GetParent() and bar:GetParent().unit)
    if unit and UnitPowerType then return (UnitPowerType(unit)) end
    return nil
end

local function Paint(bar)
    local info = bars[bar]
    local c = M.active and ns.db.theme.power
    busy = true
    if c and THEMED_POWER[PowerType(bar)] then
        bar:SetStatusBarTexture(BAR_TEXTURE)
        bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        themed[bar] = true
    elseif themed[bar] then
        if info.texture then bar:SetStatusBarTexture(info.texture) end
        bar:SetStatusBarColor(unpack(info.color))
        themed[bar] = nil
    end
    busy = false
end

local function Watch(bar, alwaysMana)
    if not (bar and bar.GetStatusBarTexture) then return end
    if bars[bar] then
        Paint(bar)
        return
    end
    local tex = bar:GetStatusBarTexture()
    bars[bar] = {
        texture = tex and (tex:GetAtlas() or tex:GetTexture()),
        color = { bar:GetStatusBarColor() },
        alwaysMana = alwaysMana or false,
    }
    hooksecurefunc(bar, "SetStatusBarColor", function(self, r, g, b, a)
        if busy then return end
        bars[self].color = { r, g, b, a }
        themed[self] = nil
        Paint(self)
    end)
    hooksecurefunc(bar, "SetStatusBarTexture", function(self, asset)
        if busy then return end
        bars[self].texture = asset
        themed[self] = nil
        Paint(self)
    end)
    Paint(bar)
end

local function UnitFrameBar(frame)
    return frame and (frame.manabar or frame.ManaBar or frame.PowerBar)
end

local function WatchUnitFrames()
    for _, name in ipairs(UNIT_FRAMES) do
        Watch(UnitFrameBar(_G[name]))
    end
    for _, name in ipairs(MANA_BARS) do
        Watch(_G[name], true)
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
    if not raidHooked and CompactUnitFrame_UpdatePowerColor then
        raidHooked = true
        hooksecurefunc("CompactUnitFrame_UpdatePowerColor", function(frame)
            if M.active and ns.db.modules.PowerBars.raidFrames and frame and frame.powerBar then
                Watch(frame.powerBar)
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
    for _, name in ipairs(MANA_BARS) do
        if _G[name] then found[#found + 1] = name end
    end
    local count, painted = 0, 0
    for bar in pairs(bars) do
        count = count + 1
        if themed[bar] then painted = painted + 1 end
    end
    ns.Print(("  Power bars: %d watched, %d themed now; frames: %s; raid hook %s"):format(
        count, painted, #found > 0 and table.concat(found, ", ") or "|cffff5555none|r",
        raidHooked and "installed" or "|cffff5555missing|r"))
end
