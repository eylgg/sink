--------------------------------------------------------------------------------
-- Sink / Tracker.lua
--
-- A window that looks like Blizzard's objective tracker, titled "Sink" and
-- the version. On by default: the Tracker tab of the options window or
-- "/sink tracker" turns it off. Drag its title to move it.
--
-- Its sections, each folded by clicking its header or its button, and hidden
-- while it has nothing to list:
--   Dungeons       every dungeon your level lets you enter that still has
--                  quests for you (Quests.lua), each quest with the same
--                  marks as the map tooltips
--   Class Skills   what your class trainer can teach you now (Trainers.lua)
--   Weapon Skills  what a weapon master can teach you now, and in which
--                  city (Weapons.lua)
-- The title's button folds the whole window. What is folded is saved.
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

local SECTIONS -- the section definitions, below with what fills them

local function Folded(key)
    return ns.db.trackerFolded ~= nil and ns.db.trackerFolded[key] == true
end

-- A section: Blizzard's secondary header art with the section's name and a
-- fold button, and below it the lines, made as they are needed.
local function CreateSection(frame, definition)
    local section = CreateFrame("Frame", nil, frame)
    section:SetSize(WIDTH, MODULE_HEADER_HEIGHT)
    section.definition = definition
    local header = CreateFrame("Button", nil, section)
    header:SetPoint("TOPLEFT")
    header:SetSize(WIDTH, 26)
    local background = header:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("ui-questtracker-secondary-objective-header", true)
    background:SetPoint("CENTER")
    local text = header:CreateFontString(nil, "ARTWORK", Font("ObjectiveTrackerHeaderFont", "GameFontNormalMed2"))
    text:SetPoint("LEFT", 7, 0)
    text:SetJustifyH("LEFT")
    text:SetText(definition.title)
    local function Toggle()
        ns.db.trackerFolded = ns.db.trackerFolded or {}
        ns.db.trackerFolded[definition.key] = not Folded(definition.key)
        ns.RefreshTracker()
    end
    header:SetScript("OnClick", Toggle)
    header.MinimizeButton = AtlasButton(header, 16, 16, "ui-questtrackerbutton-yellow-highlight")
    header.MinimizeButton:SetPoint("RIGHT", 1, 0)
    header.MinimizeButton:SetScript("OnClick", Toggle)
    section.Header = header
    section.lines = {} -- font strings, reused on every refresh
    section:Hide()
    return section
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

    frame.sections = {}
    for index, definition in ipairs(SECTIONS) do
        frame.sections[index] = CreateSection(frame, definition)
    end

    frame:Hide()
    return frame
end

-- The nth font string of a section, made the first time it is needed.
local function Line(section, n)
    local line = section.lines[n]
    if not line then
        line = section:CreateFontString(nil, "ARTWORK", Font("ObjectiveTrackerLineFont", "GameFontHighlight"))
        line:SetJustifyH("LEFT")
        line:SetWordWrap(true)
        section.lines[n] = line
    end
    return line
end

--------------------------------------------------------------------------------
-- Filling it in
--------------------------------------------------------------------------------

-- What each section lists, as lines: { text, color, block }. A line with
-- block starts a new block, set apart as Blizzard sets apart its quests; the
-- lines after it sit under it.

-- A block per dungeon: its name and level range, then its quests.
local function DungeonLines()
    local lines = {}
    for _, entry in ipairs(ns.DungeonsToDo and ns.DungeonsToDo() or {}) do
        local dungeon = entry.dungeon
        lines[#lines + 1] = { block = true, color = TITLE_COLOR,
            text = ("%s %s(%d-%d)|r"):format(dungeon.name, ns.grey.hex, dungeon.minLevel or 0, dungeon.maxLevel or 0) }
        for _, row in ipairs(entry.rows) do
            local text, color = ns.QuestRowText(row)
            lines[#lines + 1] = { text = text, color = color }
        end
    end
    return lines
end

-- One block of the class skills you can learn now.
local function ClassSkillLines()
    local lines = {}
    for i, name in ipairs(ns.ClassSkillsToLearn and ns.ClassSkillsToLearn() or {}) do
        lines[#lines + 1] = { block = i == 1, text = ns.CROSS .. " " .. name, color = ns.missing }
    end
    return lines
end

-- One block of the weapon skills you can learn now, each with where.
local function WeaponSkillLines()
    local lines = {}
    for i, skill in ipairs(ns.WeaponSkillsToLearn and ns.WeaponSkillsToLearn() or {}) do
        lines[#lines + 1] = { block = i == 1, color = ns.missing,
            text = ("%s %s %s(%s)|r"):format(ns.CROSS, skill.name, ns.grey.hex, skill.where) }
    end
    return lines
end

SECTIONS = {
    { key = "dungeons", title = "Dungeons", lines = DungeonLines },
    { key = "classSkills", title = "Class Skills", lines = ClassSkillLines },
    { key = "weaponSkills", title = "Weapon Skills", lines = WeaponSkillLines },
}

-- Lays out a section's lines under its header and returns its height.
local function FillSection(section, lines)
    local folded = Folded(section.definition.key)
    SetButtonAtlas(section.Header.MinimizeButton,
        folded and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse")
    local y = MODULE_HEADER_HEIGHT
    local used = 0
    if not folded then
        for n, entry in ipairs(lines) do
            y = y + (entry.block and BLOCK_GAP or LINE_SPACING)
            local line = Line(section, n)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", BLOCK_X, -y)
            line:SetWidth(WIDTH - BLOCK_X)
            line:SetText(entry.text)
            line:SetTextColor(entry.color.r, entry.color.g, entry.color.b)
            line:Show()
            y = y + line:GetStringHeight()
            used = n
        end
    end
    for n = used + 1, #section.lines do
        section.lines[n]:Hide()
    end
    section:SetHeight(y)
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
    -- Each shown section below the last; like Blizzard's, one with nothing
    -- in it is not shown at all.
    local height = HEADER_HEIGHT
    local above = tracker.Header
    for _, section in ipairs(tracker.sections) do
        local lines = not collapsed and section.definition.lines() or {}
        if #lines == 0 then
            section:Hide()
        else
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -MODULE_SPACING)
            section:Show()
            height = height + MODULE_SPACING + FillSection(section, lines)
            above = section
        end
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
-- Quests for Dungeons; learned spells and skill lines, and a trainer window
-- recording what it teaches, for the skill sections.
for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_DATA_LOAD_RESULT",
    "SPELLS_CHANGED", "SKILL_LINES_CHANGED", "TRAINER_SHOW", "TRAINER_UPDATE" }) do
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
