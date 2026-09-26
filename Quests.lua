--------------------------------------------------------------------------------
-- Sink / Quests.lua
--
-- One record per quest, NPC and dungeon, linked by ID, so each fact is written
-- once. MapPins.lua draws from them: a dungeon's entrance with its quests on
-- the tooltip, and a "Dungeon Quest" pin on each NPC who gives one.
--
-- A quest's start says how you get it:
--   { npc = id }   an NPC gives it; the NPC's record says where they stand,
--                  and one inside the quest's dungeon reads 'Talk to "Nalpak" inside'
--   { drop = id }  an NPC drops the item that starts it (item = its ID, for
--                  reference); when that NPC is in the quest's dungeon it
--                  reads "Kill "The Baron" inside"
--   { item = id }  an item you loot starts it, one lying on the ground rather
--                  than dropped by an NPC; when the item is in the quest's
--                  dungeon it reads "Loot inside"
--   { after = id } offered once the quest before it is turned in; with npc as
--                  well, that NPC offers it then (Thrall gives Hidden Enemies
--                  1/5 and, once it is turned in, 2/5)
-- A quest's objective = { npc = id } is an NPC you go to while the quest is
-- in your log, such as Neeru Fireblade for Hidden Enemies 2/5; that NPC gets
-- a "Quest Objective" pin until the objective is done. finish = { npc = id }
-- is who takes the quest in; they get a "Turn In" pin once it is ready to
-- hand in.
--
-- Quests linked by after make a series, and the objective tracker adds the
-- step to the end of each one's title: "Unending Torment (2/5)". The map
-- tooltips add it too, except on the first quest of a series whose parts
-- all have their own names, where the name says enough.
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
-- inside. The entrance is on uiMap map at x, y; a continent map, as a dump
-- in a cave gives, is fine, the pin goes on the zone that point is in.
-- verified = true once the position was taken in game (see MapPins.lua).
ns.dungeons = {
    [2999] = { name = "Ruins of Lordaeron", minLevel = 11, maxLevel = 24, map = 1458, x = 0.7261, y = 0.1148,
        verified = true },
    [389] = { name = "Ragefire Chasm", minLevel = 10, maxLevel = 18, map = 1454, x = 0.5302, y = 0.4876,
        verified = true },
    -- Recorded on the Kalimdor map (1414); MapPins.lua draws it on the zone it lies in, The Barrens.
    -- Unverified until the converted spot on The Barrens has been checked in game.
    [43] = { name = "Wailing Caverns", minLevel = 15, maxLevel = 24, map = 1414, x = 0.5239, y = 0.5521 },
}

