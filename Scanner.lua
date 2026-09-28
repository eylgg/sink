--------------------------------------------------------------------------------
-- Sink / Scanner.lua
--
-- A rare scanner, as far as Forever allows one. The game draws no minimap
-- marks for rares here, and a unit that is not loaded around you cannot be
-- looked for, so Sink watches what does come near: every nameplate that
-- appears, your mouseover and your target. When one is an NPC on the watch
-- list it puts a skull on it (once per spawn, so taking the skull off keeps
-- it off) and the tracker's Nearby section lists it; clicking the name there
-- targets it. Nothing is printed.
--
-- The watch list is built from the other files: rares with a map pin
-- (rare = true), quest elites whose quest you have not done (eliteQuest),
-- and NPCs a quest in your log still needs you at (Quests.lua objectives,
-- such as Mad Magglish for Trouble at the Docks).
--
-- GUIDs are secret in combat and in instances, so the scan works in the
-- open world out of combat, and needs enemy nameplates shown to see further
-- than your mouse. A stealthed NPC has no nameplate until you see through
-- it. One is dropped from Nearby when it dies, or half a minute after its
-- nameplate goes and nothing has shown it since; not while you are in
-- combat, so the tracker's click buttons stay where they are.
--------------------------------------------------------------------------------

local _, ns = ...

local SKULL = 8
local LINGER = 30 -- seconds one stays in Nearby after it was last seen

local nearby = {} -- npcID -> { name, why, guid, seen, plate }
local marked = {} -- GUID -> true once it has had its skull

local function Enabled()
    return ns.db ~= nil and ns.db.scanner ~= false
end

-- npcID -> why it is watched, for the rares and quest elites on the map.
local pinned
local function PinnedWatch(npcID)
    if not pinned then
        pinned = {}
        for _, pins in pairs(ns.mapPins or {}) do
            for _, pin in ipairs(pins) do
                if pin.npc and (pin.rare or pin.eliteQuest) then
                    pinned[pin.npc] = pin
                end
            end
        end
    end
    local pin = pinned[npcID]
    if not pin then
        return nil
    end
    if pin.rare then
        return "Rare"
    end
    if pin.quest and not C_QuestLog.IsQuestFlaggedCompleted(pin.quest) then
        return "Elite"
    end
    return nil
end

-- Why an NPC is watched, or nil when it is not.
local function Why(npcID)
    local why = PinnedWatch(npcID)
    if why then
        return why
    end
    if ns.IsObjectiveOpen and ns.IsObjectiveOpen(npcID) then
        local questID = ns.QuestsWithObjective(npcID)[1]
        return questID and ns.QuestTitle and ns.QuestTitle(questID) or "Quest"
    end
    return nil
end

local function Changed()
    if ns.RefreshTracker then
        ns.RefreshTracker()
    end
end

-- Look at a unit: a watched NPC is noted as nearby and gets its skull.
local function Check(unit, plate)
    if not Enabled() then
        return
    end
    local guid = UnitGUID(unit)
    local npcID = guid and not ns.Secret(guid) and ns.NPCIDFromGUID(guid)
    local why = npcID and Why(npcID)
    if not why then
        return
    end
    if UnitIsDead(unit) then
        if nearby[npcID] then
            nearby[npcID] = nil
            Changed()
        end
        return
    end
    local entry = nearby[npcID]
    local new = not entry or entry.guid ~= guid
    entry = entry or {}
    entry.name = ns.Readable(UnitName(unit)) or entry.name or (ns.npcs[npcID] and ns.npcs[npcID].name) or "?"
    entry.why, entry.guid, entry.seen = why, guid, GetTime()
    if plate then
        entry.plate = unit
    end
    nearby[npcID] = entry
    if ns.db.scannerSkull ~= false and not marked[guid] then
        marked[guid] = true
        if (GetRaidTargetIndex(unit) or 0) == 0 then
            pcall(SetRaidTarget, unit, SKULL)
        end
    end
    if new then
        Changed()
    end
end

-- Drop the ones that died or have not been seen for a while. Not in combat:
-- the tracker's click buttons cannot move then.
local function Expire()
    if InCombatLockdown() then
        return
    end
    local now, changed = GetTime(), false
    for npcID, entry in pairs(nearby) do
        local gone = entry.plate == nil and now - entry.seen > LINGER
        if entry.plate and UnitGUID(entry.plate) == entry.guid and UnitIsDead(entry.plate) then
            gone = true
        end
        if gone or not Why(npcID) then
            nearby[npcID] = nil
            changed = true
        end
    end
    if changed then
        Changed()
    end
end

-- Every nameplate shown now, as when combat ends and the GUIDs can be read again.
local function ScanPlates()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then
        return
    end
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then
            Check(unit, true)
        end
    end
end

-- What the tracker's Nearby section lists: { { npcID, name, why, seen } },
-- the one seen last first.
function ns.NearbyWatched()
    local list = {}
    for npcID, entry in pairs(nearby) do
        list[#list + 1] = { npcID = npcID, name = entry.name, why = entry.why, seen = entry.seen,
            here = entry.plate ~= nil }
    end
    table.sort(list, function(a, b)
        return a.seen > b.seen
    end)
    return list
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UPDATE_MOUSEOVER_UNIT",
    "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
    pcall(frame.RegisterEvent, frame, event) -- see Core.lua
end
frame:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Check(unit, true)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        for _, entry in pairs(nearby) do
            if entry.plate == unit then
                entry.plate, entry.seen = nil, GetTime()
            end
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Check("mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        Check("target")
    elseif event == "PLAYER_REGEN_ENABLED" then
        ScanPlates()
        Expire()
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(nearby)
        Changed()
    end
end)

C_Timer.NewTicker(5, Expire)
