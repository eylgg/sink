--------------------------------------------------------------------------------
-- Sink / Hunts.lua
--
-- Treasure hunts: chains of objects in the world, each a quest that starts at
-- one object and ends at the next, as the hunt for the Cozy Sleeping Bag.
-- The map gets one pin for a hunt, at the next place to go: where the next
-- step starts, or, with a step in your log, where it ends. Which step you are
-- on comes from the quests you have completed, so nothing is saved. The pin
-- is a Quest NPCs kind of pin, and goes once the hunt is done.
--
-- Steps and objects from Wowhead's Forever database; the directions from a
-- player's guide. Not checked in game yet.
--------------------------------------------------------------------------------

local _, ns = ...

-- A hunt: { name, level, steps = { { quest, faction, start, finish } } }. start
-- and finish are { map, x, y, object, hint }. A step with a faction is that
-- side's only; the hunt's first steps differ by side.
ns.hunts = {
    {
        name = "Cozy Sleeping Bag", level = 14,
        steps = {
            { quest = 79007, faction = "Horde",
              start = { map = 1413, x = 0.464, y = 0.739, object = "Burned-Out Remains" },
              finish = { map = 1436, x = 0.375, y = 0.507, object = "Burned-Out Remains" } },
            { quest = 79008, faction = "Alliance",
              start = { map = 1436, x = 0.375, y = 0.507, object = "Burned-Out Remains" },
              finish = { map = 1413, x = 0.464, y = 0.739, object = "Burned-Out Remains" } },
            -- Stepping Stones starts at the Nailed Plank where the first step ended.
            { quest = 79192, faction = "Horde",
              start = { map = 1436, x = 0.375, y = 0.508, object = "Nailed Plank" },
              finish = { map = 1442, x = 0.408, y = 0.526, object = "Pocket Litter",
                         hint = "From the road at 51, 51, follow the opening into the mountains to the camp" } },
            { quest = 79192, faction = "Alliance",
              start = { map = 1413, x = 0.464, y = 0.738, object = "Nailed Plank" },
              finish = { map = 1442, x = 0.408, y = 0.526, object = "Pocket Litter",
                         hint = "From the road at 51, 51, follow the opening into the mountains to the camp" } },
            { quest = 79980,
              start = { map = 1442, x = 0.408, y = 0.526, object = "Pocket Litter" },
              finish = { map = 1442, x = 0.396, y = 0.499, object = "Mound of Dirt",
                         hint = "Run through the camp and jump down the mountain to the ledge" } },
            { quest = 79974,
              start = { map = 1442, x = 0.396, y = 0.499, object = "Mound of Dirt" },
              finish = { map = 1432, x = 0.495, y = 0.128, object = "Carved Figurine",
                         hint = "At the dam: jump down to the ledge" } },
            { quest = 79975,
              start = { map = 1432, x = 0.495, y = 0.128, object = "Carved Figurine" },
              finish = { map = 1417, x = 0.225, y = 0.242, object = "Messenger Bag",
                         hint = "From Hillsbrad (81, 56), face the gate to Arathi and turn left along the wall to"
                             .. " the fallen cart, then up the little jumping puzzle to the camp" } },
            { quest = 79976,
              start = { map = 1417, x = 0.225, y = 0.242, object = "Messenger Bag" },
              finish = { map = 1417, x = 0.225, y = 0.242, object = "Hastily Rolled-Up Satchel",
                         hint = "Beside the Messenger Bag" } },
        },
    },
}

local function ForMyFaction(step)
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    return not step.faction or not mine or step.faction == mine
end

local function InLog(questID)
    return C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID) ~= nil
end

-- Where to go next in a hunt: { place, action, step, count }, or nil once it
-- is done or your level is too low for it.
local function NextStop(hunt)
    local level = UnitLevel and UnitLevel("player") or 0
    if hunt.level and level < hunt.level then
        return nil
    end
    local steps = {}
    for _, step in ipairs(hunt.steps) do
        if ForMyFaction(step) then
            steps[#steps + 1] = step
        end
    end
    for index, step in ipairs(steps) do
        if not C_QuestLog.IsQuestFlaggedCompleted(step.quest) then
            if InLog(step.quest) then
                return { place = step.finish, action = "Then find", step = index, count = #steps, inLog = true }
            end
            return { place = step.start, action = "Find", step = index, count = #steps }
        end
    end
    return nil
end

-- The pins for a map: each hunt's next stop, if it is on this map.
function ns.HuntPins(mapID)
    local pins = {}
    for _, hunt in ipairs(ns.hunts) do
        local stop = NextStop(hunt)
        if stop and stop.place.map == mapID then
            pins[#pins + 1] = { name = stop.place.object, note = ("%s (%d/%d)"):format(hunt.name, stop.step, stop.count),
                x = stop.place.x, y = stop.place.y, hunt = true, hint = stop.place.hint, faction = "Both",
                huntAction = stop.action, atlas = stop.inLog and "QuestTurnin" or "QuestNormal" }
        end
    end
    return pins
end

-- A hunt pin's tooltip, under its "Cozy Sleeping Bag (3/6)" title: what to
-- look for, and the directions.
function ns.AddHuntLines(tooltip, pin)
    tooltip:AddLine(pin.huntAction .. " the " .. pin.name, 1, 1, 1)
    if pin.hint then
        tooltip:AddLine(pin.hint, ns.grey.r, ns.grey.g, ns.grey.b, true)
    end
end

-- A step taken or done moves the pin on.
local frame = CreateFrame("Frame")
for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do
    pcall(frame.RegisterEvent, frame, event) -- see Core.lua
end
frame:SetScript("OnEvent", function()
    if ns.RefreshMapPins then
        ns.RefreshMapPins()
    end
end)
