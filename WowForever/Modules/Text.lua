local _, ns = ...

local M = ns.RegisterModule("Text", {
    label = "UI text colors",
    defaults = { enabled = true },
})

-- Retints Blizzard's shared font objects. Strings that set their own color
-- explicitly are not affected. No global color tables are modified.

-- Font objects that use Blizzard's default gold UI text.
local GOLD_FONTS = {
    "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge",
    "GameFontNormalHuge", "GameFontNormalMed3", "GameFontNormalLeft",
}

-- Font objects that use Blizzard's default white UI text.
local WHITE_FONTS = {
    "GameFontHighlight", "GameFontHighlightSmall", "GameFontHighlightLarge",
    "GameFontHighlightMedium", "GameFontHighlightLeft",
}

local originals = {}

local function Tint(list, color)
    for _, fontName in ipairs(list) do
        local font = _G[fontName]
        if font and font.SetTextColor then
            if not originals[fontName] then originals[fontName] = { font:GetTextColor() } end
            font:SetTextColor(color.r, color.g, color.b)
        end
    end
end

function M:Apply()
    Tint(GOLD_FONTS, ns.db.theme.text)
    Tint(WHITE_FONTS, ns.db.theme.highlight)
end

function M:Disable()
    for fontName, color in pairs(originals) do
        local font = _G[fontName]
        if font then font:SetTextColor(unpack(color)) end
    end
end

function M:Audit()
    local missing = {}
    for _, list in ipairs({ GOLD_FONTS, WHITE_FONTS }) do
        for _, fontName in ipairs(list) do
            if not _G[fontName] then missing[#missing + 1] = fontName end
        end
    end
    if #missing == 0 then
        ns.Print("  Font objects: all found")
    else
        ns.Print("  |cffff5555Font objects missing: " .. table.concat(missing, ", ") .. "|r")
    end
end
