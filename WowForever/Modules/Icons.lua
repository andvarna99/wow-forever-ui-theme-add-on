local _, ns = ...

local M = ns.RegisterModule("Icons", {
    label = "Chat and quest icons",
    defaults = { enabled = true, outlineChatButtons = true },
})

-- Chat side buttons and quest POI markers are single images with background,
-- glyph, and border baked together, so their parts cannot be colored
-- separately. Each texture is desaturated and tinted with theme.iconGlyph:
-- bright glyphs come out in that color and dark backgrounds come out as a
-- deep shade of it. Square chat buttons also get a theme.iconBorder outline.
-- Both keys are optional; when iconGlyph is unset, icons are left alone.

local CHAT_BUTTONS = {
    "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton",
}
local POI_ROOTS = { "ObjectiveTrackerFrame", "QuestScrollFrame" }

local outlines = {}  -- chat button -> outline frame
local poiButtons = {} -- quest POI button -> true
local styleHooked = {}
local scanPending = false

local function GlyphColor()
    return M.active and ns.db.theme.iconGlyph or nil
end

local function StyleChatButton(button)
    ns.TintFrameTextures(button, GlyphColor(), 2)

    local border = ns.db.theme.iconBorder
    local show = M.active and GlyphColor() and border and ns.db.modules.Icons.outlineChatButtons
    local outline = outlines[button]
    if show and not outline then
        outline = CreateFrame("Frame", nil, button, "BackdropTemplate")
        outline:EnableMouse(false)
        outline:SetPoint("TOPLEFT", -1, 1)
        outline:SetPoint("BOTTOMRIGHT", 1, -1)
        outline:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        outlines[button] = outline
    end
    if outline then
        if show then
            outline:SetBackdropBorderColor(border.r, border.g, border.b, border.a or 1)
            outline:Show()
        else
            outline:Hide()
        end
    end
end

local function StylePOI(button)
    ns.TintFrameTextures(button, GlyphColor(), 2)
end

-- Quest POI buttons expose GetQuestID. Protected frames (such as secure quest
-- item buttons) are skipped.
local function FindPOIs(frame, depth)
    if depth > 12 then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.GetQuestID and child:IsObjectType("Button") and not child:IsProtected() then
            if not poiButtons[child] then
                poiButtons[child] = true
                if child.UpdateButtonStyle and not styleHooked[child] then
                    styleHooked[child] = true
                    hooksecurefunc(child, "UpdateButtonStyle", StylePOI)
                end
            end
            StylePOI(child)
        else
            FindPOIs(child, depth + 1)
        end
    end
end

local function Scan()
    scanPending = false
    if not M.active then return end
    for _, name in ipairs(POI_ROOTS) do
        local root = _G[name]
        if root then FindPOIs(root, 0) end
    end
end

local function RequestScan()
    if scanPending then return end
    scanPending = true
    C_Timer.After(0.1, Scan)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", RequestScan)
local EVENTS = {
    "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED",
}

function M:Enable()
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
end

function M:Apply()
    for _, name in ipairs(CHAT_BUTTONS) do
        local button = _G[name]
        if button then StyleChatButton(button) end
    end
    Scan()
    for button in pairs(poiButtons) do StylePOI(button) end
end

function M:Disable()
    events:UnregisterAllEvents()
    for _, name in ipairs(CHAT_BUTTONS) do
        local button = _G[name]
        if button then StyleChatButton(button) end
    end
    for button in pairs(poiButtons) do StylePOI(button) end
end

function M:Audit()
    local parts = {}
    for _, name in ipairs(CHAT_BUTTONS) do
        parts[#parts + 1] = name .. (_G[name] and " ok" or " |cffff5555missing|r")
    end
    local pois = 0
    for _ in pairs(poiButtons) do pois = pois + 1 end
    ns.Print("  Chat icons: " .. table.concat(parts, ", "))
    ns.Print(("  Quest POI icons styled: %d"):format(pois))
end
