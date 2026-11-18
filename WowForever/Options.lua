local _, ns = ...

local frame
local swatches = {}
local moduleChecks = {}
local settingChecks = {}

local function CreateSwatch(parent, label, key, hasAlpha, x, y)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(20, 20)
    button:SetPoint("TOPLEFT", x, y)

    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.6, 0.6, 0.6, 1)

    local fill = button:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    button.fill = fill

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", button, "RIGHT", 8, 0)
    text:SetText(label)

    button:SetScript("OnClick", function()
        -- Optional keys start as a copy of the accent until customized.
        if not ns.db.theme[key] then ns.db.theme[key] = ns.CopyColor(ns.ThemeColor(key)) end
        ns.OpenColorPicker(ns.db.theme[key], hasAlpha, function() ns.ApplyAll() end)
    end)

    swatches[key] = button
end

local function CreateCheck(parent, label, x, y, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", x, y)
    local text = check.Text or check.text
    if not text then
        text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 4, 0)
        check.Text = text
    end
    text:SetText(label)
    check:SetScript("OnClick", onClick)
    return check
end

local function CreateHeader(parent, label, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetText(label)
end

local function CreateOptions()
    local rowCount = math.ceil(#ns.moduleOrder / 2) -- modules are listed in two columns
    local modulesHeight = 26 * rowCount

    frame = CreateFrame("Frame", "WowForeverOptions", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(680, 550 + modulesHeight)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "WowForeverOptions") -- close with Escape

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("WowForever Theme")

    local y = -36
    CreateHeader(frame, "Theme colors", y)
    -- Columns: action bars | other frames and text | quest difficulty and health.
    CreateSwatch(frame, "Accent (other bars, bags)", "accent", true, 20, y - 22)
    CreateSwatch(frame, "Action bars 1-3", "bars123", true, 20, y - 48)
    CreateSwatch(frame, "Action bars 4-5", "bars45", true, 20, y - 74)
    CreateSwatch(frame, "Action bars 6-7", "bars67", true, 20, y - 100)
    CreateSwatch(frame, "Button hover", "hover", true, 20, y - 126)
    CreateSwatch(frame, "Glows (was yellow)", "glow", true, 20, y - 152)
    CreateSwatch(frame, "Chat border", "chat", true, 240, y - 22)
    CreateSwatch(frame, "Minimap border", "minimap", true, 240, y - 48)
    CreateSwatch(frame, "Tracker headers", "tracker", true, 240, y - 74)
    CreateSwatch(frame, "Primary text (gold)", "text", false, 240, y - 100)
    CreateSwatch(frame, "Secondary text (white)", "highlight", false, 240, y - 126)
    CreateSwatch(frame, "Icons (glyph)", "iconGlyph", true, 240, y - 152)
    CreateSwatch(frame, "Icon border", "iconBorder", true, 240, y - 178)
    CreateSwatch(frame, "Quest: trivial", "diffTrivial", false, 460, y - 22)
    CreateSwatch(frame, "Quest: easy", "diffEasy", false, 460, y - 48)
    CreateSwatch(frame, "Quest: on-level", "diffStandard", false, 460, y - 74)
    CreateSwatch(frame, "Quest: hard", "diffHard", false, 460, y - 100)
    CreateSwatch(frame, "Quest: very hard", "diffVeryHard", false, 460, y - 126)
    CreateSwatch(frame, "Health bars", "health", true, 460, y - 152)

    y = y - 214
    CreateHeader(frame, "Modules", y)
    for i, name in ipairs(ns.moduleOrder) do
        local module = ns.modules[name]
        local label = module.stub and (module.label .. " (coming soon)") or module.label
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local check = CreateCheck(frame, label, 16 + col * 330, y - 18 - row * 26, function(self)
            ns.SetModuleEnabled(name, self:GetChecked())
        end)
        if module.stub then
            check:Disable()
            check.Text:SetFontObject("GameFontDisable")
        end
        moduleChecks[name] = check
    end

    y = y - 30 - modulesHeight
    CreateHeader(frame, "Action bars", y)
    settingChecks.tintBlizzardBorder = CreateCheck(frame, "Tint Blizzard button frames", 16, y - 18, function(self)
        ns.db.modules.ActionBars.tintBlizzardBorder = self:GetChecked() and true or false
        ns.ApplyAll()
    end)
    settingChecks.themeMacroText = CreateCheck(frame, "Theme macro names", 16, y - 44, function(self)
        ns.db.modules.ActionBars.themeMacroText = self:GetChecked() and true or false
        ns.ApplyAll()
    end)
    settingChecks.tintHighlights = CreateCheck(frame, "Theme hover and glows", 16, y - 70, function(self)
        ns.db.modules.ActionBars.tintHighlights = self:GetChecked() and true or false
        ns.ApplyAll()
    end)

    local sizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", 20, y - 106)
    frame.sizeLabel = sizeLabel

    local function StepBorder(delta)
        local bars = ns.db.modules.ActionBars
        bars.borderSize = math.max(0, math.min(4, bars.borderSize + delta))
        ns.ApplyAll()
    end

    local minus = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    minus:SetSize(24, 20)
    minus:SetPoint("LEFT", sizeLabel, "RIGHT", 10, 0)
    minus:SetText("-")
    minus:SetScript("OnClick", function() StepBorder(-1) end)

    local plus = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    plus:SetSize(24, 20)
    plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    plus:SetText("+")
    plus:SetScript("OnClick", function() StepBorder(1) end)

    y = y - 138
    CreateHeader(frame, "Presets", y)
    for i, name in ipairs(ns.presetOrder) do
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(90, 22)
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        b:SetPoint("TOPLEFT", 16 + col * 96, y - 20 - row * 26)
        b:SetText(name)
        b:SetScript("OnClick", function() ns.ApplyPreset(name) end)
    end
end

function ns.RefreshOptions()
    if not frame then return end
    for key, swatch in pairs(swatches) do
        local c = ns.ThemeColor(key)
        swatch.fill:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    end
    for name, check in pairs(moduleChecks) do
        check:SetChecked(ns.db.modules[name].enabled)
    end
    local bars = ns.db.modules.ActionBars
    for key, check in pairs(settingChecks) do
        check:SetChecked(bars[key])
    end
    frame.sizeLabel:SetText("Outline thickness: " .. bars.borderSize)
end

function ns.ToggleOptions()
    if not frame then CreateOptions() end
    if frame:IsShown() then
        frame:Hide()
    else
        ns.RefreshOptions()
        frame:Show()
    end
end
