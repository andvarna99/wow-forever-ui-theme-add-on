local _, ns = ...

local M = ns.RegisterModule("QuestLog", {
    label = "Quest log difficulty colors",
    defaults = { enabled = true },
})

-- Recolors quest titles that Blizzard colors by difficulty (trivial, easy,
-- on-level, hard, very hard) to the theme's difficulty colors. Supports both
-- the map-attached quest log and the standalone quest log frame, whichever
-- this client has. Quest log rows are pooled, so the log is rescanned
-- (debounced) when it is shown and when the quest log updates.

local ROOTS = { "QuestScrollFrame", "QuestMapFrame", "QuestLogFrame" }

local scanPending = false
local shownHooked = {}

local function Mapper(r, g, b)
    if not M.active then return nil end
    return ns.MapDifficultyColor(r, g, b)
end

local function ScanLog()
    scanPending = false
    if not M.active then return end
    for _, name in ipairs(ROOTS) do
        local root = _G[name]
        if root and root:IsShown() then ns.Recolor.WatchTree(root, Mapper, 12) end
    end
end

local function RequestScan()
    if scanPending then return end
    scanPending = true
    C_Timer.After(0.05, ScanLog)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", RequestScan)

function M:Enable()
    events:RegisterEvent("QUEST_LOG_UPDATE")
    for _, name in ipairs(ROOTS) do
        local root = _G[name]
        if root and not shownHooked[name] then
            shownHooked[name] = true
            root:HookScript("OnShow", function()
                if M.active then RequestScan() end
            end)
        end
    end
end

function M:Apply()
    ScanLog()
    ns.Recolor.Repaint(Mapper)
end

function M:Disable()
    events:UnregisterAllEvents()
    ns.Recolor.Repaint(Mapper)
end

function M:Audit()
    local parts = {}
    for _, name in ipairs(ROOTS) do
        parts[#parts + 1] = name .. (_G[name] and " ok" or " -")
    end
    ns.Print(("  Quest log: %s; difficulty colors %s; %d text lines hooked"):format(
        table.concat(parts, ", "),
        QuestDifficultyColors and "ok" or "|cffff5555missing|r",
        ns.Recolor.Count(Mapper)))
end
