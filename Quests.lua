--------------------------------------------------------------------------------
-- Sink / Quests.lua
--
-- One record per quest, NPC and dungeon, linked by ID, so each fact is written
-- once. MapPins.lua draws from them: a dungeon's entrance with its quests on
-- the tooltip, and a "Dungeon Quest" pin on each NPC who gives one.
--
-- A quest's start says how you get it:
--   { npc = id }   an NPC gives it; the NPC's record says where they stand
--   { drop = id }  an NPC drops the item that starts it; when that NPC is in
--                  the quest's dungeon it reads "Kill "The Baron" inside"
--   { item = id }  an item you loot starts it, one lying on the ground rather
--                  than dropped by an NPC; when the item is in the quest's
--                  dungeon it reads "Loot inside"
--   { after = id } offered once the quest before it is turned in
-- Quests linked by after make a series, and the objective tracker adds the
-- step to the end of each one's title: "Unending Torment (2/5)".
--
-- The tracker is Blizzard's Retail one (Blizzard_ObjectiveTracker). Each
-- quest is a block whose header QuestObjectiveTrackerMixin:UpdateSingle sets
-- on every update, so a hook after it finds the block and appends the step to
-- the header text. The block's height was measured on Blizzard's text; if the
-- longer title would wrap onto another line, Blizzard's title is put back so
-- the layout never breaks. Only the text is touched, nothing protected.
--------------------------------------------------------------------------------

local _, ns = ...

-- Dungeons by instance ID, the Map table's ID that GetInstanceInfo() returns
-- inside. The entrance is on uiMap map at x, y.
ns.dungeons = {
    [2999] = { name = "Ruins of Lordaeron", minLevel = 11, maxLevel = 24, map = 1458, x = 0.7261, y = 0.1148 },
}

-- NPCs that give or drop quests. One outside has a uiMap map and x, y; one
-- inside a dungeon has its instance ID.
ns.npcs = {
    [251001] = { name = "Deathguard Kristof", map = 1420, x = 0.6524, y = 0.6020 },
    [250660] = { name = "The Baron", instance = 2999 },
}

-- Items you loot from the ground that start a quest, by item ID, with the
-- instance ID of the dungeon they are found in.
ns.questItems = {
    [275521] = { name = "Crest of Lordaeron", instance = 2999 }, -- lies on the ground at random spots
}

-- Quests by ID. name stands in until the client has the quest cached;
-- faction is "Horde", "Alliance" or "Both" (the default); minLevel is the
-- level the quest asks for, where known, else the dungeon's is used; dungeon
-- is the instance ID of the dungeon the quest is for; start is how you get it.
ns.quests = {
    [92421] = { name = "Light's Justice", faction = "Horde", dungeon = 2999 },
    [95216] = { name = "The New Plague", faction = "Horde", dungeon = 2999 },
    [92422] = { name = "The Wrath of Rath'mael", faction = "Horde", dungeon = 2999, start = { npc = 251001 } },
    [95204] = { name = "Crest of Lordaeron", faction = "Horde", dungeon = 2999, start = { item = 275521 } },
    [97288] = { name = "Unending Torment", faction = "Horde", dungeon = 2999, start = { drop = 250660 } },
    [97289] = { name = "Unending Torment", faction = "Horde", start = { after = 97288 } },
    [97290] = { name = "Unending Torment", faction = "Horde", start = { after = 97289 } },
    [97291] = { name = "Unending Torment", faction = "Horde", start = { after = 97290 } },
    [97292] = { name = "Unending Torment", faction = "Horde", start = { after = 97291 } },
}

--------------------------------------------------------------------------------
-- Links, built once from the records above
--------------------------------------------------------------------------------

local questsByDungeon = {} -- instance ID -> { questID, ... }
local questsByGiver = {}   -- npcID -> { questID, ... }
local stepByQuest = {}     -- questID -> { step, count } for a quest in a series

local function Append(index, key, value)
    index[key] = index[key] or {}
    table.insert(index[key], value)
end

