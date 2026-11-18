local _, ns = ...

-- Placeholder modules. Each lists the Blizzard frames, regions, and globals it
-- would theme so /wf audit can confirm they exist before any work starts.
-- Dotted paths ("WorldMapFrame.BorderFrame") walk child keys from a global.
local STUBS = {
    {
        name = "WorldMap",
        label = "World map",
        probes = { "WorldMapFrame", "WorldMapFrame.BorderFrame", "WorldMapFrame.BorderFrame.NineSlice" },
    },
    {
        name = "Bags",
        label = "Bags",
        probes = {
            "ContainerFrameCombinedBags", "ContainerFrameCombinedBags.NineSlice",
            "ContainerFrame1", "BagsBar",
        },
    },
}

local function Resolve(path)
    local node
    for part in path:gmatch("[^%.]+") do
        if node == nil then
            node = _G[part]
        elseif type(node) == "table" then
            node = node[part]
        else
            return nil
        end
        if node == nil then return nil end
    end
    return node
end

for _, info in ipairs(STUBS) do
    local M = ns.RegisterModule(info.name, {
        label = info.label,
        stub = true,
        probes = info.probes,
    })

    function M:Enable() end
    function M:Apply() end
    function M:Disable() end

    function M:Audit()
        local found, missing = {}, {}
        for _, path in ipairs(self.probes) do
            if Resolve(path) ~= nil then
                found[#found + 1] = path
            else
                missing[#missing + 1] = path
            end
        end
        ns.Print(("  [stub] %s: %d/%d found"):format(self.label, #found, #self.probes))
        if #missing > 0 then
            ns.Print("    |cffff5555missing: " .. table.concat(missing, ", ") .. "|r")
        end
    end
end
