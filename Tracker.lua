--------------------------------------------------------------------------------
-- Sink / Tracker.lua
--
-- A window that looks like Blizzard's objective tracker, titled "Sink" and
-- the version. On by default: the Tracker tab of the options window or
-- "/sink tracker" turns it off. Drag its title to move it.
--
-- It has one section so far, Dungeons: every dungeon your level lets you
-- enter that still has quests for you (Quests.lua, ns.DungeonsToDo), each
-- quest with the same marks as the map tooltips. The title's button folds
-- the whole window, and the Dungeons header, or its button, folds that
-- section; both are saved.
--
-- It is its own frame, not a module in Blizzard's tracker: Blizzard's holds
-- secure quest item buttons and lays itself out in combat, and addon code in
-- that layout can taint it. So the parts are copied instead: the header
-- atlases, fonts, sizes and spacing from Blizzard_ObjectiveTracker's
-- templates (ObjectiveTrackerContainerHeaderTemplate,
-- ObjectiveTrackerModuleHeaderTemplate and the module layout values).
--------------------------------------------------------------------------------

local _, ns = ...

-- Blizzard's sizes: the container and its header, a module header, how far
-- blocks sit in from the left, and the gaps between header, blocks and lines.
local WIDTH = 260
local HEADER_HEIGHT = 32
local MODULE_SPACING = 10
local MODULE_HEADER_HEIGHT = 25
local BLOCK_X = 20
local BLOCK_GAP = 10
local LINE_SPACING = 4

-- The fonts exist once Blizzard_ObjectiveTracker has loaded, which the
-- Retail UI does at startup; the fallbacks are close in case it has not.
local function Font(name, fallback)
    return _G[name] and name or fallback
end

-- Block titles are gold and quests grey in Blizzard's tracker; the marks
-- here carry the quest colours instead.
local TITLE_COLOR = OBJECTIVE_TRACKER_BLOCK_HEADER_COLOR or { r = 1.0, g = 0.82, b = 0.0 }

local tracker -- the window, created the first time it is shown
local pending -- a refresh is already waiting for the next frame

local function Enabled()
    return ns.db ~= nil and ns.db.tracker == true
end

--------------------------------------------------------------------------------
-- Building the window
--------------------------------------------------------------------------------

-- A button with Blizzard's tracker art. The atlases are the button's size,
-- so they fill it; SetButtonAtlas picks the fold or unfold pair.
local function AtlasButton(parent, width, height, highlight)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button:SetHighlightAtlas(highlight, "ADD")
    return button
end

local function SetButtonAtlas(button, normal)
    button:SetNormalAtlas(normal)
    button:SetPushedAtlas(normal .. "-pressed")
end

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint()
    ns.db.trackerPoint = { point, relativePoint, x, y }
end

local function CreateTracker()
    local frame = CreateFrame("Frame", "SinkTrackerFrame", UIParent)
    frame:SetSize(WIDTH, HEADER_HEIGHT)
    local p = ns.db.trackerPoint
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -320, -220)
    end
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    -- The title bar: the primary header art, "Sink" in the accent colour and the
    -- version in white, and the fold-all button.
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT")
    header:SetSize(WIDTH, HEADER_HEIGHT)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)
    local background = header:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("ui-questtracker-primary-objective-header", true)
    background:SetPoint("CENTER")
    header.Text = header:CreateFontString(nil, "ARTWORK", Font("ObjectiveTrackerHeaderFont", "GameFontNormalMed2"))
    header.Text:SetPoint("LEFT", 7, 0)
    header.Text:SetJustifyH("LEFT")
    header.Text:SetText(ns.Accent("Sink") .. " |cffffffff" .. ns.Version() .. "|r")
    header.MinimizeButton = AtlasButton(header, 18, 19, "ui-questtrackerbutton-red-highlight")
    header.MinimizeButton:SetPoint("RIGHT", -1, 0)
    header.MinimizeButton:SetScript("OnClick", function()
        ns.db.trackerCollapsed = not ns.db.trackerCollapsed
        ns.RefreshTracker()
    end)
    frame.Header = header

    -- The Dungeons section: the secondary header art, its fold button, and
    -- below it one block per dungeon.
    local module = CreateFrame("Frame", nil, frame)
    module:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -MODULE_SPACING)
    module:SetSize(WIDTH, MODULE_HEADER_HEIGHT)
    local moduleHeader = CreateFrame("Button", nil, module)
    moduleHeader:SetPoint("TOPLEFT")
    moduleHeader:SetSize(WIDTH, 26)
    local moduleBackground = moduleHeader:CreateTexture(nil, "BACKGROUND")
    moduleBackground:SetAtlas("ui-questtracker-secondary-objective-header", true)
    moduleBackground:SetPoint("CENTER")
    local moduleText = moduleHeader:CreateFontString(nil, "ARTWORK", Font("ObjectiveTrackerHeaderFont", "GameFontNormalMed2"))
    moduleText:SetPoint("LEFT", 7, 0)
    moduleText:SetJustifyH("LEFT")
    moduleText:SetText("Dungeons")
    local function ToggleModule()
        ns.db.trackerDungeonsCollapsed = not ns.db.trackerDungeonsCollapsed
        ns.RefreshTracker()
    end
    moduleHeader:SetScript("OnClick", ToggleModule)
    moduleHeader.MinimizeButton = AtlasButton(moduleHeader, 16, 16, "ui-questtrackerbutton-yellow-highlight")
    moduleHeader.MinimizeButton:SetPoint("RIGHT", 1, 0)
    moduleHeader.MinimizeButton:SetScript("OnClick", ToggleModule)
    module.Header = moduleHeader
    module.lines = {} -- font strings, reused on every refresh
    frame.Dungeons = module

    frame:Hide()
    return frame
