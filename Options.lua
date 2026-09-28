--------------------------------------------------------------------------------
-- Sink / Options.lua
--
-- Slash commands (/sink) and the options window: a portrait frame with a
-- General tab and one per module, opened with "/sink", by clicking Sink in
-- the addon compartment or by clicking the tracker's title. Everything in
-- this file is optional; Core.lua works without it.
--
-- One write path: Assign(key, value) stores the value, tells the module that
-- owns it, and refreshes the window if it is open, so the slash commands and
-- the window never disagree. Modules reach it as ns.SetOption.
--------------------------------------------------------------------------------

local _, ns = ...

local RANGE = {
    splitsShown = { min = 1, max = 10, step = 1 },
}
local SLIDER_STEP = 5 -- the step of a range that does not give its own

local function Clamp(value, range)
    if value < range.min then
        return range.min
    elseif value > range.max then
        return range.max
    end
    return value
end

local RefreshWindow -- defined with the window below

-- Whether a setting is one of the map icon kinds (ns.PIN_KINDS, MapPins.lua).
local function MapKind(key)
    for _, kind in ipairs(ns.PIN_KINDS or {}) do
        if kind.key == key then
            return true
        end
    end
    return false
end

-- React to a value that is already stored in ns.db.
local function OnChanged(key)
    if key == "muteErrors" then
        if ns.ApplyErrorMute then
            ns.ApplyErrorMute()
        end
    elseif key == "mapIcons" or key == "showAllTrainers" or key == "showAllClassTrainers" or MapKind(key) then
        if ns.RefreshMapPins then
            ns.RefreshMapPins()
        end
    elseif key == "splits" or key == "splitsShown" then
        if ns.ApplySplits then
            ns.ApplySplits()
        end
    elseif key == "tracker" then
        if ns.ApplyTracker then
            ns.ApplyTracker()
        end
    elseif key == "trackerTalents" or key == "trackerTracking" or key == "trackerQuestItems" or key == "trackerDungeons"
        or key == "trackerClassTraining" or key == "trackerWeaponSkills" or key == "trackerCurrentDungeon"
        or key == "trackerNearby" or key == "scanner" then
        if ns.RefreshTracker then
            ns.RefreshTracker()
        end
    elseif key == "questItemWarnings" then
        if ns.RefreshBagOverlays then
            ns.RefreshBagOverlays()
        end
        if ns.RefreshTracker then
            ns.RefreshTracker()
        end
    end
    RefreshWindow()
end

local function Assign(key, value)
    if RANGE[key] then
        value = Clamp(math.floor(value + 0.5), RANGE[key])
    end
    ns.db[key] = value
    OnChanged(key)
end
-- Modules write their own settings through this so the window follows.
ns.SetOption = Assign

local OpenOptions -- defined with the window below

