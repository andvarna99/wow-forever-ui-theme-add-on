local _, ns = ...

local M = ns.RegisterModule("ObjectiveTracker", {
    label = "Objective tracker",
    defaults = { enabled = true, themeText = true, tintHeaders = true },
})

-- Blizzard colors tracker text explicitly from OBJECTIVE_TRACKER_COLOR, so
-- font objects cannot reach it, and that table must not be modified. Instead,
-- each tracker FontString gets a hooksecurefunc on SetTextColor: when Blizzard
-- sets a known tracker color, it is swapped for the matching theme color.
-- Tracker lines are pooled and created on demand, so the tracker is rescanned
-- (debounced) whenever quest or tracking state changes.

local blizzardColors = {} -- FontString -> last {r, g, b, a} Blizzard set
local headerColors = {}   -- header background texture -> original vertex color
local recoloring = false
local scanPending = false
local updateHooked = false

local function Near(r, g, b, color)
    return color and math.abs(r - color.r) < 0.01 and math.abs(g - color.g) < 0.01
        and math.abs(b - color.b) < 0.01
end

-- Maps a Blizzard tracker color to a theme color, or nil to leave it alone.
local function MapColor(r, g, b)
    local colors = OBJECTIVE_TRACKER_COLOR
    if not colors then return nil end
    local theme = ns.db.theme
    if Near(r, g, b, colors.Header) then return theme.text end
    if Near(r, g, b, colors.HeaderHighlight) then return ns.Lighten(theme.text, 0.35) end
    if Near(r, g, b, colors.Normal) then return theme.highlight end
    return nil
end

local function Paint(fontString)
    local col = blizzardColors[fontString]
    if not col then return end
    local themed = M.active and ns.db.modules.ObjectiveTracker.themeText and MapColor(col[1], col[2], col[3])
    recoloring = true
    if themed then
        fontString:SetTextColor(themed.r, themed.g, themed.b, col[4] or 1)
    else
        fontString:SetTextColor(col[1], col[2], col[3], col[4] or 1)
    end
    recoloring = false
end

local function OnSetTextColor(fontString, r, g, b, a)
    if recoloring then return end
    blizzardColors[fontString] = { r, g, b, a }
    if M.active then Paint(fontString) end
end

local function TintHeader(header)
    local bg = header and header.Background
    if not (bg and bg.SetVertexColor) then return end
    if not headerColors[header] then headerColors[header] = { bg:GetVertexColor() } end
    if M.active and ns.db.modules.ObjectiveTracker.tintHeaders then
        local c = ns.ThemeColor("tracker")
        bg:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    else
        bg:SetVertexColor(unpack(headerColors[header]))
    end
end

local function Scan(frame, depth)
    if depth > 10 then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "FontString" and not blizzardColors[region] then
            hooksecurefunc(region, "SetTextColor", OnSetTextColor)
            OnSetTextColor(region, region:GetTextColor())
        end
    end
    if frame.Header then TintHeader(frame.Header) end
    for _, child in ipairs({ frame:GetChildren() }) do
        Scan(child, depth + 1)
    end
end

local function ScanTracker()
    scanPending = false
    if M.active and ObjectiveTrackerFrame then Scan(ObjectiveTrackerFrame, 0) end
end

local function RequestScan()
    if scanPending then return end
    scanPending = true
    C_Timer.After(0.1, ScanTracker)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", RequestScan)
local EVENTS = {
    "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED",
    "TRACKED_ACHIEVEMENT_UPDATE", "SUPER_TRACKING_CHANGED", "SCENARIO_UPDATE",
}

function M:Enable()
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
    if not updateHooked and ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
        updateHooked = true
        hooksecurefunc(ObjectiveTrackerFrame, "Update", function()
            if M.active then RequestScan() end
        end)
    end
end

function M:Apply()
    ScanTracker()
    for fontString in pairs(blizzardColors) do Paint(fontString) end
    for header in pairs(headerColors) do TintHeader(header) end
end

function M:Disable()
    events:UnregisterAllEvents()
    for fontString in pairs(blizzardColors) do Paint(fontString) end
    for header in pairs(headerColors) do TintHeader(header) end
end

function M:Audit()
    local strings, headers = 0, 0
    for _ in pairs(blizzardColors) do strings = strings + 1 end
    for _ in pairs(headerColors) do headers = headers + 1 end
    ns.Print(("  Objective tracker: %d text lines hooked, %d headers, Update hook %s, colors %s"):format(
        strings, headers,
        updateHooked and "installed" or "|cffff5555missing|r",
        OBJECTIVE_TRACKER_COLOR and "ok" or "|cffff5555missing|r"))
end