end

-- The nth font string of the section, made the first time it is needed.
local function Line(module, n)
    local line = module.lines[n]
    if not line then
        line = module:CreateFontString(nil, "ARTWORK", Font("ObjectiveTrackerLineFont", "GameFontHighlight"))
        line:SetJustifyH("LEFT")
        line:SetWordWrap(true)
        module.lines[n] = line
    end
    return line
end

--------------------------------------------------------------------------------
-- Filling it in
--------------------------------------------------------------------------------

-- Lays out the dungeon blocks under the section header and returns the
-- section's height. Each block is the dungeon's name and level range, then
-- one line per quest, indented as Blizzard indents a block's lines.
local function FillDungeons(module, dungeons)
    local collapsed = ns.db.trackerDungeonsCollapsed
    SetButtonAtlas(module.Header.MinimizeButton,
        collapsed and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse")
    local used = 0
    local y = MODULE_HEADER_HEIGHT
    if not collapsed then
        for _, entry in ipairs(dungeons) do
            y = y + BLOCK_GAP
            local dungeon = entry.dungeon
            used = used + 1
            local title = Line(module, used)
            title:ClearAllPoints()
            title:SetPoint("TOPLEFT", BLOCK_X, -y)
            title:SetWidth(WIDTH - BLOCK_X)
            title:SetText(("%s %s(%d-%d)|r"):format(dungeon.name, ns.grey.hex, dungeon.minLevel or 0, dungeon.maxLevel or 0))
            title:SetTextColor(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b)
            title:Show()
            y = y + title:GetStringHeight()
            for _, row in ipairs(entry.rows) do
                y = y + LINE_SPACING
                used = used + 1
                local line = Line(module, used)
                local text, color = ns.QuestRowText(row)
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", BLOCK_X, -y)
                line:SetWidth(WIDTH - BLOCK_X)
                line:SetText(text)
                line:SetTextColor(color.r, color.g, color.b)
                line:Show()
                y = y + line:GetStringHeight()
            end
        end
    end
    for n = used + 1, #module.lines do
        module.lines[n]:Hide()
    end
    module:SetHeight(y)
    return y
end

local function Refresh()
    pending = false
    if not tracker or not tracker:IsShown() then
        return
    end
    local collapsed = ns.db.trackerCollapsed
    SetButtonAtlas(tracker.Header.MinimizeButton,
        collapsed and "ui-questtrackerbutton-expand-all" or "ui-questtrackerbutton-collapse-all")
    local height = HEADER_HEIGHT
    -- Like Blizzard's, a section with nothing in it is not shown at all.
    local dungeons = ns.DungeonsToDo and ns.DungeonsToDo() or {}
    local module = tracker.Dungeons
    if collapsed or #dungeons == 0 then
        module:Hide()
    else
        module:Show()
        height = height + MODULE_SPACING + FillDungeons(module, dungeons)
    end
    tracker:SetHeight(height)
end

-- Refresh on the next frame, once however many events asked for it.
function ns.RefreshTracker()
    if not pending then
        pending = true
        C_Timer.After(0, Refresh)
    end
end

-- Show or hide the window for the current setting. Options.lua calls it when
-- "tracker" changes.
function ns.ApplyTracker()
    if not ns.db then
        return
    end
    if Enabled() then
        tracker = tracker or CreateTracker()
        tracker:Show()
        ns.RefreshTracker()
    elseif tracker then
        tracker:Hide()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("QUEST_LOG_UPDATE")
-- Not guaranteed on the Forever beta; see Core.lua.
for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_DATA_LOAD_RESULT" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event)
    if not Enabled() then
        return
    end
    if event == "PLAYER_LOGIN" then
        ns.ApplyTracker()
    elseif event == "PLAYER_LEVEL_UP" then
        -- UnitLevel still has the old level while this event runs.
        C_Timer.After(1, ns.RefreshTracker)
    else
        ns.RefreshTracker()
    end
end)
