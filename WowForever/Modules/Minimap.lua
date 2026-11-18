local _, ns = ...

local M = ns.RegisterModule("Minimap", {
    label = "Minimap border",
    defaults = { enabled = true },
})

-- Tints the round minimap border ring. (MinimapCluster.BorderTop does not
-- exist on this client per /wf audit, so the zone bar is left alone.)

local original

function M:Apply()
    local ring = MinimapCompassTexture
    if not ring then return end
    if not original then original = { ring:GetVertexColor() } end
    local c = ns.ThemeColor("minimap")
    ring:SetVertexColor(c.r, c.g, c.b, c.a or 1)
end

function M:Disable()
    if MinimapCompassTexture and original then
        MinimapCompassTexture:SetVertexColor(unpack(original))
    end
end

function M:Audit()
    ns.Print("  Minimap ring (MinimapCompassTexture): "
        .. (MinimapCompassTexture and "ok" or "|cffff5555missing|r"))
end
