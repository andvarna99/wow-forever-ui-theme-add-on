local _, ns = ...

local M = ns.RegisterModule("ObjectiveTracker", {
    label = "Objective tracker",
    defaults = { enabled = true, themeText = true, tintHeaders = true },
})

-- Blizzard colors tracker text explicitly, so font objects cannot reach it.
-- Text is recolored through ns.Recolor: quest difficulty colors map to the
-- theme's difficulty colors, tracker header/normal colors map to theme text.
-- Tracker lines are pooled and created on demand, so the tracker is rescanned
-- (debounced) whenever quest or tracking state changes.

local headerColors = {} -- header frame -> original background vertex color
local scanPending = false
local updateHooked = false

local function Mapper(r, g, b)
    if not (M.active and ns.db.modules.ObjectiveTracker.themeText) then return nil end
    local difficulty = ns.MapDifficultyColor(r, g, b)
    if difficulty then return difficulty end

    local colors = OBJECTIVE_TRACKER_COLOR
    if not colors then return nil end
    local theme = ns.db.theme
    if ns.NearColor(r, g, b, colors.Header) then return theme.text end
    if ns.NearColor(r, g, b, colors.HeaderHighlight) then return ns.Lighten(theme.text, 0.35) end
    if ns.NearColor(r, g, b, colors.Normal) then return theme.highlight end
    return nil
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

local function TintHeaders(frame, depth)
    if depth > 10 then return end
    if frame.Header then TintHeader(frame.Header) end
    for _, child in ipairs({ frame:GetChildren() }) do TintHeaders(child, depth + 1) end
end

local function ScanTracker()
    scanPending = false
    if not (M.active and ObjectiveTrackerFrame) then return end
    ns.Recolor.WatchTree(ObjectiveTrackerFrame, Mapper)
    TintHeaders(ObjectiveTrackerFrame, 0)
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
    ns.Recolor.Repaint(Mapper)
    for header in pairs(headerColors) do TintHeader(header) end
end

function M:Disable()
    events:UnregisterAllEvents()
    ns.Recolor.Repaint(Mapper)
    for header in pairs(headerColors) do TintHeader(header) end
end

function M:Audit()
    local headers = 0
    for _ in pairs(headerColors) do headers = headers + 1 end
    ns.Print(("  Objective tracker: %d text lines hooked, %d headers, Update hook %s, colors %s"):format(
        ns.Recolor.Count(Mapper), headers,
        updateHooked and "installed" or "|cffff5555missing|r",
        OBJECTIVE_TRACKER_COLOR and "ok" or "|cffff5555missing|r"))
end
