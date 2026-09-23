--------------------------------------------------------------------------------
-- Sink / Options.lua
--
-- Slash commands (/sink) and a panel under Options -> AddOns -> Sink.
-- Everything in this file is optional; Core.lua works without it.
--------------------------------------------------------------------------------

local ADDON_NAME, ns = ...

local RANGE = {
    offsetX = { min = -800, max = 800 },
    offsetY = { min = 0, max = 800 },
}
local SLIDER_STEP = 5

local function Clamp(value, range)
    if value < range.min then
        return range.min
    elseif value > range.max then
        return range.max
    end
    return value
end

-- React to a value that is already stored in ns.db.
local function OnChanged(key)
    if key == "enabled" then
        if ns.db.enabled then
            ns.Center()
        else
            ns.RestoreEditModePosition()
        end
    elseif key == "muteErrors" then
        if ns.ApplyErrorMute then
            ns.ApplyErrorMute()
        end
    else
        ns.Center()
    end
end

-- Single write path. When the options panel exists the change goes through its
-- Settings object so the panel and the slash commands never disagree.
local function Assign(key, value)
    if RANGE[key] then
        value = Clamp(value, RANGE[key])
    end
    local setting = ns.settings and ns.settings[key]
    if setting then
        setting:SetValue(value) -- writes ns.db[key] and fires OnChanged through the callback
    else
        ns.db[key] = value
        OnChanged(key)
    end
end
-- Modules write their own settings through this so the panel's checkboxes follow.
ns.SetOption = Assign

local function Status()
    local db = ns.db
    ns.Print(("centering is %s | x %.0f | y %.0f"):format(
        db.enabled and "|cff00ff00on|r" or "|cffff0000off|r", db.offsetX, db.offsetY))
end

local function Help()
    ns.Print("commands")
    print("  /sink                 status")
    print("  /sink on | off | toggle")
    print(("  /sink x <n>           horizontal offset from screen center (%d to %d)"):format(RANGE.offsetX.min, RANGE.offsetX.max))
    print(("  /sink y <n>           height above the bottom of the screen (%d to %d)"):format(RANGE.offsetY.min, RANGE.offsetY.max))
    print("  /sink reset           back to the defaults")
    print("  /sink center          re-apply the position now")
    print("  /sink config          open the options panel")
    print("  /sink items           quest items that are safe to delete (/sink items help)")
    print("  /sink recipes         vendor recipes you know or not (/sink recipes help)")
    print("  /sink weapons         weapon skills you can learn and who teaches them (/sink weapons help)")
    print("  /sink errors          hide \"not enough energy\" errors when spamming (/sink errors help)")
    print("  /sink map             icons with tooltips on the world map (/sink map help)")
    print("  /sink dump            developer dumps of IDs and coordinates (/sink dump help)")
end

local function OpenOptions()
    if ns.settingsCategoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(ns.settingsCategoryID)
    else
        ns.Print("the options panel is not available; use the slash commands instead.")
    end
end

SLASH_SINK1 = "/sink"
SlashCmdList.SINK = function(msg)
    if not ns.db then
        return
    end
    -- The command is case-insensitive; the argument keeps its case for names.
    local command, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()

    if command == "" or command == "status" then
        Status()
    elseif command == "on" then
        Assign("enabled", true)
        Status()
    elseif command == "off" then
        Assign("enabled", false)
        Status()
    elseif command == "toggle" then
        Assign("enabled", not ns.db.enabled)
        Status()
    elseif command == "x" or command == "y" then
        local n = tonumber(arg)
        if not n then
            ns.Print("usage: /sink " .. command .. " <number>")
            return
        end
        Assign(command == "x" and "offsetX" or "offsetY", n)
        Status()
    elseif command == "reset" then
        Assign("offsetX", ns.defaults.offsetX)
        Assign("offsetY", ns.defaults.offsetY)
        Status()
    elseif command == "center" then
        ns.Center()
        Status()
    elseif command == "items" or command == "item" then
        if ns.QuestItemsCommand then
            ns.QuestItemsCommand(arg)
        end
    elseif command == "recipes" or command == "recipe" then
        if ns.RecipesCommand then
            ns.RecipesCommand(arg)
        end
    elseif command == "weapons" or command == "weapon" then
        if ns.WeaponsCommand then
            ns.WeaponsCommand(arg)
        end
    elseif command == "errors" or command == "error" then
        if ns.ErrorsCommand then
            ns.ErrorsCommand(arg)
        end
    elseif command == "map" or command == "maps" then
        if ns.MapCommand then
            ns.MapCommand(arg)
        end
    elseif command == "dump" then
        if ns.DumpCommand then
            ns.DumpCommand(arg)
        end
    elseif command == "config" or command == "options" then
        OpenOptions()
    else
        Help()
    end
end

-- Clicking Sink in the addon compartment (the dropdown next to the minimap).
function Sink_OnAddonCompartmentClick()
    OpenOptions()
end

--------------------------------------------------------------------------------
-- Options -> AddOns -> Sink
--------------------------------------------------------------------------------

local function RegisterSlider(category, key, label, tooltip)
    local range = RANGE[key]
    local options = Settings.CreateSliderOptions(range.min, range.max, SLIDER_STEP)
    if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end

    local setting = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_" .. key, key, ns.db,
        Settings.VarType.Number, label, ns.defaults[key])
    setting:SetValueChangedCallback(function(_, value)
        ns.db[key] = value
        OnChanged(key)
    end)
    Settings.CreateSlider(category, setting, options, tooltip)
    return setting
end

local function RegisterCheckbox(category, key, label, tooltip)
    local setting = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_" .. key, key, ns.db,
        Settings.VarType.Boolean, label, ns.defaults[key])
    setting:SetValueChangedCallback(function(_, value)
        ns.db[key] = value
        OnChanged(key)
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
    return setting
end

local function CreateSettingsPanel()
    local category = Settings.RegisterVerticalLayoutCategory("Sink")
    ns.settingsCategoryID = category:GetID()
    ns.settings = {}

    ns.settings.enabled = RegisterCheckbox(category, "enabled", "Auto-center the player frame",
        "Keep the player frame horizontally centered, even after Edit Mode moves it.")
    ns.settings.offsetX = RegisterSlider(category, "offsetX", "Horizontal offset",
        "Distance from the center of the screen. Negative moves the frame left.")
    ns.settings.offsetY = RegisterSlider(category, "offsetY", "Height",
        "Distance from the bottom of the screen to the bottom edge of the frame.")

    ns.settings.muteErrors = RegisterCheckbox(category, "muteErrors", "Mute repeated ability errors",
        "Hide \"Not enough energy\" and \"not ready yet\" errors, both the red text and the voice line, when you spam an ability.")

    Settings.RegisterAddOnCategory(category)
end

-- Called from Core.lua on PLAYER_LOGIN, after the saved variables exist.
function ns.SetupOptions()
    local ok, err = pcall(CreateSettingsPanel)
    if not ok then
        ns.settings = nil
        ns.Print("options panel could not be created (" .. tostring(err) .. "). Slash commands still work.")
    end
end
