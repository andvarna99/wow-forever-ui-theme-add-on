local ADDON, ns = ...

ns.DB_VERSION = 4
ns.modules = {}
ns.moduleOrder = {}

---------------------------------------------------------------------------
-- Theme presets. "accent" colors outlines; "text" replaces the default gold
-- UI text; "highlight" replaces the default white UI text.
---------------------------------------------------------------------------

-- Optional theme keys fall back to "accent" when a preset leaves them out.
-- Difficulty, power, and icon keys have no fallback: when unset, Blizzard's
-- colors are left alone.
ns.OPTIONAL_THEME_KEYS = {
    "bars123", "bars45", "bars67", "hover", "glow", "chat", "minimap", "tracker",
    "diffTrivial", "diffEasy", "diffStandard", "diffHard", "diffVeryHard", "power",
    "iconGlyph", "iconBorder", "npcSay",
}

ns.presets = {
    Blossom = {
        accent = { r = 1.00, g = 0.47, b = 0.71, a = 1 },
        text = { r = 1.00, g = 0.71, b = 0.84 },
        highlight = { r = 1.00, g = 0.94, b = 0.97 },
    },
    Sakura = {
        accent = { r = 1.00, g = 0.72, b = 0.82, a = 1 },   -- bar 8, pet, stance, bags
        bars123 = { r = 0.95, g = 0.55, b = 0.70, a = 1 },  -- deep rose
        bars45 = { r = 1.00, g = 0.77, b = 0.87, a = 1 },   -- petal pink
        bars67 = { r = 0.89, g = 0.63, b = 0.85, a = 1 },   -- lilac mauve
        hover = { r = 1.00, g = 0.62, b = 0.77, a = 1 },    -- blush pink (button hover)
        glow = { r = 0.95, g = 0.55, b = 0.70, a = 1 },     -- deep rose (formerly yellow effects)
        chat = { r = 1.00, g = 0.77, b = 0.87, a = 1 },     -- petal pink
        minimap = { r = 0.95, g = 0.55, b = 0.70, a = 1 },  -- deep rose
        tracker = { r = 0.89, g = 0.63, b = 0.85, a = 1 },  -- lilac mauve
        diffTrivial = { r = 0.620, g = 0.557, b = 0.588 },  -- #9E8E96 dusty mauve
        diffEasy = { r = 0.659, g = 0.863, b = 0.769 },     -- #A8DCC4 mint
        diffStandard = { r = 0.961, g = 0.875, b = 0.627 }, -- #F5DFA0 butter
        diffHard = { r = 0.949, g = 0.553, b = 0.698 },     -- #F28DB2 deep rose
        diffVeryHard = { r = 0.878, g = 0.314, b = 0.494 }, -- #E0507E raspberry
        power = { r = 0.878, g = 0.314, b = 0.494, a = 1 }, -- #E0507E raspberry (mana, rage, energy)
        iconGlyph = { r = 0.878, g = 0.314, b = 0.494, a = 1 }, -- #E0507E raspberry
        iconBorder = { r = 0.620, g = 0.557, b = 0.588, a = 1 }, -- #9E8E96 dusty mauve
        npcSay = { r = 0.976, g = 0.639, b = 0.796 },       -- #F9A3CB peony (NPC chat text)
        text = { r = 0.949, g = 0.553, b = 0.698 },         -- #F28DB2 deep rose
        highlight = { r = 1.00, g = 0.96, b = 0.98 },
    },
    Bubblegum = {
        accent = { r = 1.00, g = 0.30, b = 0.62, a = 1 },
        text = { r = 1.00, g = 0.55, b = 0.75 },
        highlight = { r = 1.00, g = 0.92, b = 0.96 },
    },
    Arcane  = {
        accent = { r = 0.20, g = 0.80, b = 1.00, a = 1 },
        text = { r = 0.55, g = 0.85, b = 1.00 },
        highlight = { r = 0.95, g = 0.97, b = 1.00 },
    },
    Fel     = {
        accent = { r = 0.35, g = 1.00, b = 0.20, a = 1 },
        text = { r = 0.60, g = 1.00, b = 0.45 },
        highlight = { r = 0.92, g = 1.00, b = 0.90 },
    },
    Blood   = {
        accent = { r = 0.85, g = 0.10, b = 0.10, a = 1 },
        text = { r = 1.00, g = 0.45, b = 0.40 },
        highlight = { r = 1.00, g = 0.92, b = 0.90 },
    },
    Void    = {
        accent = { r = 0.60, g = 0.25, b = 1.00, a = 1 },
        text = { r = 0.78, g = 0.60, b = 1.00 },
        highlight = { r = 0.96, g = 0.93, b = 1.00 },
    },
    Classic = {
        accent = { r = 1.00, g = 0.82, b = 0.00, a = 1 },
        text = { r = 1.00, g = 0.82, b = 0.00 },
        highlight = { r = 1.00, g = 1.00, b = 1.00 },
    },
}
ns.presetOrder = { "Blossom", "Sakura", "Bubblegum", "Arcane", "Fel", "Blood", "Void", "Classic" }

