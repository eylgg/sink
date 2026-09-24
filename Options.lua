--------------------------------------------------------------------------------
-- Sink / Options.lua
--
-- Slash commands (/sink) and the options window: a portrait frame with a
-- General tab and a Map Pins tab, opened with "/sink" or by clicking
-- Sink in the addon compartment. Everything in this file is optional; Core.lua
-- works without it.
--
-- One write path: Assign(key, value) stores the value, tells the module that
-- owns it, and refreshes the window if it is open, so the slash commands and
-- the window never disagree. Modules reach it as ns.SetOption.
--------------------------------------------------------------------------------

local _, ns = ...

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

local RefreshWindow -- defined with the window below

-- React to a value that is already stored in ns.db.
local function OnChanged(key)
    if key == "enabled" then
        if ns.db.enabled then
            ns.Center()
        else
            ns.RestoreEditModePosition()
        end
    elseif key == "offsetX" or key == "offsetY" then
        ns.Center()
    elseif key == "muteErrors" then
        if ns.ApplyErrorMute then
            ns.ApplyErrorMute()
        end
    elseif key == "mapIcons" or key == "showAllTrainers" or key == "showAllClassTrainers" or key == "showDungeons" then
        if ns.RefreshMapPins then
            ns.RefreshMapPins()
        end
    elseif key == "questItemWarnings" then
        if ns.RefreshBagOverlays then
            ns.RefreshBagOverlays()
        end
    end
    RefreshWindow()
end

local function Assign(key, value)
    if RANGE[key] then
        value = Clamp(value, RANGE[key])
    end
    ns.db[key] = value
    OnChanged(key)
end
-- Modules write their own settings through this so the window follows.
ns.SetOption = Assign

local OpenOptions -- defined with the window below

local function Status()
    local db = ns.db
    ns.Print(("centering is %s | x %.0f | y %.0f"):format(
        db.enabled and "|cff00ff00on|r" or "|cffff0000off|r", db.offsetX, db.offsetY))
end

local function Help()
    ns.Print("commands")
    print("  /sink                 open the options window (also /sink config)")
    print("  /sink status          whether centering is on, and the offsets")
    print("  /sink on | off | toggle")
    print(("  /sink x <n>           horizontal offset from screen center (%d to %d)"):format(RANGE.offsetX.min, RANGE.offsetX.max))
    print(("  /sink y <n>           height above the bottom of the screen (%d to %d)"):format(RANGE.offsetY.min, RANGE.offsetY.max))
    print("  /sink reset           back to the defaults")
    print("  /sink center          re-apply the position now")
    print("  /sink items           quest items that are safe to delete (/sink items help)")
    print("  /sink recipes         vendor recipes you know or not (/sink recipes help)")
    print("  /sink weapons         weapon skills you can learn and who teaches them (/sink weapons help)")
    print("  /sink errors          hide \"not enough energy\" errors when spamming (/sink errors help)")
    print("  /sink map             icons with tooltips on the world map (/sink map help)")
    print("  /sink dump            developer dumps of IDs and coordinates (/sink dump help)")
end

SLASH_SINK1 = "/sink"
SlashCmdList.SINK = function(msg)
    if not ns.db then
        return
    end
    -- The command is case-insensitive; the argument keeps its case for names.
    local command, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()

    if command == "" or command == "config" or command == "options" then
        OpenOptions()
    elseif command == "status" then
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
    else
        Help()
    end
end

-- Clicking Sink in the addon compartment (the dropdown next to the minimap).
function Sink_OnAddonCompartmentClick()
    OpenOptions()
end

--------------------------------------------------------------------------------
-- The options window
--
-- Built from the pieces Blizzard's own panels use: ButtonFrameTemplate for the
-- portrait frame with its inset, LargeSideTabButtonTemplate for the icon tabs
-- down the right edge (as on the professions window), UICheckButtonTemplate for checkboxes and MinimalSliderWithSteppers-
-- Template for the sliders. Pages are described by the table below and built
-- top to bottom; the controls read ns.db whenever the window refreshes.
--------------------------------------------------------------------------------

local WINDOW_NAME = "SinkOptionsFrame"
local window        -- created on first open
local controls = {} -- key -> checkbox or slider, refreshed from ns.db
local refreshing = false

-- A checkbox is { key, label, tooltip }; a slider adds range; a header is
-- { header = ... }.
local PAGES = {
    {
        name = "General",
        icon = "Interface\\Icons\\INV_Misc_Gear_02",
        { header = "Player Frame" },
        { key = "enabled", label = "Auto-center the player frame",
          tooltip = "Keep the player frame horizontally centered, even after Edit Mode moves it." },
        { key = "offsetX", label = "Horizontal offset", range = RANGE.offsetX,
          tooltip = "Distance from the center of the screen. Negative moves the frame left." },
        { key = "offsetY", label = "Height", range = RANGE.offsetY,
          tooltip = "Distance from the bottom of the screen to the bottom edge of the frame." },
        { header = "Errors" },
        { key = "muteErrors", label = "Mute repeated ability errors",
          tooltip = "Hide \"Not enough energy\" and \"not ready yet\" errors, both the red text and the voice line,"
              .. " when you spam an ability." },
        { header = "Tooltips and Warnings" },
        { key = "questItemWarnings", label = "Quest item warnings",
          tooltip = "Tooltip line, bag slot tint and popup for quest items that are safe to delete." },
        { key = "recipeTooltips", label = "Recipe vendor tooltips",
          tooltip = "Vendor tooltips list the recipes sold, with a check for the ones you know." },
        { key = "weaponTooltips", label = "Weapon master tooltips",
          tooltip = "Weapon master tooltips and map icons list the skills taught." },
    },
    {
        name = "Map Pins",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        { key = "mapIcons", label = "Show map icons",
          tooltip = "Icons with tooltips on the world map for the vendors and trainers Sink knows about." },
        { header = "Profession Trainers" },
        { key = "showAllTrainers", label = "Show all profession trainers",
          tooltip = "Off: trainers for your own professions, plus cooking, fishing and first aid, and every primary"
              .. " profession until you have picked two. On: every profession trainer." },
        { header = "Class Trainers" },
        { key = "showAllClassTrainers", label = "Show all class trainers",
          tooltip = "Off: class trainers for your class only. On: every class trainer." },
        { header = "Dungeons" },
        { key = "showDungeons", label = "Show dungeons",
          tooltip = "Dungeon entrances with their level range, and the quests for each dungeon marked done,"
              .. " in your log or not taken." },
    },
}

