--------------------------------------------------------------------------------
-- Sink / Fishing.lua
--
-- While a fishing pole is in your hands, the tracker's Fishing section shows
-- your Fishing skill, how often a catch raises it, and the zone's catch
-- rate: the skill the zone needs for no fish to get away, in brackets, green
-- when yours is enough, yellow with an estimate of how many you land when it
-- is not. Your skill for the catch rate counts the bonus from your pole and
-- lure, as the skill window shows it after the +. A zone not in the table
-- has no zone line.
--
-- The skill for each tier is from play; which zone is in which tier is not
-- yet checked in game.
--------------------------------------------------------------------------------

local _, ns = ...

local STARTING, CAPITAL, TIER2, TIER3, TIER4 = 25, 75, 150, 225, 300
-- local LEVEL_60 = 425 -- level 60+ zones, none listed yet

-- uiMapID -> skill.
local ZONES = {
    -- Starting zones
    [1429] = STARTING, -- Elwynn Forest
    [1426] = STARTING, -- Dun Morogh
    [1438] = STARTING, -- Teldrassil
    [1411] = STARTING, -- Durotar
    [1412] = STARTING, -- Mulgore
    [1420] = STARTING, -- Tirisfal Glades
    [2521] = STARTING, -- Zephras Isle
    -- Capital cities
    [1453] = CAPITAL, -- Stormwind City
    [1455] = CAPITAL, -- Ironforge
    [1457] = CAPITAL, -- Darnassus
    [1454] = CAPITAL, -- Orgrimmar
    [1456] = CAPITAL, -- Thunder Bluff
    [1458] = CAPITAL, -- Undercity
    -- Tier 2
    [1436] = TIER2, -- Westfall
    [1432] = TIER2, -- Loch Modan
    [1433] = TIER2, -- Redridge Mountains
    [1431] = TIER2, -- Duskwood
    [1437] = TIER2, -- Wetlands
    [1424] = TIER2, -- Hillsbrad Foothills
    [1421] = TIER2, -- Silverpine Forest
    [1439] = TIER2, -- Darkshore
    [1413] = TIER2, -- The Barrens
    [1440] = TIER2, -- Ashenvale
    [1442] = TIER2, -- Stonetalon Mountains
    -- Tier 3
    [1416] = TIER3, -- Alterac Mountains
    [1417] = TIER3, -- Arathi Highlands
    [1418] = TIER3, -- Badlands
    [1434] = TIER3, -- Stranglethorn Vale
    [1435] = TIER3, -- Swamp of Sorrows
    [1425] = TIER3, -- The Hinterlands
    [1441] = TIER3, -- Thousand Needles
    [1443] = TIER3, -- Desolace
    [1445] = TIER3, -- Dustwallow Marsh
    [1444] = TIER3, -- Feralas
    [1446] = TIER3, -- Tanaris
    [1447] = TIER3, -- Azshara
    [1448] = TIER3, -- Felwood
    [1449] = TIER3, -- Un'Goro Crater
    -- Tier 4
    [1419] = TIER4, -- Blasted Lands
    [1428] = TIER4, -- Burning Steppes
    [1430] = TIER4, -- Deadwind Pass
    [1422] = TIER4, -- Western Plaguelands
    [1423] = TIER4, -- Eastern Plaguelands
    [1452] = TIER4, -- Winterspring
    [1451] = TIER4, -- Silithus
    [1450] = TIER4, -- Moonglade
}

local FISHING_POLE = 20 -- Enum.ItemWeaponSubclass.Fishingpole
local MAIN_HAND = 16

local function Enabled()
    return ns.db ~= nil and ns.db.trackerFishing ~= false
end

-- Whether the item in your main hand is a fishing pole.
local function PoleEquipped()
    local itemID = GetInventoryItemID and GetInventoryItemID("player", MAIN_HAND)
    if not itemID then
        return false
    end
    local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not getInfo then
        return false
    end
    local _, _, _, _, _, classID, subclassID = getInfo(itemID)
    return classID == 2 and subclassID == FISHING_POLE
end

-- Your Fishing skill: the base, the bonus from your pole and lure, and the
-- most your rank allows (75 for Apprentice); nil without Fishing. The skill
-- window's list has the bonus and the cap; C_SkillInfo only the base.
local function Skill()
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, modifier, maxRank = GetSkillLineInfo(i)
            if not isHeader and name == "Fishing" then
                return rank or 0, modifier or 0, maxRank
            end
        end
    end
    local base = ns.ProfessionSkill and ns.ProfessionSkill("Fishing")
    if base then
        return base, 0, nil
    end
    return nil
end

-- The zone you are in that has a requirement: its name and skill. A cave or
-- district map counts as its zone; a dungeon does not.
local function Zone()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    while mapID do
        local info = C_Map.GetMapInfo(mapID)
        if not info or (Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Dungeon) then
            return nil
        end
        if ZONES[mapID] then
            return info.name, ZONES[mapID]
        end
        mapID = info.parentMapID ~= 0 and info.parentMapID or nil
    end
    return nil
