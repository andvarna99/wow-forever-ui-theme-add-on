local _, ns = ...

local M = ns.RegisterModule("ActionBars", {
    label = "Action bars",
    defaults = {
        enabled = true,
        borderSize = 1,
        tintBlizzardBorder = true,
        themeMacroText = true,
        tintHighlights = true,
    },
})

-- Named action buttons on the 12.x (Dragonflight-era and later) UI.
-- Removed from the 0.1.0 list because they do not exist on this UI:
--   ShapeshiftButton1-10  (renamed StanceButton in Cataclysm)
--   BonusActionButton1-12 (merged into the main bar after Wrath)
-- Zone ability buttons have no global names; they are pooled frames under
-- ZoneAbilityFrame.SpellButtonContainer and are handled separately.
-- Verified in-game with /wf audit on WoW: Forever 1.60.1 (Interface 16001):
-- every prefix group below was found in full, along with the
-- ZoneAbilityFrame pool and ActionButton:UpdateButtonArt.
--
-- "color" names a theme key (see ns.ThemeColor); groups without one use the
-- theme accent. Edit Mode numbering: bar 1 = ActionButton, 2 = BottomLeft,
-- 3 = BottomRight, 4 = Right, 5 = Left, 6-8 = MultiBar5-7.
-- Groups may list explicit frame names instead of prefix + count.
M.BUTTON_GROUPS = {
    { prefix = "ActionButton", count = 12, color = "bars123" },
    { prefix = "MultiBarBottomLeftButton", count = 12, color = "bars123" },
    { prefix = "MultiBarBottomRightButton", count = 12, color = "bars123" },
    { prefix = "MultiBarRightButton", count = 12, color = "bars45" },
    { prefix = "MultiBarLeftButton", count = 12, color = "bars45" },
    { prefix = "MultiBar5Button", count = 12, color = "bars67" },
    { prefix = "MultiBar6Button", count = 12, color = "bars67" },
    { prefix = "MultiBar7Button", count = 12 },
    { prefix = "PetActionButton", count = 10 },
    { prefix = "StanceButton", count = 10 },
    { prefix = "PossessButton", count = 2 },
    { prefix = "OverrideActionBarButton", count = 6 },
    { prefix = "ExtraActionButton", count = 1 },
    {
        label = "Bag bar",
        names = {
            "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
            "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot",
        },
    },
}

local overlays = {}  -- button -> our BackdropTemplate outline frame
local originals = {} -- button -> Blizzard colors captured before we touched them
local hooked = {}    -- button -> true once hooksecurefunc is installed
local colorKeys = {} -- button -> theme key for its outline color
local zoneHooked = false

local function ForEachInGroup(group, fn)
    if group.names then
        for _, frameName in ipairs(group.names) do
            local button = _G[frameName]
            if button then fn(button) end
        end
    else
        for i = 1, group.count do
            local button = _G[group.prefix .. i]
            if button then fn(button) end
        end
    end
end

local function ForEachButton(fn)
    for _, group in ipairs(M.BUTTON_GROUPS) do
        ForEachInGroup(group, function(button)
            colorKeys[button] = group.color
            fn(button)
        end)
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

---------------------------------------------------------------------------
-- Highlight and glow textures (hover, checked, proc alerts, flyout arrows)
---------------------------------------------------------------------------

local texOriginals = {} -- texture -> { color = {r, g, b, a}, desaturated = bool }
local alertHook         -- name of the proc-glow function hooked, if any

-- Tints a texture to color c, or restores Blizzard's look when c is nil.
local function TintTexture(tex, c)
    if not (tex and tex.SetVertexColor) then return end
    if not texOriginals[tex] then
        texOriginals[tex] = {
            color = { tex:GetVertexColor() },
            desaturated = tex.IsDesaturated and tex:IsDesaturated() or false,
        }
    end
    local saved = texOriginals[tex]
    if c then
        -- Desaturate first so the theme color replaces Blizzard's yellow
        -- instead of multiplying with it (yellow x pink comes out orange).
        if tex.SetDesaturated then tex:SetDesaturated(true) end
        tex:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    else
        if tex.SetDesaturated then tex:SetDesaturated(saved.desaturated) end
        tex:SetVertexColor(unpack(saved.color))
    end
