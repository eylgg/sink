--------------------------------------------------------------------------------
-- Sink / Tracker.lua
--
-- A window that looks like Blizzard's objective tracker, titled "Sink" and
-- the version. On by default: the Tracker tab of the options window or
-- "/sink tracker" turns it off. Drag its title to move it.
--
-- Its sections, each folded by clicking its header or its button, and hidden
-- while it has nothing to list:
--   Nearby         rares, quest elites and quest NPCs the scanner has seen
--                  close by (Scanner.lua); click one to target it
--   Current Dungeon the dungeon you are in, if Sink knows it: each boss ticked
--                  off as it dies, and your quests there with their objectives
--   Talents        how many talent points you have not spent, "2 unspent talents"
--   Tracking       Find Minerals and Find Herbs, while you know one and no
--                  tracking is on; click one to turn it on
--   Items to Delete quest items in your bags whose quests are complete
--                  (QuestItems.lua); click one to delete it, after a Delete /
--                  Keep question
--   Dungeons       every dungeon your level lets you enter that still has
--                  quests for you (Quests.lua), each quest with the same
--                  marks as the map tooltips; click a red one to see its
--                  giver on the world map, or a dungeon's name to fold its
--                  quests away
--   Class Training what your class trainer can teach you now, and the cost
--                  of it all, red when you cannot afford it (Trainers.lua);
--                  hover one for its tooltip, right-click it to ignore it
--                  and all its ranks
--   Weapon Skills  what a weapon master can teach you now, and in which
--                  city, and the cost as for Class Training (Weapons.lua)
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
local HideTargetButtons -- the Nearby click buttons, below with them

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
    local dragged = false
    header:SetScript("OnDragStart", function()
        dragged = true
        if not InCombatLockdown() then
            HideTargetButtons() -- they do not follow; they come back where it lands
        end
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        frame:SetUserPlaced(false) -- ns.db.trackerPoint is the one saved position
        AnchorTop(frame)
        ns.RefreshTracker()
    end)
    -- A left click that was not a drag opens the options window.
    header:SetScript("OnMouseUp", function(_, button)
        if dragged then
            dragged = false
        elseif button == "LeftButton" and ns.OpenOptions then
            ns.OpenOptions()
        end
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

-- The nth mouse area of a section, over a line that has a tooltip or does
-- something when clicked, made the first time it is needed.
local function ClickArea(section, n)
    section.buttons = section.buttons or {}
    local button = section.buttons[n]
    if not button then
        button = CreateFrame("Button", nil, section)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.08)
        button:SetScript("OnClick", function(self, mouseButton)
            local entry = self.entry
            if not entry then
                return
            end
            if mouseButton == "RightButton" then
                if entry.onRightClick then
                    GameTooltip:Hide()
                    entry.onRightClick(self)
                end
            elseif entry.onClick then
                entry.onClick()
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

-- What each section lists, as lines: { text, color, block, onClick,
-- onRightClick, tooltip }.
-- A line with block starts a new block, set apart as Blizzard sets apart its
-- quests; the lines after it sit under it. A line with onClick can be
-- clicked, one with onRightClick(owner) right-clicked, and tooltip(GameTooltip)
-- fills its tooltip.

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

-- While you are in a dungeon Sink knows: its name and how many bosses are
-- dead, each boss ticked off as it dies, then your quests there with their
-- objectives as your quest log counts them. A rare is not in the count, and
-- is grey until killed, as it may not be there. A quest item found in one of
-- several spots lists them under its quest: click one once you have looked
-- there and it goes grey, so the group does not look twice.
local function CurrentDungeonLines()
    local here = ns.CurrentDungeon and ns.CurrentDungeon()
    if not here then
        return {}
    end
    local dead, total = 0, 0
    for _, boss in ipairs(here.bosses) do
        if not boss.rare then
            total = total + 1
            if boss.dead then
                dead = dead + 1
            end
        end
    end
    local count = total > 0 and (" %s(%d/%d Bosses)|r"):format(ns.grey.hex, dead, total) or ""
    local lines = { { block = true, color = ns.dungeonColor, text = here.name .. count } }
    -- The bosses in order, then the rares at the bottom.
    for _, rares in ipairs({ false, true }) do
        for _, boss in ipairs(here.bosses) do
            if (boss.rare == true) == rares then
                local name = boss.rare and (boss.name .. " (Rare)") or boss.name
                if boss.dead then
                    lines[#lines + 1] = { text = ns.CHECK .. " " .. name, color = ns.known }
                elseif boss.rare then
                    lines[#lines + 1] = { text = name, color = ns.grey }
                else
                    lines[#lines + 1] = { text = ns.CROSS .. " " .. name, color = ns.missing }
                end
            end
        end
    end
    for i, quest in ipairs(here.quests) do
        local text, color = ns.QuestRowText(quest.row)
        lines[#lines + 1] = { block = i == 1, text = text, color = color }
        -- Each objective under its quest: white while open, green once done.
        for _, objective in ipairs(quest.objectives) do
            if objective.text and objective.text ~= "" then
                lines[#lines + 1] = { text = "      " .. objective.text,
                    color = objective.finished and ns.known or { r = 0.8, g = 0.8, b = 0.8 } }
            end
        end
        for _, spot in ipairs(quest.spots or {}) do
            lines[#lines + 1] = { text = "      " .. spot.name,
                color = spot.searched and ns.grey or { r = 0.8, g = 0.8, b = 0.8 },
                onClick = function()
                    ns.ToggleSearchedSpot(spot.index)
                end,
                tooltip = function(tooltip)
                    tooltip:SetText(spot.name, 1, 1, 1)
                    tooltip:AddLine(spot.where, 0.8, 0.8, 0.8, true)
                    tooltip:AddLine(spot.searched and "Click if you have not looked here after all"
                        or "Click once you have looked here", ns.grey.r, ns.grey.g, ns.grey.b)
                end }
        end
    end
    return lines
end

-- The gathering tracking spells: Find Minerals and Find Herbs.
local GATHERING_TRACKING = { [2580] = true, [2383] = true }

-- While no tracking spell is on, a line for each gathering one you know;
-- clicking it turns that one on. Hunter tracks and the like count as on, so
-- the section stays hidden while any of them is. The minimap's tracking list
-- (C_Minimap) has them all, with the spell, its icon and whether it is on;
-- turning one on through it is the same as casting the spell, and is not
-- protected. Other entries in that list, such as flight masters, are not
-- spells and do not count.
local function TrackingLines()
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo and C_Minimap.SetTracking) then
        return {}
    end
    local choices = {}
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if info and info.type == "spell" then
            if info.active then
                return {} -- some tracking is on already
            end
            if info.spellID and GATHERING_TRACKING[info.spellID] then
                choices[#choices + 1] = { index = index, name = info.name, texture = info.texture }
            end
        end
    end
    local lines = {}
    for i, choice in ipairs(choices) do
        lines[#lines + 1] = { block = i == 1, color = ns.missing,
            text = ("|T%s:14:14|t %s"):format(tostring(choice.texture), choice.name),
            onClick = function()
                C_Minimap.SetTracking(choice.index, true)
            end,
            tooltip = function(tooltip)
                tooltip:SetText(choice.name)
                tooltip:AddLine("Click to turn it on", ns.grey.r, ns.grey.g, ns.grey.b)
            end }
    end
    return lines
end

-- A block per dungeon: "[13-18] Ragefire Chasm (2/4 Quests)", the level range
-- first as the quest log has it and coloured for your level (Quests.lua),
-- the name in the dungeon teal, and of its
-- quests for your faction not finished yet, how many are in your log or start
-- inside; then the quests left.
local function DungeonLines()
    local lines = {}
    for _, entry in ipairs(ns.DungeonsToDo and ns.DungeonsToDo() or {}) do
        local dungeon = entry.dungeon
        -- Clicking the title folds the dungeon's quests away, saved like a section's.
        local key = "dungeon" .. entry.instanceID
        local folded = Folded(key)
        lines[#lines + 1] = { block = true, color = ns.dungeonColor,
            text = ("%s %s %s(%d/%d Quests)|r"):format(ns.DungeonRangeText(dungeon),
                dungeon.name, ns.grey.hex, entry.have, entry.total),
            onClick = function()
                ns.db.trackerFolded = ns.db.trackerFolded or {}
                ns.db.trackerFolded[key] = not folded or nil
                ns.RefreshTracker()
            end,
            tooltip = function(tooltip)
                tooltip:SetText(dungeon.name, ns.dungeonColor.r, ns.dungeonColor.g, ns.dungeonColor.b)
                tooltip:AddLine(folded and "Click to show its quests" or "Click to hide its quests",
                    ns.grey.r, ns.grey.g, ns.grey.b)
                tooltip:AddLine("Right-click to ignore", ns.grey.r, ns.grey.g, ns.grey.b)
            end,
            -- Leave it out of the section; the Ignored tab of the options window brings it back.
            onRightClick = function(owner)
                if not (MenuUtil and MenuUtil.CreateContextMenu) then
                    return
                end
                MenuUtil.CreateContextMenu(owner, function(_, root)
                    root:CreateTitle(dungeon.name)
                    root:CreateButton("Ignore", function()
                        ns.SetDungeonIgnored(entry.instanceID, true)
                    end)
                end)
            end }
        for _, row in ipairs(folded and {} or entry.rows) do
            local text, color = ns.QuestRowText(row)
            local line = { text = text, color = color }
            -- Click a quest to see its next step on the map: the giver to pick it
            -- up from, the NPC to turn it in to, or the dungeon to do it in. For a
            -- chain, the step you are on. Not for one your level is too low for.
            local next = not row.needsLevel and ns.QuestNextStep and ns.QuestNextStep(row.questID)
            if next and ns.ShowOnMap then
                line.onClick = function()
                    ns.ShowOnMap(next.place)
                end
                line.tooltip = function(tooltip)
                    local step = ns.QuestSeriesSuffix(next.questID)
                    tooltip:SetText(next.title .. (step and (" " .. step) or ""), 1, 1, 0)
                    local where = next.place.dungeonID and (ns.dungeonColor.hex .. next.place.name .. "|r")
                        or ("\"%s\" in %s"):format(next.place.name, ns.MapName and ns.MapName(next.place.map) or "?")
                    tooltip:AddLine(next.action .. " " .. where, 1, 1, 1)
                    if next.note then
                        tooltip:AddLine(next.note, ns.grey.r, ns.grey.g, ns.grey.b)
                    end
                    tooltip:AddLine("Click to show on the map", ns.grey.r, ns.grey.g, ns.grey.b)
                end
            end
            lines[#lines + 1] = line
        end
    end
    return lines
end

-- One line per quest item you can delete, with its icon and stack size.
local function QuestItemLines()
    local lines = {}
    for i, item in ipairs(ns.DeletableQuestItems and ns.DeletableQuestItems() or {}) do
        local icon = item.icon and ("|T" .. item.icon .. ":14:14|t ") or ""
        -- The link keeps its quality colour; the brackets around the name go.
        local name = item.link and item.link:gsub("%[(.-)%]", "%1") or ("item #" .. item.itemID)
        lines[#lines + 1] = { block = i == 1, color = ns.active,
            text = icon .. name .. (item.count > 1 and (" x" .. item.count) or ""),
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

-- A section's closing "Cost: 1g 20s" line: white when you can pay it, red when you cannot.
local function CostLine(total)
    local short = GetMoney and GetMoney() < total
    return { block = true, color = short and ns.missing or { r = 1, g = 1, b = 1 }, text = "Cost: " .. Money(total) }
end

-- One block of the class training you can learn now, then what they cost
-- together: white when you can pay it, red when you cannot. Skills without
-- a price add nothing, and with none priced there is no cost line.
local function ClassTrainingLines()
    local lines = {}
    for i, skill in ipairs(ns.ClassTrainingToLearn and ns.ClassTrainingToLearn() or {}) do
        lines[#lines + 1] = { block = i == 1, text = ns.CROSS .. " " .. skill.text, color = ns.missing,
            -- The spell's own tooltip, as the spellbook shows it.
            tooltip = function(tooltip)
                if skill.spell then
                    tooltip:SetSpellByID(skill.spell)
                else
                    tooltip:SetText(skill.text)
                end
                tooltip:AddLine("Right-click to ignore", ns.grey.r, ns.grey.g, ns.grey.b)
            end,
            -- Ignore every rank of it; the Ignored tab of the options window brings it back.
            onRightClick = function(owner)
                if not (MenuUtil and MenuUtil.CreateContextMenu) then
                    return
                end
                MenuUtil.CreateContextMenu(owner, function(_, root)
                    root:CreateTitle(skill.name)
                    root:CreateButton("Ignore", function()
                        ns.SetTrainingIgnored(skill.name, true)
                    end)
                end)
            end }
    end
    if #lines > 0 and ns.ClassTrainingCost then
        local total = ns.ClassTrainingCost()
        if total > 0 then
            lines[#lines + 1] = CostLine(total)
        end
    end
    return lines
end

-- One block of the weapon skills you can learn now, each with where, then
-- what they cost together as for Class Training. A skill without a price
-- adds nothing.
local function WeaponSkillLines()
    local lines, total = {}, 0
    for i, skill in ipairs(ns.WeaponSkillsToLearn and ns.WeaponSkillsToLearn() or {}) do
        lines[#lines + 1] = { block = i == 1, color = ns.missing,
            text = ("%s %s %s(%s)|r"):format(ns.CROSS, skill.name, ns.grey.hex, skill.where) }
        total = total + (skill.cost or 0)
    end
    if total > 0 then
        lines[#lines + 1] = CostLine(total)
    end
    return lines
end

-- option is the setting that puts the section in the tracker, a "Show in
-- tracker" checkbox on the options window's Tracker tab.
-- What the scanner has seen nearby (Scanner.lua): the skull and the name in
-- red, why it is watched in grey. Clicking one targets it, through a secure
-- button (see PlaceTargetButtons below).
local SKULL_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14:14|t "

local function NearbyLines()
    local lines = {}
    for i, npc in ipairs(ns.NearbyWatched and ns.NearbyWatched() or {}) do
        lines[#lines + 1] = { block = i == 1, color = ns.missing, target = npc.name,
            text = ("%s%s %s(%s)|r"):format(SKULL_ICON, npc.name, ns.grey.hex, npc.why),
            tooltip = function(tooltip)
                tooltip:SetText(npc.name, 1, 1, 1)
                tooltip:AddLine(npc.why, ns.grey.r, ns.grey.g, ns.grey.b)
                tooltip:AddLine(npc.here and "In sight now"
                    or ("Seen %d seconds ago"):format(GetTime() - npc.seen), ns.grey.r, ns.grey.g, ns.grey.b)
                tooltip:AddLine("Click to target", ns.grey.r, ns.grey.g, ns.grey.b)
            end }
    end
    return lines
end

SECTIONS = {
    { key = "nearby", title = "Nearby", option = "trackerNearby", lines = NearbyLines },
    { key = "currentDungeon", title = "Current Dungeon", option = "trackerCurrentDungeon", lines = CurrentDungeonLines },
    { key = "talents", title = "Talents", option = "trackerTalents", lines = TalentLines },
    { key = "tracking", title = "Tracking", option = "trackerTracking", lines = TrackingLines },
    { key = "questItems", title = "Items to Delete", option = "trackerQuestItems", lines = QuestItemLines },
    { key = "dungeons", title = "Dungeons", option = "trackerDungeons", lines = DungeonLines },
    { key = "classTraining", title = "Class Training", option = "trackerClassTraining", lines = ClassTrainingLines },
    { key = "weaponSkills", title = "Weapon Skills", option = "trackerWeaponSkills", lines = WeaponSkillLines },
}

-- Clicking a Nearby name targets that NPC. Targeting needs a secure button,
-- and addon code may only move or change one out of combat; a frame one is
-- anchored to is locked in combat as well, which would stop the tracker
-- laying itself out. So these buttons hang off UIParent, placed over their
-- lines after each layout out of combat, and go when combat starts
-- (PLAYER_REGEN_DISABLED comes just before the lockdown). In combat a
-- Nearby name is not clickable.
local targetButtons = {}
local targets = {} -- { { line, entry } } for the lines laid out this refresh

local function TargetButton(n)
    local button = targetButtons[n]
    if not button then
        button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
        button:SetAttribute("type", "macro")
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
        button:Hide()
        targetButtons[n] = button
    end
    return button
end

function HideTargetButtons()
    for _, button in ipairs(targetButtons) do
        button:Hide()
    end
end

local function PlaceTargetButtons()
    if InCombatLockdown() then
        return
    end
    for n, target in ipairs(targets) do
        local button, line = TargetButton(n), target.line
        local left, top = line:GetLeft(), line:GetTop()
        if left and top then
            button.entry = target.entry
            -- Clearing first makes the previous target the last target, which the
            -- last line puts back when the NPC is not found.
            button:SetAttribute("macrotext", table.concat({
                "/cleartarget",
                "/targetexact " .. target.entry.target,
                "/targetlasttarget [@target,noexists]",
            }, "\n"))
            button:SetFrameStrata(tracker:GetFrameStrata())
            button:SetFrameLevel(tracker:GetFrameLevel() + 50)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left - 4, top + 2)
            button:SetSize(line:GetWidth() + 4, line:GetStringHeight() + 4)
            button:Show()
        else
            TargetButton(n):Hide()
        end
    end
    for n = #targets + 1, #targetButtons do
        targetButtons[n]:Hide()
    end
end

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
            if entry.onClick or entry.onRightClick or entry.tooltip then
                button = ClickArea(section, n)
                button.entry = entry
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", line, "TOPLEFT", -4, 2)
                button:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, -2)
                button:Show()
            elseif button then
                button:Hide()
            end
            if entry.target then
                targets[#targets + 1] = { line = line, entry = entry }
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
    wipe(targets)
    if not tracker or not tracker:IsShown() then
        if not InCombatLockdown() then
            HideTargetButtons()
        end
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
    PlaceTargetButtons()
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
    "PLAYER_MONEY",
    -- Reputation, for the discount on weapon skills.
    "UPDATE_FACTION",
    -- Combat starting and ending, for the Nearby click buttons.
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    -- Minimap tracking turned on or off.
    "MINIMAP_UPDATE_TRACKING",
    -- Entering or leaving a dungeon, and its bosses dying, for Current Dungeon.
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_END" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event)
    if not Enabled() then
        return
    end
    if event == "PLAYER_LOGIN" then
        ns.ApplyTracker()
    elseif event == "PLAYER_REGEN_DISABLED" then
        HideTargetButtons() -- just before the lockdown, while that is still allowed
    elseif event == "PLAYER_LEVEL_UP" then
        -- UnitLevel still has the old level while this event runs.
        C_Timer.After(1, ns.RefreshTracker)
    else
        ns.RefreshTracker()
    end
end)