local function Help()
    ns.Print("commands")
    print("  /sink                 open the options window (also /sink config)")
    print("  /sink version         the version you are running")
    print("  /sink items           quest items that are safe to delete (/sink items help)")
    print("  /sink recipes         vendor recipes you know or not (/sink recipes help)")
    print("  /sink weapons         weapon skills you can learn and who teaches them (/sink weapons help)")
    print("  /sink errors          hide \"not enough energy\" errors when spamming (/sink errors help)")
    print("  /sink map             icons with tooltips on the world map (/sink map help)")
    print("  /sink splits          show or hide the splits window (the Splits tab lists the times)")
    print("  /sink tracker         show or hide the Sink tracker")
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
    elseif command == "version" or command == "status" then
        ns.Print("version " .. ns.Version())
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
    elseif command == "splits" or command == "split" then
        Assign("splits", not ns.db.splits)
        ns.Print("splits window " .. (ns.db.splits and "|cff00ff00on|r" or "|cffff0000off|r") .. ".")
    elseif command == "tracker" then
        Assign("tracker", not ns.db.tracker)
        ns.Print("tracker " .. (ns.db.tracker and "|cff00ff00on|r" or "|cffff0000off|r") .. ".")
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
-- { header = ... }; { build = fn } lets a module draw its own part of the
-- page: fn(page, y) returns the height it used.
local PAGES = {
    {
        name = "General",
        icon = "Interface\\Icons\\INV_Misc_Gear_02",
        { header = "Errors" },
        { key = "muteErrors", label = "Mute repeated ability errors",
          tooltip = "Hide \"Not enough energy\" and \"not ready yet\" errors, both the red text and the voice line,"
              .. " when you spam an ability." },
        { header = "Tooltips and Warnings" },
        { key = "questItemWarnings", label = "Quest item warnings",
          tooltip = "Bag slot tint and tracker list for quest items that are safe to delete, and a"
              .. " tooltip line naming the quest: \"Needed for\" until it is done, \"Done with\" after." },
        { key = "recipeTooltips", label = "Recipe vendor tooltips",
          tooltip = "Vendor tooltips list the recipes sold, with a check for the ones you know." },
        { key = "reagentTooltips", label = "Reagent tooltips",
          tooltip = "Reagent tooltips list the recipes that use them, with a check for the ones you know." },
        { key = "weaponTooltips", label = "Weapon master tooltips",
          tooltip = "Weapon master tooltips and map icons list the skills taught." },
        { header = "Rare Scanner" },
        { key = "scanner", label = "Scan for rares and quest mobs",
          tooltip = "Watch nameplates, your mouseover and your target, out of combat and outside instances, for"
              .. " rares, quest elites and NPCs a quest still needs you at. What it finds is listed in the"
              .. " tracker's Nearby section. Enemy nameplates must be shown to see past your mouse." },
        { key = "scannerSkull", label = "Put a skull on what it finds",
          tooltip = "Mark each one found with a skull, once per spawn, so taking the skull off keeps it off." },
    },
    {
        name = "Map Pins",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        { key = "mapIcons", label = "Show map icons",
          tooltip = "Icons with tooltips on the world map for the vendors and trainers Sink knows about." },
        { header = "Show on the Map" },
        { kinds = true }, -- a checkbox for each kind of icon, two to a row; also in the world map's filter menu
        { header = "Trainers" },
        { key = "showAllTrainers", label = "Show all profession trainers",
          tooltip = "Off: trainers for your own professions, plus cooking, fishing and first aid, and every primary"
              .. " profession until you have picked two. On: every profession trainer." },
        { key = "showAllClassTrainers", label = "Show all class trainers",
          tooltip = "Off: class trainers for your class only. On: every class trainer." },
    },
    {
        name = "Splits",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        { key = "splits", label = "Show the splits window",
          tooltip = "A small window you can drag anywhere with the current level's /played time and the last"
              .. " few levels. The times are recorded for every character whether it is shown or not." },
        { key = "splitsShown", label = "Levels in the window", range = RANGE.splitsShown,
          tooltip = "How many finished levels the splits window lists under the current one." },
        { header = "This Character" },
        { build = function(page, y)
            return ns.BuildSplitsList and ns.BuildSplitsList(page, y) or 0
        end },
    },
    {
        name = "Professions",
        icon = "Interface\\Icons\\INV_Misc_Book_11",
        { header = "Recipes to Learn" },
        { build = function(page, y)
            return ns.BuildProfessionList and ns.BuildProfessionList(page, y) or 0
        end },
    },
    {
        name = "Items",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        { build = function(page, y)
            return ns.BuildItemList and ns.BuildItemList(page, y) or 0
        end },
    },
    {
        name = "Tracker",
        icon = "Interface\\Icons\\INV_Scroll_03",
        { key = "tracker", label = "Enable tracker",
          tooltip = "A window like the objective tracker, titled Sink, that you can drag by its title."
              .. " It lists the dungeon you are in, unspent talent points, gathering tracking that is off, quest"
              .. " items you can delete,"
              .. " the dungeons your level lets you enter that still have quests for you, and the class training"
              .. " and weapon skills you can learn now." },
        { header = "Show in the Tracker" },
        { grid = {
            { key = "trackerNearby", label = "Nearby",
              tooltip = "Rares, quest elites and NPCs a quest still needs you at, once the scanner has seen them"
                  .. " close by. Click one to target it." },
            { key = "trackerCurrentDungeon", label = "Current dungeon",
              tooltip = "While you are in a dungeon Sink knows: each boss ticked off as it dies, and your"
                  .. " quests there with their objectives." },
            { key = "trackerTalents", label = "Talents",
              tooltip = "How many talent points you have not spent. Hidden while there are none." },
            { key = "trackerTracking", label = "Tracking",
              tooltip = "Find Minerals or Find Herbs while you know it and no tracking is on. Click it to turn it on." },
            { key = "trackerQuestItems", label = "Items to delete",
              tooltip = "Quest items in your bags whose quests are complete. Click one to delete it; you are asked"
                  .. " first." },
            { key = "trackerDungeons", label = "Dungeons",
              tooltip = "The dungeons your level lets you enter that still have quests for you, with those quests." },
            { key = "trackerClassTraining", label = "Class training",
              tooltip = "The skills your class trainer can teach you now, and what they cost together." },
            { key = "trackerWeaponSkills", label = "Weapon skills",
              tooltip = "The weapon skills your class can learn now, and the cities that teach them." },
        } },
    },
    {
        name = "Ignored",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        { build = function(page, y) -- its own Class Training and Dungeons headings
            return ns.BuildIgnoredList and ns.BuildIgnoredList(page, y) or 0
        end },
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

local function Checkbox(page, item, y, x)
    local box = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", (x or 0) - 4, -y + 4)
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
    slider:Init(ns.db[item.key] or range.min, range.min, range.max, (range.max - range.min) / (range.step or SLIDER_STEP),
        formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not refreshing then
            Assign(item.key, value)
        end
    end, page)
    Tooltip(slider.Slider, item.label, item.tooltip)
    controls[item.key] = slider
    return 66
end

-- What each kind of map icon covers, for its checkbox's tooltip.
local KIND_TOOLTIPS = {
    showClassTrainers = "Class trainers, and the pet, portal and demon trainers. Yours only unless"
        .. " \"Show all class trainers\" is on.",
    showProfessionTrainers = "Profession trainers, filtered to your professions unless \"Show all profession"
        .. " trainers\" is on.",
    showWeaponMasters = "Weapon masters, with the weapon skills they teach on the tooltip.",
    showInnkeepers = "Innkeepers.",
    showBankers = "Bankers.",
    showAuctioneers = "Auctioneers.",
    showStableMasters = "Stable masters.",
    showBooks = "Books lying in the world, such as Baxtan: On Destructive Magics.",
    showFlightMasters = "Flight masters for your faction on zone and city maps, grey until you have discovered"
        .. " them. Which you have is known once you open any flight master's map.",
    showDungeons = "Dungeon entrances with their level range, and the quests for each dungeon marked done,"
        .. " in your log or not taken.",
    showQuestNPCs = "Quest givers while they have a quest for you, and the NPCs a quest sends you to or"
        .. " that take it in.",
    showTravel = "Zeppelins, boats and teleporters, titled for where they take you.",
    showEntrances = "Cave and crypt entrances, such as the Entrance to Crypts in Tirisfal Glades.",
    showEliteQuests = "Elites that drop an item starting a quest, shown until you have done that quest. Gold dragon.",
    showRares = "Rare mobs, such as Bayne in Tirisfal Glades. Silver dragon.",
    showOtherPins = "Everything else: vendors such as fishing suppliers and quartermasters, and icons you added.",
}

-- Checkboxes two to a row, { key, label, tooltip } each; returns the height
-- used. KindCheckboxes makes one for each kind of map icon (ns.PIN_KINDS,
-- MapPins.lua).
local function Grid(page, y, items)
    for i, item in ipairs(items) do
        local row, column = math.floor((i - 1) / 2), (i - 1) % 2
        Checkbox(page, item, y + row * 28, column * 190)
    end
    return math.ceil(#items / 2) * 28
end

local function KindCheckboxes(page, y)
    local items = {}
    for _, kind in ipairs(ns.PIN_KINDS or {}) do
        items[#items + 1] = { key = kind.key, label = kind.label, tooltip = KIND_TOOLTIPS[kind.key] or kind.label }
    end
    return Grid(page, y, items)
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
        elseif item.build then
            y = y + item.build(page, y)
        elseif item.kinds then
            y = y + KindCheckboxes(page, y)
        elseif item.grid then
            y = y + Grid(page, y, item.grid)
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
    if ns.RefreshSplitsList then
        ns.RefreshSplitsList()
    end
    if ns.RefreshProfessionList then
        ns.RefreshProfessionList()
    end
    if ns.RefreshIgnoredList then
        ns.RefreshIgnoredList()
    end
    if ns.RefreshItemList then
        ns.RefreshItemList()
    end
end

local function ShowPage(index)
    window.selectedTab = index
    for i, page in ipairs(window.pages) do
        page:SetShown(i == index)
        window.Tabs[i]:SetChecked(i == index)
    end
    local title = (window.TitleContainer and window.TitleContainer.TitleText) or window.TitleText
    if title then
        -- The first page is the addon's own: its name and version; the others are just their name.
        title:SetText(index == 1 and ("Sink " .. ns.Version()) or PAGES[index].name)
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

    -- The version, from the TOC, small and grey in the bottom-right corner.
    local version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("BOTTOMRIGHT", frame.Inset or frame, "BOTTOMRIGHT", -8, 6)
    version:SetText("Version " .. ns.Version())

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
ns.OpenOptions = OpenOptions
