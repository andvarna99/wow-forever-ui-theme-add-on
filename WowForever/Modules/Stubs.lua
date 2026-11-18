local _, ns = ...

-- Placeholder modules. Each lists the Blizzard frames it will theme so that
-- /wf audit can confirm they exist before any work starts.
local STUBS = {
    { name = "ObjectiveTracker", label = "Objective tracker", frames = { "ObjectiveTrackerFrame" } },
    { name = "Minimap", label = "Minimap", frames = { "MinimapCluster", "Minimap" } },
    { name = "WorldMap", label = "World map", frames = { "WorldMapFrame" } },
    { name = "Bags", label = "Bags", frames = { "ContainerFrameCombinedBags", "ContainerFrame1" } },
    { name = "Chat", label = "Chat", frames = { "ChatFrame1", "GeneralDockManager" } },
}

for _, info in ipairs(STUBS) do
    local M = ns.RegisterModule(info.name, {
        label = info.label,
        stub = true,
        frames = info.frames,
    })

    function M:Enable() end
    function M:Apply() end
    function M:Disable() end

    function M:Audit()
        local parts = {}
        for _, frameName in ipairs(self.frames) do
            parts[#parts + 1] = frameName .. (_G[frameName] and " ok" or " |cffff5555missing|r")
        end
        ns.Print(("  [stub] %s: %s"):format(self.label, table.concat(parts, ", ")))
    end
end
