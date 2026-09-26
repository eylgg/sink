--------------------------------------------------------------------------------
-- Sink / Tracker.lua
--
-- A window that looks like Blizzard's objective tracker, titled "Sink" and
-- the version. On by default: the Tracker tab of the options window or
-- "/sink tracker" turns it off. Drag its title to move it.
--
-- Its sections, each folded by clicking its header or its button, and hidden
-- while it has nothing to list:
--   Talents        how many talent points you have not spent, "2 unspent talents"
--   Items to Delete quest items in your bags whose quests are complete
--                  (QuestItems.lua); click one to delete it, after a Delete /
--                  Keep question
--   Dungeons       every dungeon your level lets you enter that still has
--                  quests for you (Quests.lua), each quest with the same
--                  marks as the map tooltips
--   Class Training what your class trainer can teach you now, and the cost
--                  of it all, red when you cannot afford it (Trainers.lua)
--   Weapon Skills  what a weapon master can teach you now, and in which
--                  city (Weapons.lua)
-- The title's button folds the whole window. What is folded is saved. Each
-- section has a "Show in tracker" checkbox on the options window's Tracker tab.
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

-- Pin the frame by its top-left corner and save that. A drag leaves it
-- anchored by whichever point the client picks, often the centre, and then
-- the title moved whenever the sections below grew or shrank.
local function AnchorTop(frame)
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    ns.db.trackerPoint = { "TOPLEFT", "BOTTOMLEFT", left, top }
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
        if p[1] ~= "TOPLEFT" then
            AnchorTop(frame) -- saved by an older version, by some other point
        end
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
        frame:SetUserPlaced(false) -- ns.db.trackerPoint is the one saved position
        AnchorTop(frame)
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

-- The nth click area of a section, over a line that does something when
-- clicked, made the first time it is needed.
local function ClickArea(section, n)
    section.buttons = section.buttons or {}
    local button = section.buttons[n]
    if not button then
        button = CreateFrame("Button", nil, section)
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.08)
        button:SetScript("OnClick", function(self)
            if self.entry and self.entry.onClick then
                self.entry.onClick()
            end
        end)
        button:SetScript("OnEnter", function(self)
            if self.entry and self.entry.tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                self.entry.tooltip(GameTooltip)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        section.buttons[n] = button
    end
    return button
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

-- What each section lists, as lines: { text, color, block, onClick, tooltip }.
-- A line with block starts a new block, set apart as Blizzard sets apart its
-- quests; the lines after it sit under it. A line with onClick can be
-- clicked, and tooltip(GameTooltip) fills its tooltip.

-- Talent points not spent yet, or nil when the client cannot say. Forever
-- uses Retail's trait system: the class tree's currency in the active
-- config, whose quantity is the points left to spend. Changes picked in the
-- talent window but not applied yet are left out, so they still count.
local function UnspentTalents()
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits) then
        return nil
    end
    local configID = C_ClassTalents.GetActiveConfigID()
    local config = configID and C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then
        return nil
    end
    local ok, currencies = pcall(C_Traits.GetTreeCurrencyInfo, configID, treeID, true)
    if not ok or not currencies then
        return nil
    end
    local count = 0
    for _, currency in ipairs(currencies) do
        count = count + (currency.quantity or 0)
    end
    return count
end

-- One line while you have talent points to spend.
local function TalentLines()
    local count = UnspentTalents()
    local text
    if count then
        if count > 0 then
            text = ("%d unspent talent%s"):format(count, count == 1 and "" or "s")
        end
    elseif C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints and C_ClassTalents.HasUnspentTalentPoints() then
        text = "Unspent talents" -- the count could not be read, only that there are some
    end
    if not text then
        return {}
    end
    return { { block = true, text = ns.CROSS .. " " .. text, color = ns.missing } }
end

