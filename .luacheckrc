-- luacheck configuration for WowForever (WoW: Forever, Interface 16001 / 12.x UI)
std = "lua51"
max_line_length = 120
codes = true

exclude_files = { ".luacheckrc" }

ignore = {
    "212/self", -- unused self in module methods
}

-- Globals this addon defines.
globals = {
    "WowForeverDB",
    "SLASH_WOWFOREVER1",
    "SLASH_WOWFOREVER2",
    SlashCmdList = { fields = { "WOWFOREVER" }, other_fields = true },
    "UISpecialFrames",
}

-- WoW API and Blizzard UI globals this addon reads.
read_globals = {
    -- Lua extensions provided by the WoW client
    "strsplit", "strtrim", "tinsert", "geterrorhandler", "unpack",

    -- API
    "CreateFrame", "GetBuildInfo", "InCombatLockdown", "hooksecurefunc", "C_Timer",

    -- Blizzard frames, textures, functions, and constants
    "UIParent", "ColorPickerFrame", "ZoneAbilityFrame", "ObjectiveTrackerFrame",
    "MinimapCompassTexture", "FCFTab_UpdateColors", "NUM_CHAT_WINDOWS",
    "OBJECTIVE_TRACKER_COLOR", "ActionButtonSpellAlertManager", "ActionButton_ShowOverlayGlow",
}
