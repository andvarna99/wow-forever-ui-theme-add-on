local _, ns = ...

-- Shared FontString recoloring.
--
-- Blizzard often colors text explicitly (SetTextColor with values from tables
-- such as QuestDifficultyColors or OBJECTIVE_TRACKER_COLOR). Those tables must
-- not be modified, so instead each watched FontString gets a hooksecurefunc on
-- SetTextColor. Every time Blizzard sets a color, a mapper function decides
-- whether to swap it for a theme color. The last Blizzard color is remembered
-- so it can be restored when a module is turned off.

local R = {}
ns.Recolor = R

local blizzardColors = {} -- FontString -> last {r, g, b, a} Blizzard set
local mappers = {}        -- FontString -> function(r, g, b) -> color or nil
local busy = false

local function Paint(fontString)
    local col = blizzardColors[fontString]
    if not col then return end
    local themed = mappers[fontString](col[1], col[2], col[3])
    busy = true
    if themed then
        fontString:SetTextColor(themed.r, themed.g, themed.b, col[4] or 1)
    else
        fontString:SetTextColor(col[1], col[2], col[3], col[4] or 1)
    end
    busy = false
end

local function OnSetTextColor(fontString, r, g, b, a)
    if busy then return end
    blizzardColors[fontString] = { r, g, b, a }
    Paint(fontString)
end

-- Starts (or retargets) recoloring of one FontString.
function R.Watch(fontString, mapper)
    if mappers[fontString] then
        mappers[fontString] = mapper
        return
    end
    mappers[fontString] = mapper
    hooksecurefunc(fontString, "SetTextColor", OnSetTextColor)
    OnSetTextColor(fontString, fontString:GetTextColor())
end

-- Watches every FontString under frame, up to maxDepth levels of children.
function R.WatchTree(frame, mapper, maxDepth, depth)
    depth = depth or 0
    if not frame or depth > (maxDepth or 10) then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "FontString" and mappers[region] ~= mapper then
            R.Watch(region, mapper)
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        R.WatchTree(child, mapper, maxDepth, depth + 1)
    end
end

-- Re-applies the mapper to every FontString it watches (after theme changes).
function R.Repaint(mapper)
    for fontString, m in pairs(mappers) do
        if m == mapper then Paint(fontString) end
    end
end

function R.Count(mapper)
    local n = 0
    for _, m in pairs(mappers) do
        if m == mapper then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Shared texture tinting
---------------------------------------------------------------------------

local texOriginals = {} -- texture -> { color = {r, g, b, a}, desaturated = bool }

-- Tints a texture to color c, or restores Blizzard's look when c is nil.
-- Desaturates first so the tint replaces the original hue instead of
-- multiplying with it.
function ns.TintTexture(tex, c)
    if not (tex and tex.SetVertexColor) then return end
    if not texOriginals[tex] then
        texOriginals[tex] = {
            color = { tex:GetVertexColor() },
            desaturated = tex.IsDesaturated and tex:IsDesaturated() or false,
        }
    end
    local saved = texOriginals[tex]
    if c then
        if tex.SetDesaturated then tex:SetDesaturated(true) end
        tex:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    else
        if tex.SetDesaturated then tex:SetDesaturated(saved.desaturated) end
        tex:SetVertexColor(unpack(saved.color))
    end
end

-- Tints every texture in frame and its children (up to maxDepth levels).
function ns.TintFrameTextures(frame, c, maxDepth, depth)
    depth = depth or 0
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "Texture" then ns.TintTexture(region, c) end
    end
    if depth < (maxDepth or 2) then
        for _, child in ipairs({ frame:GetChildren() }) do
            ns.TintFrameTextures(child, c, maxDepth, depth + 1)
        end
    end
end

---------------------------------------------------------------------------
-- Shared color matching
---------------------------------------------------------------------------

function ns.NearColor(r, g, b, color)
    return color ~= nil and r ~= nil
        and math.abs(r - color.r) < 0.01 and math.abs(g - color.g) < 0.01 and math.abs(b - color.b) < 0.01
end

-- Blizzard quest difficulty buckets -> theme keys.
local DIFFICULTY_KEYS = {
    { blizzard = "trivial", theme = "diffTrivial" },
    { blizzard = "standard", theme = "diffEasy" },
    { blizzard = "difficult", theme = "diffStandard" },
    { blizzard = "verydifficult", theme = "diffHard" },
    { blizzard = "impossible", theme = "diffVeryHard" },
}

-- Returns the theme color replacing a Blizzard quest difficulty color, or nil
-- if the color is not a difficulty color or the theme leaves it unset.
function ns.MapDifficultyColor(r, g, b)
    local colors = QuestDifficultyColors
    if not colors then return nil end
    for _, entry in ipairs(DIFFICULTY_KEYS) do
        if ns.NearColor(r, g, b, colors[entry.blizzard]) then
            return ns.db.theme[entry.theme]
        end
    end
    return nil
end