end

local function TintFrameTextures(frame, c, depth)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "Texture" then TintTexture(region, c) end
    end
    if depth < 2 then
        for _, child in ipairs({ frame:GetChildren() }) do TintFrameTextures(child, c, depth + 1) end
    end
end

local function GlowsOn()
    return M.active and ns.db.modules.ActionBars.tintHighlights
end

-- Proc glow ("spell activation alert") shown on a button.
local function TintAlert(button)
    local alert = button and (button.SpellActivationAlert or button.overlay)
    if alert then TintFrameTextures(alert, GlowsOn() and ns.ThemeColor("glow") or nil, 0) end
end

local function TintHighlights(button)
    local on = GlowsOn()
    local hover = on and ns.ThemeColor("hover") or nil
    local glow = on and ns.ThemeColor("glow") or nil

    TintTexture(button.GetHighlightTexture and button:GetHighlightTexture(), hover)
    TintTexture(button.GetCheckedTexture and button:GetCheckedTexture(), glow)
    TintTexture(button.SpellHighlightTexture, glow)
    TintTexture(button.NewActionTexture, glow)
    if button.FlyoutArrowContainer then TintFrameTextures(button.FlyoutArrowContainer, glow, 0) end
    TintAlert(button)
end

---------------------------------------------------------------------------

-- Color-only changes: safe to run at any time, including in combat.
function M:StyleColors(button)
    local overlay = overlays[button]
    if not overlay then return end
    local settings = ns.db.modules.ActionBars
    local theme = ns.db.theme
    local c = ns.ThemeColor(colorKeys[button])

    TintHighlights(button)

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
    if not alertHook then
        if ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.ShowAlert then
            alertHook = "ActionButtonSpellAlertManager:ShowAlert"
            hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button) TintAlert(button) end)
        elseif ActionButton_ShowOverlayGlow then
            alertHook = "ActionButton_ShowOverlayGlow"
            hooksecurefunc("ActionButton_ShowOverlayGlow", TintAlert)
        end
    end

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
    for tex in pairs(texOriginals) do TintTexture(tex, nil) end
end

function M:Audit()
    for _, group in ipairs(self.BUTTON_GROUPS) do
        local found, missing = 0, {}
        local total, label
        if group.names then
            total, label = #group.names, group.label
            for _, frameName in ipairs(group.names) do
                if _G[frameName] then found = found + 1 else missing[#missing + 1] = frameName end
            end
        else
            total, label = group.count, ("%s1-%d"):format(group.prefix, group.count)
            for i = 1, group.count do
                if _G[group.prefix .. i] then found = found + 1 else missing[#missing + 1] = i end
            end
        end
        local line = ("  %s: %d/%d found"):format(label, found, total)
        if #missing > 0 and found > 0 then line = line .. " (missing " .. table.concat(missing, ",") .. ")" end
        ns.Print(found == 0 and ("|cffff5555" .. line .. "|r") or line)
    end

    local function status(ok, good, bad)
        return ok and good or ("|cffff5555" .. bad .. "|r")
    end

    local container = ZoneAbilityFrame and ZoneAbilityFrame.SpellButtonContainer
    ns.Print("  ZoneAbilityFrame pool: " .. status(container and container.EnumerateActive, "ok", "missing"))
    ns.Print("  ZoneAbility hook: " .. status(zoneHooked, "installed", "not installed"))
    ns.Print("  Proc glow hook: " .. status(alertHook, alertHook, "not installed"))

    local sample = _G.ActionButton1
    ns.Print("  ActionButton1.UpdateButtonArt: " .. status(sample and sample.UpdateButtonArt, "ok", "missing"))
end