ns.defaults = {
    version = ns.DB_VERSION,
    theme = {
        accent = { r = 1.00, g = 0.47, b = 0.71, a = 1 },
        text = { r = 1.00, g = 0.71, b = 0.84 },
        highlight = { r = 1.00, g = 0.94, b = 0.97 },
    },
    modules = {},
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function ns.CopyColor(c)
    return { r = c.r, g = c.g, b = c.b, a = c.a }
end

-- Returns a copy of color blended toward white by amount (0-1).
function ns.Lighten(c, amount)
    return {
        r = c.r + (1 - c.r) * amount,
        g = c.g + (1 - c.g) * amount,
        b = c.b + (1 - c.b) * amount,
        a = c.a,
    }
end

-- Returns the theme color for key, falling back to the accent color.
function ns.ThemeColor(key)
    local theme = ns.db.theme
    return (key and theme[key]) or theme.accent
end

function ns.Print(msg)
    print("|cffff78b5WowForever|r: " .. tostring(msg))
end

local function SafeCall(fn, ...)
    local args = { n = select("#", ...), ... }
    return xpcall(function() return fn(unpack(args, 1, args.n)) end, geterrorhandler())
end
ns.SafeCall = SafeCall

---------------------------------------------------------------------------
-- Combat-safe queue
--
-- Anything that creates, parents, or anchors frames near Blizzard's secure
-- action buttons goes through RunOutOfCombat. Work requested during combat
-- lockdown is deduplicated by key and runs on PLAYER_REGEN_ENABLED.
---------------------------------------------------------------------------

local queue, queueOrder = {}, {}

function ns.RunOutOfCombat(key, fn)
    if InCombatLockdown() then
        if not queue[key] then queueOrder[#queueOrder + 1] = key end
        queue[key] = fn
        return false
    end
    SafeCall(fn)
    return true
end

local function FlushQueue()
    local pending, order = queue, queueOrder
    queue, queueOrder = {}, {}
    for _, key in ipairs(order) do
        SafeCall(pending[key])
    end
end

---------------------------------------------------------------------------
-- Saved variables: versioning and migrations
---------------------------------------------------------------------------

-- migrations[n] upgrades a database from version n - 1 to version n.
local migrations = {}

-- v1 (0.1.0): flat layout with colors and action bar settings at the root.
migrations[2] = function(db)
    db.theme = type(db.theme) == "table" and db.theme or {}
    for _, key in ipairs({ "accent", "text", "highlight" }) do
        if type(db[key]) == "table" then db.theme[key] = db[key] end
        db[key] = nil
    end

    db.modules = type(db.modules) == "table" and db.modules or {}
    local bars = db.modules.ActionBars or {}
    if db.borderSize ~= nil then bars.borderSize = db.borderSize end
    if db.tintBlizzardBorder ~= nil then bars.tintBlizzardBorder = db.tintBlizzardBorder end
    db.modules.ActionBars = bars

    local text = db.modules.Text or {}
    if db.themeText ~= nil then text.enabled = db.themeText end
    db.modules.Text = text

    db.borderSize, db.tintBlizzardBorder, db.themeText = nil, nil, nil
end

-- v3 (0.3.0): Chat, Minimap, and ObjectiveTracker graduated from stub modules.
-- Stub defaults saved them as disabled, so switch them on once.
migrations[3] = function(db)
    if type(db.modules) ~= "table" then return end
    for _, name in ipairs({ "Chat", "Minimap", "ObjectiveTracker" }) do
        if type(db.modules[name]) == "table" then db.modules[name].enabled = true end
    end
end

-- v4 (0.5.0): HealthBars was replaced by PowerBars; drop its settings and the
-- health color so health bars keep Blizzard's colors.
migrations[4] = function(db)
    if type(db.modules) == "table" then db.modules.HealthBars = nil end
    if type(db.theme) == "table" then db.theme.health = nil end
end

function ns.MigrateDB(db)
    local version = tonumber(db.version) or 1
    if version > ns.DB_VERSION then
        ns.Print("Saved settings are from a newer version of WowForever; they may not load correctly.")
        return
    end
    for target = version + 1, ns.DB_VERSION do
        migrations[target](db)
        db.version = target
    end
end

local function InitDB(saved)
    local db = type(saved) == "table" and saved or {}
    if next(db) == nil then
        db.version = ns.DB_VERSION
    else
        ns.MigrateDB(db)
    end
    CopyDefaults(ns.defaults, db)
    for _, name in ipairs(ns.moduleOrder) do
        db.modules[name] = CopyDefaults(ns.modules[name].defaults, db.modules[name] or {})
    end
    return db
end

---------------------------------------------------------------------------
-- Module registry
--
-- A module is a table with optional methods, each called as
-- module:Method(settings), where settings is ns.db.modules[name]:
--   Enable  - one-time setup when the module turns on (hooks, frames)
--   Apply   - (re)apply the current theme; called whenever settings change
--   Disable - undo visible changes when the module turns off
--   Audit   - print diagnostics for /wf audit
-- Set module.stub = true for placeholders that cannot be enabled yet.
---------------------------------------------------------------------------

function ns.RegisterModule(name, module)
    module.name = name
    module.label = module.label or name
    module.defaults = module.defaults or {}
    if module.defaults.enabled == nil then
        module.defaults.enabled = not module.stub
    end
    module.active = false
    ns.modules[name] = module
    ns.moduleOrder[#ns.moduleOrder + 1] = name
    return module
end

local function Call(module, method)
    local fn = module[method]
    if fn then SafeCall(fn, module, ns.db.modules[module.name]) end
end

local function Activate(module)
    if module.active or module.stub then return end
    Call(module, "Enable")
    module.active = true
    Call(module, "Apply")
end

local function Deactivate(module)
    if not module.active then return end
    Call(module, "Disable")
    module.active = false
end

function ns.FindModule(name)
    name = (name or ""):lower()
    for _, key in ipairs(ns.moduleOrder) do
        if key:lower() == name then return ns.modules[key] end
    end
end

function ns.SetModuleEnabled(name, enabled)
    local module = ns.modules[name]
    if not module or module.stub then return false end
    ns.db.modules[name].enabled = enabled and true or false
    if enabled then Activate(module) else Deactivate(module) end
    if ns.RefreshOptions then ns.RefreshOptions() end
    return true
end

function ns.ApplyAll()
    if not ns.db then return end
    for _, name in ipairs(ns.moduleOrder) do
        local module = ns.modules[name]
        if module.active then Call(module, "Apply") end
    end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.ApplyPreset(name)
    local preset = ns.presets[name]
    if not preset then return false end
    for _, key in ipairs(ns.OPTIONAL_THEME_KEYS) do
        ns.db.theme[key] = nil
    end
    for key, color in pairs(preset) do
        ns.db.theme[key] = ns.CopyColor(color)
    end
    ns.ApplyAll()
    return true
end

function ns.Reset()
    for _, name in ipairs(ns.moduleOrder) do Deactivate(ns.modules[name]) end
    WowForeverDB = InitDB({})
    ns.db = WowForeverDB
    for _, name in ipairs(ns.moduleOrder) do
        if ns.db.modules[name].enabled then Activate(ns.modules[name]) end
    end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        WowForeverDB = InitDB(WowForeverDB)
        ns.db = WowForeverDB
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        for _, name in ipairs(ns.moduleOrder) do
            if ns.db.modules[name].enabled then Activate(ns.modules[name]) end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        FlushQueue()
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function PrintHelp()
    ns.Print("/wf - open options")
    ns.Print("/wf preset <" .. table.concat(ns.presetOrder, "|"):lower() .. ">")
    ns.Print("/wf border <0-4> - action bar outline thickness")
    ns.Print("/wf module <name> <on|off> - toggle a module")
    ns.Print("/wf audit - check which Blizzard frames exist on this client")
    ns.Print("/wf reset")
end

SLASH_WOWFOREVER1 = "/wf"
SLASH_WOWFOREVER2 = "/wowforever"
SlashCmdList.WOWFOREVER = function(input)
    local cmd, rest = strsplit(" ", strtrim(input or ""), 2)
    cmd = (cmd or ""):lower()
    rest = rest and strtrim(rest) or nil

    if cmd == "" or cmd == "config" or cmd == "options" then
        ns.ToggleOptions()
    elseif cmd == "preset" and rest then
        for _, name in ipairs(ns.presetOrder) do
            if name:lower() == rest:lower() then
                ns.ApplyPreset(name)
                ns.Print("Applied preset " .. name .. ".")
                return
            end
        end
        ns.Print("Unknown preset. Try: " .. table.concat(ns.presetOrder, ", "):lower() .. ".")
    elseif cmd == "border" and tonumber(rest) then
        local bars = ns.db.modules.ActionBars
        bars.borderSize = math.max(0, math.min(4, math.floor(tonumber(rest))))
        ns.ApplyAll()
        ns.Print("Border size set to " .. bars.borderSize .. ".")
    elseif cmd == "module" and rest then
        local name, state = strsplit(" ", rest, 2)
        local module = ns.FindModule(name)
        state = state and state:lower()
        if not module then
            ns.Print("Unknown module. Modules: " .. table.concat(ns.moduleOrder, ", "))
        elseif module.stub then
            ns.Print(module.label .. " is not built yet.")
        elseif state == "on" or state == "off" then
            ns.SetModuleEnabled(module.name, state == "on")
            ns.Print(module.label .. (state == "on" and " enabled." or " disabled."))
        else
            ns.Print("Usage: /wf module <name> <on|off>")
        end
    elseif cmd == "audit" then
        ns.Print("Audit (client interface " .. select(4, GetBuildInfo()) .. "):")
        for _, name in ipairs(ns.moduleOrder) do
            local module = ns.modules[name]
            if module.Audit then SafeCall(module.Audit, module) end
        end
    elseif cmd == "reset" then
        ns.Reset()
        ns.Print("Settings reset.")
    else
        PrintHelp()
    end
end
