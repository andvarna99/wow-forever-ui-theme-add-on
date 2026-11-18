local _, ns = ...

-- Opens the Blizzard color picker for a color table {r, g, b, a}.
-- onChange is called with the color table every time the selection changes,
-- including when the user cancels and the original color is restored.
-- Uses only the public SetupColorPickerAndShow API (no writes to
-- ColorPickerFrame fields).
function ns.OpenColorPicker(color, hasAlpha, onChange)
    if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then
        ns.Print("Color picker API not available on this client.")
        return
    end

    local original = ns.CopyColor(color)

    local function onSelect()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        color.r, color.g, color.b = r, g, b
        if hasAlpha then color.a = ColorPickerFrame:GetColorAlpha() end
        onChange(color)
    end

    local function onCancel()
        color.r, color.g, color.b, color.a = original.r, original.g, original.b, original.a
        onChange(color)
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = color.r,
        g = color.g,
        b = color.b,
        opacity = color.a or 1,
        hasOpacity = hasAlpha,
        swatchFunc = onSelect,
        opacityFunc = onSelect,
        cancelFunc = onCancel,
    })
end