-- A block per dungeon: its name in the dungeon teal and its level range,
-- then its quests.
local function DungeonLines()
    local lines = {}
    for _, entry in ipairs(ns.DungeonsToDo and ns.DungeonsToDo() or {}) do
        local dungeon = entry.dungeon
        lines[#lines + 1] = { block = true, color = ns.dungeonColor,
            text = ("%s %s(%d-%d)|r"):format(dungeon.name, ns.grey.hex, dungeon.minLevel or 0, dungeon.maxLevel or 0) }
        for _, row in ipairs(entry.rows) do
            local text, color = ns.QuestRowText(row)
            lines[#lines + 1] = { text = text, color = color }
        end
    end
    return lines
end

-- One line per quest item you can delete, with its icon and stack size.
local function QuestItemLines()
    local lines = {}
    for i, item in ipairs(ns.DeletableQuestItems and ns.DeletableQuestItems() or {}) do
        local icon = item.icon and ("|T" .. item.icon .. ":14:14|t ") or ""
        lines[#lines + 1] = { block = i == 1, color = ns.active,
            text = icon .. (item.link or ("item #" .. item.itemID)) .. (item.count > 1 and (" x" .. item.count) or ""),
            onClick = function()
                ns.ConfirmDeleteQuestItem(item.itemID)
            end,
            tooltip = function(tooltip)
                tooltip:SetItemByID(item.itemID)
                tooltip:AddLine("Click to delete", ns.grey.r, ns.grey.g, ns.grey.b)
            end }
    end
    return lines
end

-- "2g 40s" with the coin icons.
local function Money(copper)
    if GetMoneyString then
        return GetMoneyString(copper, true)
    end
    return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100)
end

-- One block of the class training you can learn now, then what they cost
-- together: white when you can pay it, red when you cannot. Skills without
-- a price add nothing, and with none priced there is no cost line.
local function ClassTrainingLines()
    local lines = {}
    for i, name in ipairs(ns.ClassTrainingToLearn and ns.ClassTrainingToLearn() or {}) do
        lines[#lines + 1] = { block = i == 1, text = ns.CROSS .. " " .. name, color = ns.missing }
    end
    if #lines > 0 and ns.ClassTrainingCost then
        local total = ns.ClassTrainingCost()
        if total > 0 then
            local short = GetMoney and GetMoney() < total
            lines[#lines + 1] = { block = true, color = short and ns.missing or { r = 1, g = 1, b = 1 },
                text = "Cost: " .. Money(total) }
        end
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

-- option is the setting that puts the section in the tracker, a "Show in
-- tracker" checkbox on the options window's Tracker tab.
SECTIONS = {
    { key = "talents", title = "Talents", option = "trackerTalents", lines = TalentLines },
    { key = "questItems", title = "Items to Delete", option = "trackerQuestItems", lines = QuestItemLines },
    { key = "dungeons", title = "Dungeons", option = "trackerDungeons", lines = DungeonLines },
    { key = "classTraining", title = "Class Training", option = "trackerClassTraining", lines = ClassTrainingLines },
    { key = "weaponSkills", title = "Weapon Skills", option = "trackerWeaponSkills", lines = WeaponSkillLines },
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
            local button = section.buttons and section.buttons[n]
            if entry.onClick then
                button = ClickArea(section, n)
                button.entry = entry
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", line, "TOPLEFT", -4, 2)
                button:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, -2)
                button:Show()
            elseif button then
                button:Hide()
            end
            y = y + line:GetStringHeight()
            used = n
        end
    end
    for n = used + 1, #section.lines do
        section.lines[n]:Hide()
    end
    for n = used + 1, #(section.buttons or {}) do
        section.buttons[n]:Hide()
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
    -- in it is not shown at all, and neither is one switched off.
    local height = HEADER_HEIGHT
    local above = tracker.Header
    for _, section in ipairs(tracker.sections) do
        local definition = section.definition
        local lines = not collapsed and ns.db[definition.option] ~= false and definition.lines() or {}
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
    "SPELLS_CHANGED", "SKILL_LINES_CHANGED", "TRAINER_SHOW", "TRAINER_UPDATE",
    -- Talent points gained or spent.
    "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "CHARACTER_POINTS_CHANGED",
    -- Whether you can pay for your training.
    "PLAYER_MONEY" }) do
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