local function Tooltip(region, title, text)
    region:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    region:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Each builder places its control at y (distance below the page's top) and
-- returns the height it used.
local function Header(page, item, y)
    local text = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("TOPLEFT", 0, -y)
    text:SetText(item.header)
    text:SetTextColor(ns.accent.r, ns.accent.g, ns.accent.b)
    return 24
end

local function Checkbox(page, item, y)
    local box = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", -4, -y + 4)
    box.Text:SetFontObject("GameFontHighlight")
    box.Text:SetText(item.label)
    box:SetScript("OnClick", function(self)
        Assign(item.key, self:GetChecked() and true or false)
    end)
    Tooltip(box, item.label, item.tooltip)
    controls[item.key] = box
    return 28
end

local function Slider(page, item, y)
    local label = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 6, -y)
    label:SetText(item.label)

    local slider = CreateFrame("Frame", nil, page, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("TOPLEFT", 6, -y - 18)
    local range = item.range
    local formatters = {
        [MinimalSliderWithSteppersMixin.Label.Right] = function(value)
            return ("%d"):format(value)
        end,
    }
    slider:Init(ns.db[item.key] or range.min, range.min, range.max, (range.max - range.min) / SLIDER_STEP, formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not refreshing then
            Assign(item.key, value)
        end
    end, page)
    Tooltip(slider.Slider, item.label, item.tooltip)
    controls[item.key] = slider
    return 66
end

local function BuildPage(frame, definition)
    local page = CreateFrame("Frame", nil, frame.Inset)
    page:SetPoint("TOPLEFT", 14, -40) -- clear of the portrait, which hangs over the inset's corner
    page:SetPoint("BOTTOMRIGHT", -14, 12)
    page:Hide()
    local y = 0
    for _, item in ipairs(definition) do
        if item.header then
            y = y + Header(page, item, y)
        elseif item.range then
            y = y + Slider(page, item, y)
        else
            y = y + Checkbox(page, item, y)
        end
    end
    return page
end

function RefreshWindow()
    if not window or not window:IsShown() then
        return
    end
    refreshing = true
    for key, control in pairs(controls) do
        local value = ns.db[key]
        if control.SetChecked then
            control:SetChecked(value and true or false)
        elseif control.SetValue then
            control:SetValue(value or 0)
        end
    end
    refreshing = false
end

local function ShowPage(index)
    window.selectedTab = index
    for i, page in ipairs(window.pages) do
        page:SetShown(i == index)
        window.Tabs[i]:SetChecked(i == index)
    end
    local title = (window.TitleContainer and window.TitleContainer.TitleText) or window.TitleText
    if title then
        title:SetText("Sink: " .. PAGES[index].name)
    end
    RefreshWindow()
end

local function CreateWindow()
    local frame = CreateFrame("Frame", WINDOW_NAME, UIParent, "ButtonFrameTemplate")
    frame:SetSize(440, 458)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local title = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText
    if title then
        title:SetText("Sink")
    end
    if frame.SetPortraitToAsset then
        frame:SetPortraitToAsset("Interface\\Icons\\INV_Enchant_EssenceMagicLarge")
    end
    if ButtonFrameTemplate_HideButtonBar then
        ButtonFrameTemplate_HideButtonBar(frame)
    end
    if ButtonFrameTemplate_HideAttic then
        ButtonFrameTemplate_HideAttic(frame)
    end
    if UISpecialFrames then
        table.insert(UISpecialFrames, WINDOW_NAME) -- Escape closes it
    end

    -- Icon tabs down the outside of the right edge, as on the professions
    -- window: Blizzard's LargeSideTabButtonTemplate, name in the tooltip.
    frame.Tabs = {}
    frame.pages = {}
    for index, definition in ipairs(PAGES) do
        local tab = CreateFrame("Frame", nil, frame, "LargeSideTabButtonTemplate")
        frame.Tabs[index] = tab
        tab.tooltipText = definition.name
        tab.Icon:SetTexture(definition.icon)
        if tab.SetFillToInterior then
            tab:SetFillToInterior(true)
        end
        if index == 1 then
            tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60)
        else
            tab:SetPoint("TOPLEFT", frame.Tabs[index - 1], "BOTTOMLEFT", 0, -2)
        end
        tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
            if button == "LeftButton" and upInside then
                ShowPage(index)
            end
        end)
        frame.pages[index] = BuildPage(frame, definition)
    end
    return frame
end

function OpenOptions()
    if not window then
        local ok, result = pcall(CreateWindow)
        if not ok then
            ns.Print("the options window could not be created (" .. tostring(result) .. "). The slash commands still work.")
            return
        end
        window = result
    end
    window:Show()
    ShowPage(window.selectedTab or 1)
end
