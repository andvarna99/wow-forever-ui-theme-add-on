local _, ns = ...

local M = ns.RegisterModule("Chat", {
    label = "Chat border and tabs",
    defaults = { enabled = true, borderSize = 1, themeTabs = true },
})

-- Chat frames have no border of their own, so this module adds a
-- BackdropTemplate outline around each chat window's background and retints
-- tab text after Blizzard colors it (FCFTab_UpdateColors).
--
-- NPC "say" text is recolored through ChangeChatColor, the same API as the
-- in-game chat color settings. The game saves that color, so the player's
-- original is stored in settings.npcSayOriginal the first time and restored
-- when the module is disabled or the theme leaves npcSay unset.

local NPC_SAY = "MONSTER_SAY"

local function CurrentNpcSayColor()
    local info = ChatTypeInfo and ChatTypeInfo[NPC_SAY]
    if info then return { r = info.r, g = info.g, b = info.b } end
    return nil
end

local function SetNpcSayColor(c)
    if not (c and ChangeChatColor) then return end
    local current = CurrentNpcSayColor()
    if current and ns.NearColor(current.r, current.g, current.b, c) then return end
    ChangeChatColor(NPC_SAY, c.r, c.g, c.b)
end

local function ApplyNpcSay(settings)
    if not settings.npcSayOriginal then settings.npcSayOriginal = CurrentNpcSayColor() end
    local themed = M.active and ns.db.theme.npcSay
    SetNpcSayColor(themed or settings.npcSayOriginal)
end

local overlays = {}   -- chat frame -> outline frame
local tabColors = {}  -- tab -> last color Blizzard set on its text
local tabHooked = false

local function ForEachChatFrame(fn)
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then fn(chatFrame, i) end
    end
end

local function TabText(tab)
    return tab and (tab.Text or _G[(tab:GetName() or "") .. "Text"])
end

local function ColorTab(tab)
    local text = TabText(tab)
    if not text then return end
    if M.active and ns.db.modules.Chat.themeTabs then
        local c = ns.db.theme.text
        text:SetTextColor(c.r, c.g, c.b)
    elseif tabColors[tab] then
        text:SetTextColor(unpack(tabColors[tab]))
    end
end

local function Outline(chatFrame, i, settings)
    local overlay = overlays[chatFrame]
    if not overlay then
        overlay = CreateFrame("Frame", nil, chatFrame, "BackdropTemplate")
        overlay:EnableMouse(false)
        overlays[chatFrame] = overlay
    end
    local anchor = _G["ChatFrame" .. i .. "Background"] or chatFrame
    local size = settings.borderSize
    if size > 0 then
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", anchor, "TOPLEFT", -size, size)
        overlay:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", size, -size)
        overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = size })
        local c = ns.ThemeColor("chat")
        overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
        overlay:Show()
    else
        overlay:Hide()
    end
end

function M:Enable()
    if not tabHooked and FCFTab_UpdateColors then
        tabHooked = true
        hooksecurefunc("FCFTab_UpdateColors", function(tab)
            local text = TabText(tab)
            if text then tabColors[tab] = { text:GetTextColor() } end
            ColorTab(tab)
        end)
    end
end

function M:Apply(settings)
    ApplyNpcSay(settings)
    ForEachChatFrame(function(chatFrame, i)
        Outline(chatFrame, i, settings)
        local tab = _G["ChatFrame" .. i .. "Tab"]
        local text = TabText(tab)
        if text and not tabColors[tab] then tabColors[tab] = { text:GetTextColor() } end
        ColorTab(tab)
    end)
end

function M:Disable(settings)
    for _, overlay in pairs(overlays) do overlay:Hide() end
    for tab in pairs(tabColors) do ColorTab(tab) end
    SetNpcSayColor(settings.npcSayOriginal)
end

function M:Audit()
    local count = 0
    ForEachChatFrame(function() count = count + 1 end)
    ns.Print(("  Chat: %d chat frames, tab hook %s, NPC say color %s"):format(count,
        tabHooked and "installed" or "|cffff5555not installed|r",
        (ChangeChatColor and CurrentNpcSayColor()) and "ok" or "|cffff5555missing|r"))
end