-- NPCs that give or drop quests. One outside has a uiMap map and x, y, and
-- verified = true once that position was taken in game (see MapPins.lua);
-- one inside a dungeon has its instance ID.
ns.npcs = {
    [251001] = { name = "Deathguard Kristof", map = 1420, x = 0.6524, y = 0.6020, verified = true },
    [250660] = { name = "The Baron", instance = 2999, verified = true },
    [4949] = { name = "Thrall", map = 1454, x = 0.3174, y = 0.3782, verified = true },
    [3216] = { name = "Neeru Fireblade", map = 1454, x = 0.4948, y = 0.5059, verified = true },
    -- From Wowhead's Forever database, not yet checked in game ("/sink dump npc unverified").
    [266484] = { name = "Morbin Lightbane", map = 1458, x = 0.574, y = 0.888 },
    [11835] = { name = "Theodore Griffs", map = 1458, x = 0.462, y = 0.704 },
    [2055] = { name = "Master Apothecary Faranell", map = 1458, x = 0.484, y = 0.694 },
    [271613] = { name = "Unfinished Abomination", map = 1458, x = 0.460, y = 0.622 },
    [2425] = { name = "Varimathras", map = 1458, x = 0.562, y = 0.924 },
    [7825] = { name = "Oran Snakewrithe", map = 1458, x = 0.734, y = 0.324 },
    [11833] = { name = "Rahauro", map = 1456, x = 0.694, y = 0.288 },
    [5769] = { name = "Arch Druid Hamuul Runetotem", map = 1456, x = 0.784, y = 0.284 },
    [5770] = { name = "Nara Wildmane", map = 1456, x = 0.752, y = 0.304 },
    [3419] = { name = "Apothecary Zamah", map = 1456, x = 0.224, y = 0.198 },
    [3448] = { name = "Tonga Runetotem", map = 1413, x = 0.522, y = 0.318 },
    [3446] = { name = "Mebok Mizzyrix", map = 1413, x = 0.624, y = 0.376 },
    [3665] = { name = "Crane Operator Bigglefuzz", map = 1413, x = 0.630, y = 0.374 },
    [8418] = { name = "Falla Sagewind", map = 1413, x = 0.482, y = 0.328 },
    [11834] = { name = "Maur Grimtotem", instance = 389 }, -- Wowhead has no position; his body lies inside
    [5768] = { name = "Ebru", instance = 43 }, -- beside Nalpak in the cave
    [5767] = { name = "Nalpak", instance = 43, verified = true },
    [3654] = { name = "Mutanus the Devourer", instance = 43, verified = true },
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
    [92421] = { name = "Light's Justice", faction = "Horde", minLevel = 15, dungeon = 2999,
        start = { npc = 266484 }, finish = { npc = 266484 } },
    [95216] = { name = "The New Plague", faction = "Horde", minLevel = 16, dungeon = 2999,
        start = { npc = 11835 }, finish = { npc = 11835 } },
    [92422] = { name = "The Wrath of Rath'mael", faction = "Horde", minLevel = 15, dungeon = 2999,
        start = { npc = 251001 }, finish = { npc = 251001 } },
    [95204] = { name = "Crest of Lordaeron", faction = "Horde", minLevel = 16, dungeon = 2999,
        start = { item = 275521 }, finish = { npc = 7825 } },
    [97288] = { name = "Unending Torment", faction = "Horde", minLevel = 16, dungeon = 2999,
        start = { drop = 250660 }, finish = { npc = 2055 } },
    [97289] = { name = "Unending Torment", faction = "Horde", minLevel = 16,
        start = { after = 97288, npc = 2055 }, finish = { npc = 271613 } },
    [97290] = { name = "Unending Torment", faction = "Horde",
        start = { after = 97289, npc = 271613 }, finish = { npc = 2055 } },
    [97291] = { name = "Unending Torment", faction = "Horde", minLevel = 16,
        start = { after = 97290, npc = 2055 }, finish = { npc = 2055 } },
    [97292] = { name = "Unending Torment", faction = "Horde", minLevel = 16,
        start = { after = 97291, npc = 2055 }, finish = { npc = 2055 } },
    -- Hidden Enemies: Thrall gives parts 1 to 3; part 2 sends you to Neeru Fireblade; part 3 is done in Ragefire Chasm.
    [5726] = { name = "Hidden Enemies", faction = "Horde", minLevel = 9,
        start = { npc = 4949 }, finish = { npc = 4949 } },
    [5727] = { name = "Hidden Enemies", faction = "Horde", minLevel = 9,
        start = { after = 5726, npc = 4949 }, objective = { npc = 3216 }, finish = { npc = 4949 } },
    [5728] = { name = "Hidden Enemies", faction = "Horde", minLevel = 9, dungeon = 389,
        start = { after = 5727, npc = 4949 }, finish = { npc = 4949 } },
    [5729] = { name = "Hidden Enemies", faction = "Horde",
        start = { after = 5728, npc = 4949 }, finish = { npc = 3216 } },
    [5730] = { name = "Hidden Enemies", faction = "Horde",
        start = { after = 5729, npc = 3216 }, finish = { npc = 4949 } },
    [5722] = { name = "Searching for the Lost Satchel", faction = "Horde", minLevel = 9, dungeon = 389,
        start = { npc = 11833 }, finish = { npc = 11834 } },
    [5724] = { name = "Returning the Lost Satchel", faction = "Horde", minLevel = 9,
        start = { after = 5722, npc = 11834 }, finish = { npc = 11833 } },
    [5761] = { name = "Slaying the Beast", faction = "Horde", minLevel = 9, dungeon = 389,
        start = { npc = 3216 }, finish = { npc = 3216 } },
    [5725] = { name = "The Power to Destroy...", faction = "Horde", minLevel = 9, dungeon = 389,
        start = { npc = 2425 }, finish = { npc = 2425 } },
    [5723] = { name = "Testing an Enemy's Strength", faction = "Horde", minLevel = 9, dungeon = 389,
        start = { npc = 11833 }, finish = { npc = 11833 } },
    [1487] = { name = "Deviate Eradication", minLevel = 15, dungeon = 43,
        start = { npc = 5768 }, finish = { npc = 5768 } },
    [1486] = { name = "Deviate Hides", minLevel = 13, dungeon = 43,
        start = { npc = 5767 }, finish = { npc = 5767 } },
    [1489] = { name = "Hamuul Runetotem", faction = "Horde", minLevel = 10,
        start = { npc = 3448 }, finish = { npc = 5769 } },
    [1490] = { name = "Nara Wildmane", faction = "Horde", minLevel = 10,
        start = { after = 1489, npc = 5769 }, finish = { npc = 5770 } },
    [914] = { name = "Leaders of the Fang", faction = "Horde", minLevel = 10, dungeon = 43,
        start = { after = 1490, npc = 5770 }, finish = { npc = 5770 } },
    [962] = { name = "Serpentbloom", faction = "Horde", minLevel = 14, dungeon = 43,
        start = { npc = 3419 }, finish = { npc = 3419 } },
    [1491] = { name = "Smart Drinks", minLevel = 13, dungeon = 43,
        start = { npc = 3446 }, finish = { npc = 3446 } },
    [959] = { name = "Trouble at the Docks", minLevel = 14, dungeon = 43,
        start = { npc = 3665 }, finish = { npc = 3665 } },
    -- Mutanus drops the Glowing Shard (item 10441) that starts it.
    [6981] = { name = "The Glowing Shard", minLevel = 15, dungeon = 43,
        start = { drop = 3654, item = 10441 }, finish = { npc = 8418 } },
}