do
    local nextQuest = {} -- questID -> the quest that follows it
    for questID, quest in pairs(ns.quests) do
        local start = quest.start or {}
        if quest.dungeon then
            Append(questsByDungeon, quest.dungeon, questID)
        end
        if start.npc then
            Append(questsByGiver, start.npc, questID)
        end
        if start.after then
            nextQuest[start.after] = questID
        end
    end
    -- A series starts at a quest something follows but that follows nothing.
    for first in pairs(nextQuest) do
        local quest = ns.quests[first]
        if not (quest and quest.start and quest.start.after) then
            local chain, questID = {}, first
            while questID do
                chain[#chain + 1] = questID
                questID = nextQuest[questID]
            end
            for step, id in ipairs(chain) do
                stepByQuest[id] = { step = step, count = #chain }
            end
        end
    end
    for _, index in ipairs({ questsByDungeon, questsByGiver }) do
        for _, list in pairs(index) do
            table.sort(list)
        end
    end
end

-- "(2/5)" for a quest in a series, else nil.
function ns.QuestSeriesSuffix(questID)
    local entry = questID and stepByQuest[questID]
    return entry and ("(%d/%d)"):format(entry.step, entry.count) or nil
end

function ns.QuestsForDungeon(instanceID)
    return questsByDungeon[instanceID] or {}
end

function ns.QuestsFromGiver(npcID)
    return questsByGiver[npcID] or {}
end

-- Calls fn(npcID, npc) for every NPC who gives a quest.
function ns.EachQuestGiver(fn)
    for npcID in pairs(questsByGiver) do
        local npc = ns.npcs[npcID]
        if npc then
            fn(npcID, npc)
        end
    end
end

--------------------------------------------------------------------------------
-- Quest state
--------------------------------------------------------------------------------

-- The title the client has, else the name in the table, and ask the server so
-- the next call has the real one.
local function QuestTitle(questID)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    if title and title ~= "" then
        return title
    end
    if C_QuestLog.RequestLoadQuestByID then
        C_QuestLog.RequestLoadQuestByID(questID)
    end
    local quest = ns.quests[questID]
    return (quest and quest.name) or ("quest #" .. questID)
end

local NOT_TAKEN, IN_LOG, DONE = 1, 2, 3

local function QuestState(questID)
    if C_QuestLog.IsQuestFlaggedCompleted(questID) then
        return DONE
    end
    if C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID) then
        return IN_LOG
    end
    return NOT_TAKEN
end

local function ForMyFaction(quest)
    if not quest.faction or quest.faction == "Both" then
        return true
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return faction == nil or faction == quest.faction
end

-- The level a quest asks for: its own where known, else its dungeon's.
local function MinLevel(quest)
    local dungeon = quest.dungeon and ns.dungeons[quest.dungeon]
    return quest.minLevel or (dungeon and dungeon.minLevel) or 0
end

-- Whether a quest is there for you to pick up now: for your faction, neither
-- in your log nor done, and your level is high enough.
local function Available(questID)
    local quest = ns.quests[questID]
    local level = UnitLevel and UnitLevel("player") or 0
    return quest ~= nil and ForMyFaction(quest) and QuestState(questID) == NOT_TAKEN and level >= MinLevel(quest)
end

-- Whether an NPC has a quest for you now.
function ns.HasQuestToGive(npcID)
    for _, questID in ipairs(ns.QuestsFromGiver(npcID)) do
        if Available(questID) then
            return true
        end
    end
    return false
end

-- Of these quests, the ones you can go and pick up from an NPC who has a
-- place on the map, alphabetical: { questID, title, npcID, npc }. These are
-- the quests whose givers have a "Dungeon Quest" pin.
function ns.QuestsToFetch(questIDs)
    local list = {}
    for _, questID in ipairs(questIDs) do
        local start = ns.quests[questID] and ns.quests[questID].start
        local npc = start and start.npc and ns.npcs[start.npc]
        if npc and npc.map and Available(questID) then
            list[#list + 1] = { questID = questID, title = QuestTitle(questID), npcID = start.npc, npc = npc }
        end
    end
    table.sort(list, function(a, b)
        return a.title < b.title
    end)
    return list
end

-- How to get a quest that starts inside its own dungeon: 'Kill "The Baron"
-- inside' for a drop, "Loot inside" for an item on the ground. nil for any
-- other quest.
local function DropText(quest)
    local start = quest.start or {}
    local dropper = start.drop and ns.npcs[start.drop]
    if dropper and dropper.instance and dropper.instance == quest.dungeon then
        return ("Kill \"%s\" inside"):format(dropper.name)
    end
    local item = start.item and ns.questItems[start.item]
    if item and item.instance and item.instance == quest.dungeon then
        return "Loot inside"
    end
    return nil
end

--------------------------------------------------------------------------------
-- Tooltip lines
--------------------------------------------------------------------------------

-- One line per quest for your faction: red cross for one not in your log,
-- yellow waiting mark for one in it, green check for one done; in that
-- order, each group alphabetical. A quest that starts inside the dungeon,
-- from a drop or an item on the ground, is yellow until done, never red,
-- with how to get it after the name.
function ns.AddQuestLines(tooltip, questIDs)
    local rows = {}
    for _, questID in ipairs(questIDs) do
        local quest = ns.quests[questID]
        if quest and ForMyFaction(quest) then
            local state = QuestState(questID)
            local title = QuestTitle(questID)
            local drop = DropText(quest)
            if drop then
                title = title .. " (" .. drop .. ")"
                if state == NOT_TAKEN then
                    state = IN_LOG
                end
            end
            rows[#rows + 1] = { state = state, title = title }
        end
    end
    table.sort(rows, function(a, b)
        if a.state ~= b.state then
            return a.state < b.state
        end
        return a.title < b.title
    end)
    for _, row in ipairs(rows) do
        if row.state == NOT_TAKEN then
            tooltip:AddLine(ns.CROSS .. " " .. row.title, ns.missing.r, ns.missing.g, ns.missing.b)
        elseif row.state == IN_LOG then
            tooltip:AddLine(ns.WAIT .. " " .. row.title, ns.active.r, ns.active.g, ns.active.b)
        else
            tooltip:AddLine(ns.CHECK .. " " .. row.title, ns.known.r, ns.known.g, ns.known.b)
        end
    end
end

--------------------------------------------------------------------------------
-- The objective tracker
--------------------------------------------------------------------------------

local function AddSuffix(module, quest)
    local questID = quest and quest.GetID and quest:GetID()
    local suffix = ns.QuestSeriesSuffix(questID)
    if not suffix then
        return
    end
    local block = module.GetExistingBlock and module:GetExistingBlock(questID)
    local header = block and block.HeaderText
    local text = header and header:GetText()
    if not text or text:sub(-#suffix) == suffix then
        return
    end
    local height = header:GetHeight()
    header:SetText(text .. " " .. suffix)
    if header:GetHeight() > height + 0.5 then
        header:SetText(text) -- would wrap; keep Blizzard's layout
    end
end

-- The quest and campaign trackers both build their blocks through UpdateSingle.
local hooked = {}
local function Install()
    for _, module in ipairs({ QuestObjectiveTracker, CampaignQuestObjectiveTracker }) do
        if module and module.UpdateSingle and not hooked[module] then
            hooked[module] = true
            hooksecurefunc(module, "UpdateSingle", AddSuffix)
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and name == "Blizzard_ObjectiveTracker") then
        Install()
    end
end)
