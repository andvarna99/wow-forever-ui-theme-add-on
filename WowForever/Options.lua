local _, ns = ...

local frame
local swatches = {}
local moduleChecks = {}
local settingChecks = {}

local function CreateSwatch(parent, label, key, hasAlpha, y)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(20, 20)
    button:SetPoint("TOPLEFT", 20, y)

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
    local rowCount = #ns.moduleOrder
    local modulesHeight = 26 * rowCount

    frame = CreateFrame("Frame", "WowForeverOptions", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(320, 420 + modulesHeight)
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
    CreateSwatch(frame, "Accent / outlines", "accent", true, y - 22)
    CreateSwatch(frame, "Primary text (gold)", "text", false, y - 48)
    CreateSwatch(frame, "Secondary text (white)", "highlight", false, y - 74)

    y = y - 110
    CreateHeader(frame, "Modules", y)
    for i, name in ipairs(ns.moduleOrder) do
        local module = ns.modules[name]
        local label = module.stub and (module.label .. " (coming soon)") or module.label
        local check = CreateCheck(frame, label, 16, y - 18 - (i - 1) * 26, function(self)
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

    local sizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", 20, y - 80)
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

    y = y - 112
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
        local c = ns.db.theme[key]
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