--------------------------------------------------------------------------------
-- Links, built once from the records above
--------------------------------------------------------------------------------

local questsByDungeon = {} -- instance ID -> { questID, ... }
local questsByGiver = {}   -- npcID -> { questID, ... }
local questsByObjective = {} -- npcID -> { questID, ... } for NPCs a quest sends you to
local questsByFinish = {}  -- npcID -> { questID, ... } for NPCs who take a quest in
local stepByQuest = {}     -- questID -> { step, count, uniqueNames } for a quest in a series

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
        if quest.objective and quest.objective.npc then
            Append(questsByObjective, quest.objective.npc, questID)
        end
        if quest.finish and quest.finish.npc then
            Append(questsByFinish, quest.finish.npc, questID)
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
            -- Whether every part has its own name (the Lost Satchel); the map
            -- tooltips leave the first step off those.
            local names, unique = {}, true
            for _, id in ipairs(chain) do
                local name = ns.quests[id] and ns.quests[id].name or id
                unique = unique and not names[name]
                names[name] = true
            end
            for step, id in ipairs(chain) do
                stepByQuest[id] = { step = step, count = #chain, uniqueNames = unique }
            end
        end
    end
    for _, index in ipairs({ questsByDungeon, questsByGiver, questsByObjective, questsByFinish }) do
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

function ns.QuestsWithObjective(npcID)
    return questsByObjective[npcID] or {}
end

function ns.QuestsFinishedAt(npcID)
    return questsByFinish[npcID] or {}
end

local function EachNPCIn(index, fn)
    for npcID in pairs(index) do
        local npc = ns.npcs[npcID]
        if npc then
            fn(npcID, npc)
        end
    end
end

-- Calls fn(npcID, npc) for every NPC a quest sends you to.
function ns.EachObjectiveNPC(fn)
    EachNPCIn(questsByObjective, fn)
end

-- Calls fn(npcID, npc) for every NPC who takes a quest in.
function ns.EachFinishNPC(fn)
    EachNPCIn(questsByFinish, fn)
end

-- Whether any quest an NPC gives is for a dungeon: their pin says "Dungeon
-- Quest" then, "Quest" otherwise.
function ns.GivesDungeonQuest(npcID)
    for _, questID in ipairs(ns.QuestsFromGiver(npcID)) do
        if ns.quests[questID].dungeon then
            return true
        end
    end
    return false
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

-- The level a quest asks for: its own where known, else its dungeon's, else none.
local function MinLevel(quest)
    local dungeon = quest.dungeon and ns.dungeons[quest.dungeon]
    return quest.minLevel or (dungeon and dungeon.minLevel) or 0
end

-- Whether a quest is there for you to pick up now: for your faction, neither
-- in your log nor done, your level is high enough, and the quest before it,
-- if any, is turned in.
local function Available(questID)
    local quest = ns.quests[questID]
    if not quest then
        return false
    end
    local after = quest.start and quest.start.after
    if after and not C_QuestLog.IsQuestFlaggedCompleted(after) then
        return false
    end
    local level = UnitLevel and UnitLevel("player") or 0
    return ForMyFaction(quest) and QuestState(questID) == NOT_TAKEN and level >= MinLevel(quest)
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

-- Where a quest's chain begins for you: back along after to the earliest
-- quest whose one before it is done, and that quest when an NPC gives it.
-- nil when that quest has no giver.
local function ChainStart(questID)
    local quest = ns.quests[questID]
    local start = quest and quest.start or {}
    if start.after and not C_QuestLog.IsQuestFlaggedCompleted(start.after) then
        return ChainStart(start.after)
    end
    if start.npc then
        return questID
    end
    return nil
end

-- Whether a quest in your log still needs you at its objective NPC. With
-- objectives, until they are complete; a talk-to quest with none is complete
-- as soon as it is taken, and talking to the NPC turns it in, so until then.
local function ObjectiveOpen(questID)
    local quest = ns.quests[questID]
    if not (quest and ForMyFaction(quest)) or QuestState(questID) ~= IN_LOG then
        return false
    end
    local count = C_QuestLog.GetNumQuestObjectives and C_QuestLog.GetNumQuestObjectives(questID) or 0
    if count > 0 and C_QuestLog.IsComplete then
        return not C_QuestLog.IsComplete(questID)
    end
    return true
end

-- Whether a quest in your log is ready to hand in: its objectives are
-- complete, or it has none, as a talk-to quest.
local function ReadyToTurnIn(questID)
    local quest = ns.quests[questID]
    if not (quest and ForMyFaction(quest)) or QuestState(questID) ~= IN_LOG then
        return false
    end
    local count = C_QuestLog.GetNumQuestObjectives and C_QuestLog.GetNumQuestObjectives(questID) or 0
    return count == 0 or (C_QuestLog.IsComplete ~= nil and C_QuestLog.IsComplete(questID))
end

-- Whether an NPC takes in a quest you can hand in now.
function ns.HasQuestToTurnIn(npcID)
    for _, questID in ipairs(ns.QuestsFinishedAt(npcID)) do
        if ReadyToTurnIn(questID) then
            return true
        end
    end
    return false
end

-- Whether an NPC is the objective of a quest you are on now.
function ns.IsObjectiveOpen(npcID)
    for _, questID in ipairs(ns.QuestsWithObjective(npcID)) do
        if ObjectiveOpen(questID) then
            return true
        end
    end
    return false
end

-- Where to go for a quest you have not taken: { questID, title, npcID, npc },
-- the quest to pick up and the NPC who gives it, when that NPC has a place on
-- the map; else nil. For a follow-up it is the first quest of its chain you
-- still need, such as Hidden Enemies 1/5 or 2/5 from Thrall for the Ragefire
-- Chasm part. The Sink tracker shows it when you click a red quest.
function ns.QuestToFetch(questID)
    if QuestState(questID) ~= NOT_TAKEN then
        return nil
    end
    local fetchID = ChainStart(questID)
    local start = fetchID and ns.quests[fetchID].start
    local npc = start and ns.npcs[start.npc]
    if not (npc and npc.map and Available(fetchID)) then
        return nil
    end
    return { questID = fetchID, title = QuestTitle(fetchID), npcID = start.npc, npc = npc }
end

-- How to get a quest that starts inside its own dungeon: 'Talk to
-- "Nalpak" inside' from an NPC, 'Kill "The Baron" inside' for a drop, "Loot
-- inside" for an item on the ground. nil for any other quest.
local function DropText(quest)
    local start = quest.start or {}
    local giver = start.npc and ns.npcs[start.npc]
    if giver and giver.instance and giver.instance == quest.dungeon then
        return ("Talk to \"%s\" inside"):format(giver.name)
    end
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
-- Quest lines, for the map tooltips and the Sink tracker
--------------------------------------------------------------------------------

-- One row per quest for your faction, { state, title }, sorted: not taken,
-- then in your log, then done, each group alphabetical. A quest in a series
-- has its step after the name, "Hidden Enemies (3/5)", except on the first
-- quest of a series whose parts all have their own names or that starts
-- inside the dungeon. A quest that starts inside the dungeon, from an NPC, a
-- drop or an item on the ground, counts as in your log until done, never not
-- taken, with how to get it after the name.
local function QuestRows(questIDs)
    local rows = {}
    for _, questID in ipairs(questIDs) do
        local quest = ns.quests[questID]
        if quest and ForMyFaction(quest) then
            local state = QuestState(questID)
            local title = QuestTitle(questID)
            local drop = DropText(quest)
            -- A series that starts inside needs no "(1/5)": how to get it says enough.
            local step = ns.QuestSeriesSuffix(questID)
            local entry = stepByQuest[questID]
            -- The first step says nothing when the name or how to get it already
            -- marks the start; later steps show there are quests to do first.
            if step and not (entry.step == 1 and (entry.uniqueNames or drop)) then
                title = title .. " " .. step
            end
            if drop then
                title = title .. " (" .. drop .. ")"
                if state == NOT_TAKEN then
                    state = IN_LOG
                end
            end
            rows[#rows + 1] = { state = state, title = title, questID = questID }
        end
    end
    table.sort(rows, function(a, b)
        if a.state ~= b.state then
            return a.state < b.state
        end
        return a.title < b.title
    end)
    return rows
end

-- A row as text with its mark, and its colour: red cross for not taken,
-- yellow waiting mark for in your log, green check for done.
function ns.QuestRowText(row)
    if row.state == NOT_TAKEN then
        return ns.CROSS .. " " .. row.title, ns.missing
    elseif row.state == IN_LOG then
        return ns.WAIT .. " " .. row.title, ns.active
    end
    return ns.CHECK .. " " .. row.title, ns.known
end

function ns.AddQuestLines(tooltip, questIDs)
    for _, row in ipairs(QuestRows(questIDs)) do
        local text, color = ns.QuestRowText(row)
        tooltip:AddLine(text, color.r, color.g, color.b)
    end
end

-- The dungeons you can enter, your level at least theirs, that still have
-- quests for you, sorted by level: { instanceID, dungeon, rows, have, total }.
-- rows are the quests not done, leaving out any your level is still too low
-- for. total counts the dungeon's quests for your faction you have not
-- finished yet, and have the ones of them in your log.
function ns.DungeonsToDo()
    local level = UnitLevel and UnitLevel("player") or 0
    local list = {}
    for instanceID, dungeon in pairs(ns.dungeons) do
        if level >= (dungeon.minLevel or 0) then
            local rows, have, total = {}, 0, 0
            for _, row in ipairs(QuestRows(ns.QuestsForDungeon(instanceID))) do
                if row.state ~= DONE then
                    total = total + 1
                    -- Its real state: a quest that starts inside shows as in your log before you have it.
                    if QuestState(row.questID) == IN_LOG then
                        have = have + 1
                    end
                    if level >= MinLevel(ns.quests[row.questID]) then
                        rows[#rows + 1] = row
                    end
                end
            end
            if #rows > 0 then
                list[#list + 1] = { instanceID = instanceID, dungeon = dungeon, rows = rows, have = have, total = total }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.dungeon.minLevel ~= b.dungeon.minLevel then
            return (a.dungeon.minLevel or 0) < (b.dungeon.minLevel or 0)
        end
        return a.dungeon.name < b.dungeon.name
    end)
    return list
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