end

-- The chance to land a fish, in percent, by the private-server formula
-- (TrinityCore): skill - zone level + 5, the zone level being the no-miss
-- skill - 95. Blizzard never published theirs, so it is an estimate; in
-- play it seems harsher at low skill.
local function CatchChance(have, need)
    return math.max(0, math.min(100, have - need + 100))
end

-- The chance a fish you land raises your skill a point, in percent, by the
-- same formula source: every catch below 75, then 2500 / (skill - 50).
-- It goes by your base skill; the zone and your bonus do not change it.
local function SkillUpChance(base)
    if base < 75 then
        return 100
    end
    return math.min(100, 2500 / (base - 50))
end

-- The tracker's text colour for plain lines, the objective tracker's grey-white.
local TEXT = { r = 0.8, g = 0.8, b = 0.8 }

-- The tracker's Fishing section while a pole is equipped:
--   Fishing Skill: 70 (45 + 25)
--   Skill-up Chance: 100%
--   [25] Tirisfal Glades: 100% catch
-- The zone line is green when no fish get away, yellow with the estimated
-- catch chance when some do, and left out in a zone not in the table.
function ns.FishingLines()
    if not Enabled() or not PoleEquipped() then
        return {}
    end
    local base, bonus, maxRank = Skill()
    if not base then
        return {}
    end
    local lines = {}
    lines[1] = { block = true, color = TEXT,
        text = bonus > 0 and ("Fishing Skill: %d (%d + %d)"):format(base + bonus, base, bonus)
            or ("Fishing Skill: %d"):format(base) }

    if maxRank and base >= maxRank then
        lines[2] = { color = ns.missing,
            text = maxRank >= 300 and "Skill-up Chance: none, at the most there is"
                or ("Skill-up Chance: none until you train past %d"):format(maxRank) }
    else
        local chance = SkillUpChance(base)
        lines[2] = { color = TEXT,
            text = chance >= 100 and "Skill-up Chance: 100%"
                or ("Skill-up Chance: ~%d%%"):format(math.floor(chance + 0.5)),
            tooltip = function(tooltip)
                tooltip:SetText("Skill-up Chance")
                tooltip:AddLine("How often a fish you land raises your Fishing a point. Fish that get away"
                    .. " give nothing.", 1, 1, 1, true)
                tooltip:AddLine("It goes by your skill without your pole and lure, and is the same in every"
                    .. " zone. An estimate, as the formula is not published.", ns.grey.r, ns.grey.g, ns.grey.b, true)
            end }
    end

    local zone, need = Zone()
    if zone then
        local have = base + bonus
        local chance = CatchChance(have, need)
        lines[3] = { color = chance >= 100 and ns.known or ns.active,
            text = chance >= 100 and ("[%d] %s: 100%% catch"):format(need, zone)
                or ("[%d] %s: ~%d%% catch"):format(need, zone, chance),
            tooltip = function(tooltip)
                tooltip:SetText(zone)
                tooltip:AddLine(("From Fishing %d, no fish here get away; yours is %d."):format(need, have),
                    1, 1, 1, true)
                tooltip:AddLine("Your pole and lure count toward it.", ns.grey.r, ns.grey.g, ns.grey.b, true)
                if chance < 100 then
                    tooltip:AddLine(("About %d%% of fish caught: an estimate, as the formula is not published.")
                        :format(chance), ns.grey.r, ns.grey.g, ns.grey.b, true)
                end
            end }
    end
    return lines
end

-- What "/sink dump fishing" prints: each thing the Fishing section checks.
function ns.FishingReport()
    local itemID = GetInventoryItemID and GetInventoryItemID("player", MAIN_HAND)
    local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local classID, subclassID
    if itemID and getInfo then
        classID, subclassID = select(6, getInfo(itemID))
    end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local zone, need = Zone()
    local base, bonus, maxRank = Skill()
    return {
        ("fishing: section %s, tracker %s"):format(Enabled() and "on" or "off (switched off)",
            ns.db and ns.db.tracker and "on" or "off"),
        ("fishing: main hand item %s, class %s, subclass %s, pole %s"):format(tostring(itemID), tostring(classID),
            tostring(subclassID), PoleEquipped() and "yes" or "no"),
        ("fishing: skill %s, bonus %s, rank cap %s; C_SkillInfo says %s"):format(tostring(base), tostring(bonus),
            tostring(maxRank), tostring(ns.ProfessionSkill and ns.ProfessionSkill("Fishing"))),
        ("fishing: map %s, zone %s needs %s"):format(tostring(mapID), tostring(zone), tostring(need)),
        ("fishing: %d line(s) for the tracker"):format(#ns.FishingLines()),
    }
end
