local _, ns = ...

local M = ns.RegisterModule("ActionBars", {
    label = "Action bars",
    defaults = {
        enabled = true,
        borderSize = 1,
        tintBlizzardBorder = true,
        themeMacroText = true,
    },
})

-- Named action buttons on the 12.x (Dragonflight-era and later) UI.
-- Removed from the 0.1.0 list because they do not exist on this UI:
--   ShapeshiftButton1-10  (renamed StanceButton in Cataclysm)
--   BonusActionButton1-12 (merged into the main bar after Wrath)
-- Zone ability buttons have no global names; they are pooled frames under
-- ZoneAbilityFrame.SpellButtonContainer and are handled separately.
-- Run /wf audit in-game to confirm each group exists on this client.
M.BUTTON_GROUPS = {
    { prefix = "ActionButton", count = 12 },
    { prefix = "MultiBarBottomLeftButton", count = 12 },
    { prefix = "MultiBarBottomRightButton", count = 12 },
    { prefix = "MultiBarRightButton", count = 12 },
    { prefix = "MultiBarLeftButton", count = 12 },
    { prefix = "MultiBar5Button", count = 12 },
    { prefix = "MultiBar6Button", count = 12 },
    { prefix = "MultiBar7Button", count = 12 },
    { prefix = "PetActionButton", count = 10 },
    { prefix = "StanceButton", count = 10 },
    { prefix = "PossessButton", count = 2 },
    { prefix = "OverrideActionBarButton", count = 6 },
    { prefix = "ExtraActionButton", count = 1 },
}

local overlays = {}  -- button -> our BackdropTemplate outline frame
local originals = {} -- button -> Blizzard colors captured before we touched them
local hooked = {}    -- button -> true once hooksecurefunc is installed
local zoneHooked = false

local function ForEachButton(fn)
    for _, group in ipairs(M.BUTTON_GROUPS) do
        for i = 1, group.count do
            local button = _G[group.prefix .. i]
            if button then fn(button) end
        end
    end

    local container = ZoneAbilityFrame and ZoneAbilityFrame.SpellButtonContainer
    if container and container.EnumerateActive then
        for button in container:EnumerateActive() do fn(button) end
    end
end

local function GetNormal(button)
    return button.GetNormalTexture and button:GetNormalTexture()
end

local function CaptureOriginals(button)
    if originals[button] then return end
    local saved = {}
    local normal = GetNormal(button)
    if normal then saved.normal = { normal:GetVertexColor() } end
    if button.Name then saved.name = { button.Name:GetTextColor() } end
    originals[button] = saved
end

-- Color-only changes: safe to run at any time, including in combat.
function M:StyleColors(button)
    local overlay = overlays[button]
    if not overlay then return end
    local settings = ns.db.modules.ActionBars
    local theme = ns.db.theme
    local c = theme.accent

    overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)

    local saved = originals[button]
    local normal = GetNormal(button)
    if normal then
        if settings.tintBlizzardBorder then
            normal:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        elseif saved and saved.normal then
            normal:SetVertexColor(unpack(saved.normal))
        end
    end

    if button.Name then
        if settings.themeMacroText then
            local t = theme.highlight
            button.Name:SetTextColor(t.r, t.g, t.b)
        elseif saved and saved.name then
            button.Name:SetTextColor(unpack(saved.name))
        end
    end
end

-- Blizzard re-applies button art on some updates; re-tint afterwards.
local function HookButton(button)
    if hooked[button] then return end
    hooked[button] = true
    if button.UpdateButtonArt then
        hooksecurefunc(button, "UpdateButtonArt", function(self)
            if M.active then M:StyleColors(self) end
        end)
    end
end

-- Structural changes: create and anchor our overlay. Run out of combat only.
local function Layout(button, settings)
    CaptureOriginals(button)
    HookButton(button)

    local overlay = overlays[button]
    if not overlay then
        overlay = CreateFrame("Frame", nil, button, "BackdropTemplate")
        overlay:EnableMouse(false)
        overlays[button] = overlay
    end
    overlay:SetFrameLevel(button:GetFrameLevel() + 2)

    local size = settings.borderSize
    if size > 0 then
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", button, "TOPLEFT", -size, size)
        overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", size, -size)
        overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = size })
        overlay:Show()
    else
        overlay:Hide()
    end
end

function M:Enable()
    if not zoneHooked and ZoneAbilityFrame and ZoneAbilityFrame.UpdateDisplayedZoneAbilities then
        zoneHooked = true
        hooksecurefunc(ZoneAbilityFrame, "UpdateDisplayedZoneAbilities", function()
            if M.active then M:Apply(ns.db.modules.ActionBars) end
        end)
    end
end

function M:Apply(settings)
    ns.RunOutOfCombat("ActionBars.layout", function()
        ForEachButton(function(button)
            Layout(button, settings)
            M:StyleColors(button)
        end)
    end)
    -- Recolor already-built overlays right away, even if layout was queued.
    ForEachButton(function(button) M:StyleColors(button) end)
end

function M:Disable()
    for button, overlay in pairs(overlays) do
        overlay:Hide()
        local saved = originals[button]
        local normal = GetNormal(button)
        if saved and saved.normal and normal then normal:SetVertexColor(unpack(saved.normal)) end
        if saved and saved.name and button.Name then button.Name:SetTextColor(unpack(saved.name)) end
    end
end

function M:Audit()
    for _, group in ipairs(self.BUTTON_GROUPS) do
        local found, missing = 0, {}
        for i = 1, group.count do
            if _G[group.prefix .. i] then
                found = found + 1
            else
                missing[#missing + 1] = i
            end
        end
        local line = ("  %s1-%d: %d/%d found"):format(group.prefix, group.count, found, group.count)
        if #missing > 0 and found > 0 then line = line .. " (missing " .. table.concat(missing, ",") .. ")" end
        ns.Print(found == 0 and ("|cffff5555" .. line .. "|r") or line)
    end

    local function status(ok, good, bad)
        return ok and good or ("|cffff5555" .. bad .. "|r")
    end

    local container = ZoneAbilityFrame and ZoneAbilityFrame.SpellButtonContainer
    ns.Print("  ZoneAbilityFrame pool: " .. status(container and container.EnumerateActive, "ok", "missing"))
    ns.Print("  ZoneAbility hook: " .. status(zoneHooked, "installed", "not installed"))

    local sample = _G.ActionButton1
    ns.Print("  ActionButton1.UpdateButtonArt: " .. status(sample and sample.UpdateButtonArt, "ok", "missing"))
end
