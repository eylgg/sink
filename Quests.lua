--------------------------------------------------------------------------------
-- Sink / Quests.lua
--
-- One record per quest, NPC and dungeon, linked by ID, so each fact is written
-- once. MapPins.lua draws from them: a dungeon's entrance with its quests on
-- the tooltip, and a "Dungeon Quest" pin on each NPC who gives one.
--
-- A quest's start says how you get it:
--   { npc = id }   an NPC gives it; the NPC's record says where they stand,
--                  and one inside the quest's dungeon reads 'Talk to "Ghostly Attendant" inside'
--   { drop = id }  an NPC drops the item that starts it (item = its ID, for
--                  reference); when that NPC is in the quest's dungeon it
--                  reads "Kill "The Baron" inside"
--   { item = id }  an item you loot starts it, one lying on the ground rather
--                  than dropped by an NPC; when the item is in the quest's
--                  dungeon it reads "Loot inside"
--   { after = id } offered once the quest before it is turned in; with npc as
--                  well, that NPC offers it then (Thrall gives Hidden Enemies
--                  1/5 and, once it is turned in, 2/5). Quests linked by
--                  after are one series, with steps: "(2/5)".
--   { needs = id } offered once another quest is turned in, one that is not a
--                  step of the same series: Raptor Horns before Smart Drinks.
--                  With npc as well, like after.
-- A quest's objective = { npc = id } is an NPC you go to while the quest is
-- in your log, such as Neeru Fireblade for Hidden Enemies 2/5; that NPC gets
-- a "Quest Objective" pin until the objective is done. With item = id as
-- well, the NPC is where you get that item, and the pin goes once the quest's
-- objective for that item is done, even while others are not. A quest with
-- several such NPCs lists them: objective = { { npc = id, item = id }, ... }. finish = { npc = id }
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
-- inside. minLevel and maxLevel are the recommended range, the one shown: the
-- game's Looking for Group range where it has been read there, as for Ruins of
-- Lordaeron, Wailing Caverns, Deadmines, Hall of Thanes and Shadowfang Keep;
-- entryLevel, where known, is the lowest level the game lets in, and without
-- it minLevel counts as that. The entrance is on uiMap map at x, y; a continent map, as a dump
-- in a cave gives, is fine, the pin goes on the zone that point is in. A
-- dungeon without map has no pin until its entrance is recorded.
-- verified = true once the position was taken in game (see MapPins.lua).
ns.dungeons = {
    [2999] = { name = "Ruins of Lordaeron", minLevel = 15, maxLevel = 22, entryLevel = 10, map = 1458, x = 0.7261, y = 0.1148,
        verified = true },
    [389] = { name = "Ragefire Chasm", minLevel = 13, maxLevel = 18, entryLevel = 10, map = 1454, x = 0.5302, y = 0.4876,
        verified = true },
    -- The cave mouth at the Lushwater Oasis, The Barrens 46, 36, from a comment on
    -- Wowhead's Wailing Caverns page (Wowhead has no position of its own); the
    -- portal inside is at 47.7, 35.0. Unverified until checked in game.
    [43] = { name = "Wailing Caverns", minLevel = 15, maxLevel = 24, map = 1413, x = 0.4600, y = 0.3600 },
    -- Neither entrance checked in game yet.
    -- Deadmines: the entrance in Moonbrook, Westfall.
    [36] = { name = "Deadmines", minLevel = 17, maxLevel = 26, map = 1436, x = 0.4250, y = 0.7170 },
    -- The Hall of Thanes: under Ironforge, through a portal at the bottom of Old
    -- Ironforge; placed on Ironforge's spot on the Dun Morogh map, as Wowhead's guide marks it.
    -- Levels as the game's Looking for Group shows them.
    [3065] = { name = "The Hall of Thanes", minLevel = 13, maxLevel = 20, map = 1426, x = 0.5240, y = 0.3780 },
    -- Levels from Wowhead's Forever dungeon overview, except Shadowfang Keep's. Entrances from the game's
    -- Map table, where your corpse is sent when you die inside, converted to the
    -- zone map; checked against Ragefire Chasm and Wailing Caverns, whose
    -- entrances were taken in game.
    [33] = { name = "Shadowfang Keep", minLevel = 20, maxLevel = 30, map = 1421, x = 0.4472, y = 0.6777 },
    [34] = { name = "Stormwind Stockade", minLevel = 22, maxLevel = 30, map = 1453, x = 0.5035, y = 0.6618 },
    [48] = { name = "Blackfathom Deeps", minLevel = 24, maxLevel = 32, map = 1440, x = 0.1650, y = 0.1103 },
    -- Excavation Site: Wetlands is new in Forever: neither the game data nor
    -- Wowhead has its entrance yet, so it has no map pin until one is recorded.
    [2998] = { name = "Excavation Site: Wetlands", minLevel = 24, maxLevel = 29 },
    -- Taken in game on the Kalimdor map; the Map table's corpse point converts to
    -- the same spot. Levels from Wowhead's Forever dungeon overview.
    [47] = { name = "Razorfen Kraul", minLevel = 30, maxLevel = 40, map = 1414, x = 0.5090, y = 0.7037,
        verified = true },
    -- New in Forever and not in this client's Map table yet, so it has no
    -- instance ID: keyed by name until it does. Levels from Wowhead's Forever
    -- dungeon overview; the portal was taken in game.
    kroldok = { name = "Krol'dok Stronghold", minLevel = 40, maxLevel = 45, map = 2548, x = 0.3746, y = 0.3733,
        verified = true },
}

-- Each dungeon's bosses in order, from the game's DungeonEncounter table: by
-- instance ID, then by the difficulty GetInstanceInfo reports (0 is any), a
-- list of { id, name }. id is the encounter ID ENCOUNTER_END gives when the
-- boss dies; rare = true for one that is not always there, which the
-- tracker lists apart from the boss count. Blackfathom Deeps has three versions.
ns.dungeonBosses = {
    [48] = { -- Blackfathom Deeps
        [1] = {
            { id = 2916, name = "Ghamoo-ra" },
            { id = 2915, name = "Lady Sarevess" },
            { id = 2914, name = "Geilhast" },
            { id = 2913, name = "Lorgus Jett" },
            { id = 2912, name = "Old Serra'kis" },
            { id = 2911, name = "Twilight Lord Kelris" },
            { id = 2910, name = "Aku'mai" },
        },
        [198] = {
            { id = 2694, name = "Baron Aquanis" },
            { id = 2697, name = "Ghamoo-ra" },
            { id = 2699, name = "Lady Sarevess" },
            { id = 2704, name = "Gelihast" },
            { id = 2710, name = "Lorgus Jett" },
            { id = 2825, name = "Twilight Lord Kelris" },
            { id = 2891, name = "Aku'mai" },
        },
        [201] = {
            { id = 2761, name = "Ghamoo-ra" },
            { id = 2762, name = "Lady Sarevess" },
            { id = 2763, name = "Geilhast" },
            { id = 2764, name = "Lorgus Jett" },
            { id = 2765, name = "Old Serra'kis" },
            { id = 2766, name = "Twilight Lord Kelris" },
            { id = 2767, name = "Aku'mai" },
        },
    },
    [36] = { -- Deadmines
        [0] = {
            { id = 2741, name = "Rhahk'Zor" },
            { id = 2742, name = "Sneed" },
            { id = 2743, name = "Gilnid" },
            { id = 2744, name = "Captain Greenskin" },
            { id = 2745, name = "Mr. Smite" },
            { id = 2746, name = "Cookie" },
            { id = 2747, name = "Edwin VanCleef" },
        },
    },
    [2998] = { -- Excavation Site: Wetlands
        [0] = {
            { id = 3480, name = "Saltspine" },
            { id = 3481, name = "Shadetooth" },
            { id = 3644, name = "Highland Horror" },
            { id = 3482, name = "Relic Guardian" },
        },
    },
    [389] = { -- Ragefire Chasm
        [0] = {
            { id = 2732, name = "Oggleflint" },
            { id = 2733, name = "Taragaman the Hungerer" },
            { id = 2734, name = "Jergosh the Invoker" },
            { id = 2735, name = "Bazzalan" },
        },
    },
    [47] = { -- Razorfen Kraul
        [0] = {
            { id = 2773, name = "Roogug" },
            { id = 2774, name = "Aggem Thorncurse" },
            { id = 2775, name = "Death Speaker Jargba" },
            { id = 2776, name = "Overlord Ramtusk" },
            { id = 2777, name = "Agathelos the Raging" },
            { id = 2778, name = "Charlga Razorflank" },
        },
    },
    [2999] = { -- Ruins of Lordaeron
        [0] = {
            { id = 3353, name = "Witherfang" },
            { id = 3357, name = "The Abandoned" },
            { id = 3355, name = "The Butcher" },
            { id = 3354, name = "Rath'mael" },
            { id = 3408, name = "Lordaeron Captain", rare = true },
            { id = 3411, name = "Viktor the Vile" },
            { id = 3412, name = "Bjork" },
        },
    },
    [33] = { -- Shadowfang Keep
        [0] = {
            { id = 2748, name = "Rethilgore" },
            { id = 2749, name = "Razorclaw the Butcher" },
            { id = 2750, name = "Baron Silverlaine" },
            { id = 2751, name = "Commander Springvale" },
            { id = 2752, name = "Odo the Blindwatcher" },
            { id = 2753, name = "Fenrus the Devourer" },
            { id = 2754, name = "Wolf Master Nandos" },
            { id = 2755, name = "Archmage Arugal" },
        },
    },
    [34] = { -- Stormwind Stockade
        [0] = {
            { id = 2756, name = "Targorr the Dread" },
            { id = 2757, name = "Kam Deepfury" },
            { id = 2758, name = "Hamhock" },
            { id = 2759, name = "Dextren Ward" },
            { id = 2760, name = "Bazil Thredd" },
        },
    },
    [3065] = { -- The Hall of Thanes
        [0] = {
            { id = 3493, name = "Faldrim Anvilmar" },
            { id = 3495, name = "Infurnus" },
            { id = 3494, name = "Plunder" },
            { id = 3496, name = "Durgen Dirgehammer" },
        },
    },
    [43] = { -- Wailing Caverns
        [0] = {
            { id = 585, name = "Lady Anacondra" },
            { id = 586, name = "Lord Cobrahn" },
            { id = 587, name = "Kresh" },
            { id = 588, name = "Lord Pythas" },
            { id = 589, name = "Skum" },
            { id = 590, name = "Lord Serpentis" },
            { id = 591, name = "Verdan the Everliving" },
            { id = 592, name = "Mutanus the Devourer" },
        },
    },
}

-- NPCs that give or drop quests. One outside has a uiMap map and x, y, and
-- verified = true once that position was taken in game (see MapPins.lua);
-- one inside a dungeon has its instance ID. One that spawns in one of
-- several places lists the others as spots = { { x, y }, ... } on the same
-- map, each drawn as a pin of its own, and hint says how to find them.
ns.npcs = {
    [251001] = { name = "Deathguard Kristof", map = 1420, x = 0.6524, y = 0.6020, verified = true },
    [250660] = { name = "The Baron", instance = 2999, verified = true },
    [4585] = { name = "Ezekiel Graves", map = 1458, x = 0.7520, y = 0.5118, verified = true },
    [4554] = { name = "Tawny Grisette", map = 1458, x = 0.6605, y = 0.3822, verified = true },
    [4949] = { name = "Thrall", map = 1454, x = 0.3174, y = 0.3782, verified = true },
    [3216] = { name = "Neeru Fireblade", map = 1454, x = 0.4948, y = 0.5059, verified = true },
    -- From Wowhead's Forever database, not yet checked in game ("/sink dump npc unverified").
    [266484] = { name = "Morbin Lightbane", map = 1458, x = 0.574, y = 0.888 },
    [11835] = { name = "Theodore Griffs", map = 1458, x = 0.462, y = 0.704 },
    [2055] = { name = "Master Apothecary Faranell", map = 1458, x = 0.484, y = 0.694 },
    [271613] = { name = "Unfinished Abomination", map = 1458, x = 0.460, y = 0.622 },
    [2425] = { name = "Varimathras", map = 1458, x = 0.562, y = 0.924 },
    [7825] = { name = "Oran Snakewrithe", map = 1458, x = 0.734, y = 0.324 },
    [15991] = { name = "Lady Dena Kennedy", map = 1453, x = 0.640, y = 0.060 }, -- wanders; one of two spots Wowhead has
    [11833] = { name = "Rahauro", map = 1456, x = 0.694, y = 0.288 },
    [5769] = { name = "Arch Druid Hamuul Runetotem", map = 1456, x = 0.784, y = 0.284 },
    [5770] = { name = "Nara Wildmane", map = 1456, x = 0.752, y = 0.304 },
    [3419] = { name = "Apothecary Zamah", map = 1456, x = 0.224, y = 0.198 },
    [3448] = { name = "Tonga Runetotem", map = 1413, x = 0.522, y = 0.318 },
    [3446] = { name = "Mebok Mizzyrix", map = 1413, x = 0.624, y = 0.376 },
    [3665] = { name = "Crane Operator Bigglefuzz", map = 1413, x = 0.630, y = 0.374 },
    -- In the cave outside Wailing Caverns, not the instance: the three places
    -- Wowhead's sightings group into.
    [3655] = { name = "Mad Magglish", map = 1413, x = 0.465, y = 0.354, spots = { { 0.450, 0.352 }, { 0.461, 0.366 } },
        hint = "Stealthed, in one of 3 spots in the cave outside the instance" },
    [8418] = { name = "Falla Sagewind", map = 1413, x = 0.482, y = 0.328 },
    [11834] = { name = "Maur Grimtotem", instance = 389 }, -- Wowhead has no position; his body lies inside
    -- Outside Wailing Caverns, not in it; the positions were taken on the Kalimdor map.
    [5768] = { name = "Ebru", map = 1414, x = 0.5192, y = 0.5544, verified = true },
    [5767] = { name = "Nalpak", map = 1414, x = 0.5191, y = 0.5542, verified = true },
    [3654] = { name = "Mutanus the Devourer", instance = 43, verified = true },
    -- From Wowhead's Forever database, for the dungeon quests above; not checked in game.
    [234] = { name = "Gryan Stoutmantle", map = 1436, x = 0.5620, y = 0.4750 },
    [270] = { name = "Councilman Millstipe", map = 1431, x = 0.7200, y = 0.4780 },
    [466] = { name = "General Marcus Jonathan", map = 1453, x = 0.6474, y = 0.7686 },
    [639] = { name = "Edwin VanCleef", instance = 36 },
    [656] = { name = "Wilder Thistlenettle", map = 1453, x = 0.6665, y = 0.2610 },
    [820] = { name = "Scout Riell", map = 1436, x = 0.5660, y = 0.4740 },
    [859] = { name = "Guard Berton", map = 1433, x = 0.2650, y = 0.4650 },
    [1074] = { name = "Motley Garmason", map = 1437, x = 0.4960, y = 0.1820 },
    [1646] = { name = "Baros Alexston", map = 1453, x = 0.5330, y = 0.3900 },
    [1719] = { name = "Warden Thelwater", map = 1453, x = 0.4127, y = 0.5773 },
    [1721] = { name = "Nikova Raskol", map = 1453, x = 0.7180, y = 0.4596 },
    [1938] = { name = "Dalar Dawnweaver", map = 1421, x = 0.4422, y = 0.3978, verified = true },
    [1952] = { name = "High Executor Hadrec", map = 1421, x = 0.4342, y = 0.4086, verified = true },
    [2784] = { name = "King Magni Bronzebeard", map = 1455, x = 0.3960, y = 0.5550 },
    [2786] = { name = "Gerrig Bonegrip", map = 1455, x = 0.5044, y = 0.0600 },
    [2934] = { name = "Keeper Bel'dugur", map = 1458, x = 0.5373, y = 0.5400 },
    [4444] = { name = "Deathstalker Vincent", instance = 33 },
    [4783] = { name = "Dawnwatcher Selgorm", map = 1457, x = 0.5573, y = 0.2413 },
    [4784] = { name = "Argent Guard Manados", map = 1457, x = 0.5533, y = 0.2373 },
    [4786] = { name = "Dawnwatcher Shaedlass", map = 1457, x = 0.5550, y = 0.2450 },
    [4787] = { name = "Argent Guard Thaelrid", instance = 48 },
    [6181] = { name = "Jordan Stilwell", map = 1426, x = 0.5250, y = 0.3680 },
    [6247] = { name = "Doan Karhan", map = 1413, x = 0.4920, y = 0.5720 },
    [6579] = { name = "Shoni the Shilent", map = 1453, x = 0.5692, y = 0.1684 },
    [8997] = { name = "Gershala Nightwhisper", map = 1439, x = 0.3840, y = 0.4300 },
    [9087] = { name = "Bashana Runetotem", map = 1456, x = 0.7067, y = 0.3340 },
    [12736] = { name = "Je'neu Sancrea", map = 1440, x = 0.1160, y = 0.3420 },
    [12876] = { name = "Baron Aquanis", instance = 48 },
    [14450] = { name = "Orphan Matron Nightingale", map = 1453, x = 0.4960, y = 0.4255 },
    [250686] = { name = "Tabitha Heartweaver", map = 1421, x = 0.4450, y = 0.4290 },
    [264936] = { name = "Earthseer Farsen", map = 1426, x = 0.6480, y = 0.5840 },
    [264943] = { name = "Afadra Dunwall", map = 1455, x = 0.3331, y = 0.4774 },
    [265002] = { name = "Ghostly Attendant", instance = 3065 },
    [265003] = { name = "Thom Filch", map = 1455, x = 0.3215, y = 0.4473 },
}

-- The Crest of Lordaeron hangs in one of these, a different one each run,
-- from a Wowhead comment that confirmed each. The dungeon has no map
-- position, so they are words: name for the tracker line, where for its tooltip.
local CREST_SPOTS = {
    { name = "East tower, top floor", where = "On the wall left of the top floor doors. The tower is in the SW corner"
        .. " of Witherfang's courtyard, by the fountain in front of The Baron; its only door is on the alley"
        .. " you come in by. A window from Witherfang's courtyard is a shortcut to it." },
    { name = "Crypt by the east tower", where = "On the pitch black wall behind the closed crypt doors in front of"
        .. " The Baron, by the broken statue SE of the Throne Room. A banshee comes out. A dark square on the"
        .. " minimap." },
    { name = "SW tower, top floor", where = "On the wall left of the top floor doors. The tower is in the NW corner"
        .. " of The Abandoned's courtyard, north of Viktor the Vile; it has two doors." },
    { name = "NW tower, bottom", where = "In front of the split staircase north of Rath'mael, where Bjork patrols." },
    { name = "Gazebo, far NW", where = "On the wall of the gazebo-like building in the far NW of the dungeon, where"
        .. " Bjork patrols. A dark square on the minimap." },
}

-- Items you loot from the ground that start a quest, by item ID, with the
-- instance ID of the dungeon they are found in, and spots when it is in one
-- of several places: the tracker lists them to tick off while you search.
ns.questItems = {
    [275521] = { name = "Crest of Lordaeron", instance = 2999, spots = CREST_SPOTS }, -- Horde
    [268579] = { name = "Crest of Lordaeron", instance = 2999, spots = CREST_SPOTS }, -- Alliance
}

-- Quests by ID. name stands in until the client has the quest cached;
-- faction is "Horde", "Alliance" or "Both" (the default); class, when set, is
-- the one class that can take it ("PALADIN"); minLevel is the
-- level the quest asks for, where known, else the dungeon's is used; dungeon
-- is the instance ID of the dungeon the quest is for, and outside = true when
-- it is done in the dungeon's caves but outside the instance, as Smart Drinks
-- in Wailing Caverns; start is how you get it.
ns.quests = {
    [92421] = { name = "Light's Justice", faction = "Horde", minLevel = 15, dungeon = 2999,
        start = { npc = 266484 }, finish = { npc = 266484 } },
    [95216] = { name = "The New Plague", faction = "Horde", minLevel = 15, dungeon = 2999,
        start = { npc = 11835 }, finish = { npc = 11835 } },
    [92422] = { name = "The Wrath of Rath'mael", faction = "Horde", minLevel = 15, dungeon = 2999,
        start = { npc = 251001 }, finish = { npc = 251001 } },
    [95204] = { name = "Crest of Lordaeron", faction = "Horde", minLevel = 15, dungeon = 2999,
        start = { item = 275521 }, finish = { npc = 7825 } },
    [97288] = { name = "Unending Torment", faction = "Horde", minLevel = 15, dungeon = 2999,
        start = { drop = 250660 }, finish = { npc = 2055 } },
    [97289] = { name = "Unending Torment", faction = "Horde", minLevel = 15,
        start = { after = 97288, npc = 2055 }, finish = { npc = 271613 } },
    [97290] = { name = "Unending Torment", faction = "Horde",
        start = { after = 97289, npc = 271613 }, finish = { npc = 2055 } },
    [97291] = { name = "Unending Torment", faction = "Horde", minLevel = 15,
        start = { after = 97290, npc = 2055 }, finish = { npc = 2055 },
        -- Blisterweed (281300), the third, lies on the ground near the herbalism trainer.
        objective = {
            { npc = 4554, item = 281246 }, -- Toxic Skullcap
            { npc = 4585, item = 8923 }, -- Essence of Agony
        } },
    [97292] = { name = "Unending Torment", faction = "Horde", minLevel = 15,
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
    -- Tonga's oasis series comes before Hamuul Runetotem: Altered Beings, its last step, is needed first.
    -- The Barrens Oases (886), which Wowhead puts first, is not needed for any of it.
    [870] = { name = "The Forgotten Pools", faction = "Horde", minLevel = 10,
        start = { npc = 3448 }, finish = { npc = 3448 } },
    [877] = { name = "The Stagnant Oasis", faction = "Horde", minLevel = 10,
        start = { after = 870, npc = 3448 }, finish = { npc = 3448 } },
    [880] = { name = "Altered Beings", faction = "Horde", minLevel = 10,
        start = { after = 877, npc = 3448 }, finish = { npc = 3448 } },
    [1489] = { name = "Hamuul Runetotem", faction = "Horde", minLevel = 13,
        start = { needs = 880, npc = 3448 }, finish = { npc = 5769 } },
    [1490] = { name = "Nara Wildmane", faction = "Horde", minLevel = 10,
        start = { after = 1489, npc = 5769 }, finish = { npc = 5770 } },
    [914] = { name = "Leaders of the Fang", faction = "Horde", minLevel = 10, dungeon = 43,
        start = { after = 1490, npc = 5770 }, finish = { npc = 5770 } },
    [962] = { name = "Serpentbloom", faction = "Horde", minLevel = 14, dungeon = 43,
        start = { npc = 3419 }, finish = { npc = 3419 } },
    [865] = { name = "Raptor Horns", minLevel = 13, -- before Smart Drinks, done outside
        start = { npc = 3446 }, finish = { npc = 3446 } },
    [1491] = { name = "Smart Drinks", minLevel = 13, dungeon = 43, outside = true,
        start = { needs = 865, npc = 3446 }, finish = { npc = 3446 } },
    [959] = { name = "Trouble at the Docks", minLevel = 14, dungeon = 43, outside = true,
        start = { npc = 3665 }, objective = { npc = 3655, item = 5334 }, -- 99-Year-Old Port
        finish = { npc = 3665 } },
    -- Mutanus drops the Glowing Shard (item 10441) that starts it.
    [6981] = { name = "The Glowing Shard", minLevel = 15, dungeon = 43,
        start = { drop = 3654, item = 10441 }, finish = { npc = 8418 } },
    -- The Hall of Thanes, from Wowhead's Forever database and dungeon quest guide.
    [96403] = { name = "Important Heirlooms", faction = "Alliance", minLevel = 10, dungeon = 3065,
        start = { npc = 265003 }, finish = { npc = 265003 } },
    [96394] = { name = "The Restless Dead", faction = "Alliance", minLevel = 10, dungeon = 3065,
        start = { npc = 264943 }, finish = { npc = 264943 } },
    [96393] = { name = "Old Ironforge Incursion", faction = "Alliance", minLevel = 9, dungeon = 3065,
        start = { after = 96391, npc = 264936 }, finish = { npc = 2784 } },
    [98423] = { name = "The Treaty of Understanding", faction = "Alliance", minLevel = 9, dungeon = 3065,
        start = {}, finish = { npc = 2784 } },
    [96395] = { name = "An Ancient Grudge", minLevel = 10,
        dungeon = 3065, start = { npc = 265002 } },
    -- Deadmines, from Wowhead's Forever database and dungeon quest guide.
    [168] = { name = "Collecting Memories", faction = "Alliance", minLevel = 14, dungeon = 36,
        start = { npc = 656 }, finish = { npc = 656 } },
    [167] = { name = "Oh Brother...", faction = "Alliance", minLevel = 15, dungeon = 36,
        start = { npc = 656 }, finish = { npc = 656 } },
    [2040] = { name = "Underground Assault", faction = "Alliance", minLevel = 15, dungeon = 36,
        start = { npc = 6579 }, finish = { npc = 6579 } },
    [373] = { name = "The Unsent Letter", faction = "Alliance", minLevel = 16, dungeon = 36,
        start = { drop = 639 }, finish = { npc = 1646 } },
    [214] = { name = "Red Silk Bandanas", faction = "Alliance", minLevel = 14, dungeon = 36,
        start = { after = 65, npc = 820 }, finish = { npc = 820 } },
    [166] = { name = "The Defias Brotherhood", faction = "Alliance", minLevel = 14, dungeon = 36,
        start = { after = 65, npc = 234 }, finish = { npc = 234 } },
    [1654] = { name = "The Test of Righteousness", faction = "Alliance", class = "PALADIN", minLevel = 20, dungeon = 36,
        start = { npc = 6181 }, finish = { npc = 6181 } },
    -- Ruins of Lordaeron, from Wowhead's Forever database and dungeon quest guide.
    [92401] = { name = "A Frightened Request", faction = "Horde", minLevel = 15, dungeon = 2999,
        start = { npc = 250686 }, finish = { npc = 250686 } },
    [95250] = { name = "Abominable Creatures", faction = "Alliance", minLevel = 15,
        dungeon = 2999, start = {} },
    [95189] = { name = "Crest of Lordaeron", faction = "Alliance", minLevel = 15, dungeon = 2999,
        start = { item = 268579 }, finish = { npc = 15991 } },
    [95195] = { name = "Bloodied Insignia", faction = "Alliance", minLevel = 15, dungeon = 2999,
        start = {}, finish = { npc = 466 } },
    [92415] = { name = "Remember That I Love You", faction = "Alliance", minLevel = 15, dungeon = 2999,
        start = {}, finish = { npc = 14450 } },
    -- Shadowfang Keep, from Wowhead's Forever database and dungeon quest guide.
    [1013] = { name = "The Book of Ur", faction = "Horde", minLevel = 16, dungeon = 33,
        start = { npc = 2934 }, finish = { npc = 2934 } },
    [1098] = { name = "Deathstalkers in Shadowfang", faction = "Horde", minLevel = 18, dungeon = 33,
        start = { npc = 1952 }, finish = { npc = 4444 } },
    [1014] = { name = "Arugal Must Die", faction = "Horde", minLevel = 18, dungeon = 33,
        start = { npc = 1938 }, finish = { npc = 1938 } },
    [1740] = { name = "The Orb of Soran'ruk", class = "WARLOCK", minLevel = 20, dungeon = 33,
        start = { npc = 6247 }, finish = { npc = 6247 } },
    -- Blackfathom Deeps, from Wowhead's Forever database and dungeon quest guide.
    [6563] = { name = "The Essence of Aku'Mai", faction = "Horde", minLevel = 17, dungeon = 48,
        start = { npc = 12736 }, finish = { npc = 12736 } },
    [6561] = { name = "Blackfathom Villainy", faction = "Horde", minLevel = 18, dungeon = 48,
        start = { npc = 4787 }, finish = { npc = 9087 } },
    [6921] = { name = "Amongst the Ruins", faction = "Horde", minLevel = 21, dungeon = 48,
        start = { npc = 12736 }, finish = { npc = 12736 } },
    [6922] = { name = "Baron Aquanis", faction = "Horde", minLevel = 21, dungeon = 48,
        start = { drop = 12876 }, finish = { npc = 12736 } },
    [6565] = { name = "Allegiance to the Old Gods", faction = "Horde", minLevel = 17, dungeon = 48,
        start = { npc = 12736 }, finish = { npc = 12736 } },
    [971] = { name = "Knowledge in the Deeps", faction = "Alliance", minLevel = 10, dungeon = 48,
        start = { npc = 2786 }, finish = { npc = 2786 } },
    [1275] = { name = "Researching the Corruption", faction = "Alliance", minLevel = 18, dungeon = 48,
        start = { npc = 8997 }, finish = { npc = 8997 } },
    [1199] = { name = "Twilight Falls", faction = "Alliance", minLevel = 20, dungeon = 48,
        start = { npc = 4784 }, finish = { npc = 4784 } },
    [1198] = { name = "In Search of Thaelrid", faction = "Alliance", minLevel = 18, dungeon = 48,
        start = { npc = 4786 }, finish = { npc = 4787 } },
    [1200] = { name = "Blackfathom Villainy", faction = "Alliance", minLevel = 18, dungeon = 48,
        start = { after = 1198, npc = 4787 }, finish = { npc = 4783 } },
    -- Stormwind Stockade, from Wowhead's Forever database and dungeon quest guide.
    [387] = { name = "Quell the Uprising", faction = "Alliance", minLevel = 22, dungeon = 34,
        start = { npc = 1719 }, finish = { npc = 1719 } },
    [388] = { name = "The Color of Blood", faction = "Alliance", minLevel = 22, dungeon = 34,
        start = { npc = 1721 }, finish = { npc = 1721 } },
    [377] = { name = "Crime and Punishment", faction = "Alliance", minLevel = 22, dungeon = 34,
        start = { npc = 270 }, finish = { npc = 270 } },
    [386] = { name = "What Comes Around...", faction = "Alliance", minLevel = 22, dungeon = 34,
        start = { npc = 859 }, finish = { npc = 859 } },
    [378] = { name = "The Fury Runs Deep", faction = "Alliance", minLevel = 22, dungeon = 34,
        start = { after = 303, npc = 1074 }, finish = { npc = 1074 } },
    -- Its line is The Unsent Letter (373), Bazil Thredd (389), then this.
    [391] = { name = "The Stockade Riots", faction = "Alliance", minLevel = 16, dungeon = 34,
        start = { after = 389, npc = 1719 }, finish = { npc = 1719 } },
}

--------------------------------------------------------------------------------
-- Links, built once from the records above
--------------------------------------------------------------------------------

local questsByDungeon = {} -- instance ID -> { questID, ... }
local questsByGiver = {}   -- npcID -> { questID, ... }
local questsByObjective = {} -- npcID -> { questID, ... } for NPCs a quest sends you to
local questsByFinish = {}  -- npcID -> { questID, ... } for NPCs who take a quest in
local stepByQuest = {}     -- questID -> { step, count, uniqueNames } for a quest in a series
local followUp = {}        -- questID -> the quest that follows it
local unlocks = {}         -- questID -> the quest that needs it first, outside its series

local function Append(index, key, value)
    index[key] = index[key] or {}
    table.insert(index[key], value)
end

-- A quest's objective NPCs as a list, whether it names one or several.
function ns.QuestObjectiveNPCs(quest)
    local objective = quest.objective
    if not objective then
        return {}
    end
    return objective.npc and { objective } or objective
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
        for _, objective in ipairs(ns.QuestObjectiveNPCs(quest)) do
            Append(questsByObjective, objective.npc, questID)
        end
        if quest.finish and quest.finish.npc then
            Append(questsByFinish, quest.finish.npc, questID)
        end
        if start.after then
            nextQuest[start.after] = questID
            followUp[start.after] = questID
        end
        if start.needs then
            unlocks[start.needs] = questID
        end
    end
    -- A series starts at a quest something follows but that follows nothing.
    -- A prerequisite with no record here (Red Silk Bandanas' chain starts with
    -- quest 65) is not a series: only its last step is known.
    for first in pairs(nextQuest) do
        local quest = ns.quests[first]
        if quest and not (quest.start and quest.start.after) then
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

-- Quests for a dungeon, and the quests before them in their chains and
-- the ones they need first: Hamuul Runetotem is not done in Wailing Caverns,
-- but it starts the chain that ends with Leaders of the Fang, which is, and
-- The Forgotten Pools comes before it. Built once.
local leadsToDungeon
local function LeadsToDungeon(questID)
    if not leadsToDungeon then
        leadsToDungeon = {}
        local function mark(step)
            if step and not leadsToDungeon[step] then
                leadsToDungeon[step] = true
                local start = ns.quests[step] and ns.quests[step].start or {}
                mark(start.after)
                mark(start.needs)
            end
        end
        for id, quest in pairs(ns.quests) do
            if quest.dungeon then
                mark(id)
            end
        end
    end
    return leadsToDungeon[questID] == true
end

-- Whether any of these quests is for a dungeon, or starts a chain that leads
-- to one: a quest NPC's pin says "Dungeon Quest" then.
function ns.AnyLeadsToDungeon(questIDs)
    for _, questID in ipairs(questIDs) do
        if LeadsToDungeon(questID) then
            return true
        end
    end
    return false
end

function ns.GivesDungeonQuest(npcID)
    return ns.AnyLeadsToDungeon(ns.QuestsFromGiver(npcID))
end

-- The dungeon quest a quest is, or leads to along its chain or as the quest
-- another needs first, and its dungeon: Hamuul Runetotem leads to Leaders of
-- the Fang, in Wailing Caverns.
local function DungeonQuestFor(questID)
    local step, seen = questID, {}
    while step and not seen[step] do
        seen[step] = true
        local quest = ns.quests[step]
        if quest and quest.dungeon then
            return step, ns.dungeons[quest.dungeon]
        end
        step = followUp[step] or unlocks[step]
    end
    return nil
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
ns.QuestTitle = QuestTitle

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

-- Whether a quest is for you: your faction, and your class when it names one.
local function ForMyFaction(quest)
    if quest.class then
        local _, class = UnitClass("player")
        if class and class ~= quest.class then
            return false
        end
    end
    if not quest.faction or quest.faction == "Both" then
        return true
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return faction == nil or faction == quest.faction
end

-- The level a quest asks for: its own where known, else the level its dungeon
-- lets you in at (its entry level, or the bottom of its range), else none.
local function MinLevel(quest)
    local dungeon = quest.dungeon and ns.dungeons[quest.dungeon]
    return quest.minLevel or (dungeon and (dungeon.entryLevel or dungeon.minLevel)) or 0
end

-- Whether a quest is there for you to pick up now: for your faction, neither
-- in your log nor done, your level is high enough, and the quest before it
-- and the one it needs, if any, are turned in.
local function Available(questID)
    local quest = ns.quests[questID]
    if not quest then
        return false
    end
    local start = quest.start or {}
    for _, before in ipairs({ start.after or false, start.needs or false }) do
        if before and not C_QuestLog.IsQuestFlaggedCompleted(before) then
            return false
        end
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

-- Whether the quest's objective for an item is still to do: the objective
-- whose text names the item, "Toxic Skullcap: 0/1". Before the item's name
-- is cached, whether you have one yet.
local function ItemStepOpen(questID, itemID)
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if name then
        local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or {}
        for _, objective in ipairs(objectives) do
            if objective.text and objective.text:find(name, 1, true) then
                return not objective.finished
            end
        end
    elseif C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return (C_Item.GetItemCount and C_Item.GetItemCount(itemID) or 0) == 0
end

-- Whether a quest in your log still needs you at an objective NPC, the
-- given one or any. With an item, until that objective is done; otherwise,
-- with objectives, until they are complete; a talk-to quest with none is
-- complete as soon as it is taken, and talking to the NPC turns it in, so
-- until then.
local function ObjectiveOpen(questID, npcID)
    local quest = ns.quests[questID]
    if not (quest and ForMyFaction(quest)) or QuestState(questID) ~= IN_LOG then
        return false
    end
    local stepped = false
    for _, objective in ipairs(ns.QuestObjectiveNPCs(quest)) do
        if objective.item and (not npcID or objective.npc == npcID) then
            if ItemStepOpen(questID, objective.item) then
                return true
            end
            stepped = true
        end
    end
    if stepped then
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
        if ObjectiveOpen(questID, npcID) then
            return true
        end
    end
    return false
end

-- Where a quest's next step is, for a click in the tracker. The step is the
-- earliest quest of its chain you still need whose record is here: Leaders of
-- the Fang while Nara Wildmane is in your log is Nara Wildmane. Returns
-- { questID, title, action, place, note }: action says what to do at place,
-- place is { map, x, y, name } with npcID for an NPC or dungeonID for a
-- dungeon entrance, note a grey line to add, or nil when nowhere is known.
local function NPCPlace(npcID)
    local npc = npcID and ns.npcs[npcID]
    if npc and npc.map then
        return { map = npc.map, x = npc.x, y = npc.y, npcID = npcID, name = npc.name }
    end
    return nil
end

local function DungeonPlace(instanceID)
    local dungeon = instanceID and ns.dungeons[instanceID]
    if dungeon and dungeon.map then
        return { map = dungeon.map, x = dungeon.x, y = dungeon.y, dungeonID = instanceID, name = dungeon.name }
    end
    return nil
end

-- The quest to do first: back along the series, and to a quest one needs,
-- while that one is not turned in and has a record here.
local function CurrentStep(questID)
    local step, seen = questID, {}
    while not seen[step] do
        seen[step] = true
        local start = ns.quests[step] and ns.quests[step].start or {}
        local before
        for _, id in ipairs({ start.after or false, start.needs or false }) do
            if not before and id and ns.quests[id] and not C_QuestLog.IsQuestFlaggedCompleted(id) then
                before = id
            end
        end
        if not before then
            break
        end
        step = before
    end
    return step
end

function ns.QuestNextStep(questID)
    if QuestState(questID) == DONE then
        return nil
    end
    local stepID = CurrentStep(questID)
    local quest = ns.quests[stepID]
    if not quest then
        return nil
    end
    local next = { questID = stepID, title = QuestTitle(stepID) }
    if QuestState(stepID) == IN_LOG then
        for _, objective in ipairs(ns.QuestObjectiveNPCs(quest)) do
            if not next.place and ObjectiveOpen(stepID, objective.npc) and NPCPlace(objective.npc) then
                next.action, next.place = "Go to", NPCPlace(objective.npc)
            end
        end
        if next.place then -- an objective NPC to go to comes first
            return next
        end
        if ReadyToTurnIn(stepID) and quest.finish and NPCPlace(quest.finish.npc) then
            next.action, next.place = "Turn in to", NPCPlace(quest.finish.npc)
        elseif quest.dungeon and DungeonPlace(quest.dungeon) then
            next.action, next.place = "Do it in", DungeonPlace(quest.dungeon)
            if quest.outside then
                next.note = "Outside the instance, in the caves around it"
            end
        elseif quest.finish and NPCPlace(quest.finish.npc) then
            next.action, next.place = "Turn in to", NPCPlace(quest.finish.npc)
        end
    else
        local start = quest.start or {}
        if NPCPlace(start.npc) then
            next.action, next.place = "Pick it up from", NPCPlace(start.npc)
            -- An earlier quest Sink has no record of comes first, such as quest 65 before Red Silk Bandanas.
            for _, id in ipairs({ start.after or false, start.needs or false }) do
                if id and not C_QuestLog.IsQuestFlaggedCompleted(id) then
                    next.note = "Needs an earlier quest first"
                end
            end
        elseif quest.dungeon and DungeonPlace(quest.dungeon) then
            next.action, next.place = "Starts inside", DungeonPlace(quest.dungeon)
        end
    end
    return next.place and next or nil
end

-- A quest NPC's pin tooltip: for each quest that is theirs right now, what to
-- do there with the quest name in the yellow of quest links, then the dungeon
-- it is for in the dungeon teal, or "Leads to <quest> in <dungeon>" when the
-- dungeon quest has another name. role is "give", "objective" or "finish".
local ROLES = {
    give = { verb = "Pick up", list = function(npcID) return ns.QuestsFromGiver(npcID) end },
    objective = { verb = "Objective of", list = function(npcID) return ns.QuestsWithObjective(npcID) end },
    finish = { verb = "Turn in", list = function(npcID) return ns.QuestsFinishedAt(npcID) end },
}

function ns.AddQuestPinLines(tooltip, role, npcID)
    local spec = ROLES[role]
    local current = (role == "give" and Available) or (role == "objective" and ObjectiveOpen) or ReadyToTurnIn
    for _, questID in ipairs(spec.list(npcID)) do
        if current(questID, npcID) then
            local step = ns.QuestSeriesSuffix(questID)
            tooltip:AddLine(("%s |cffffff00%s%s|r"):format(spec.verb, QuestTitle(questID), step and (" " .. step) or ""),
                1, 1, 1)
            -- The quest name in quest yellow, the dungeon's in the dungeon teal, the rest grey.
            local target, dungeon = DungeonQuestFor(questID)
            local place = dungeon and (ns.dungeonColor.hex .. dungeon.name .. "|r")
            if dungeon and target ~= questID then
                tooltip:AddLine(("Leads to |cffffff00%s|r in %s"):format(QuestTitle(target), place),
                    ns.grey.r, ns.grey.g, ns.grey.b)
            elseif dungeon then
                tooltip:AddLine(place, ns.grey.r, ns.grey.g, ns.grey.b)
            end
        end
    end
end

-- How to get a quest that starts inside its own dungeon: 'Talk to "Ghostly
-- Attendant" inside' from an NPC, 'Kill "The Baron" inside' for a drop,
-- "Loot inside" for an item on the ground. nil for any other quest.
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
        return item.spots and ("Loot inside, in one of %d spots"):format(#item.spots) or "Loot inside"
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
            if quest.outside then
                title = title .. " (outside the instance)"
            end
            -- In your log with its objectives done: drawn as done, but still counted
            -- and sorted as in your log. One with no objectives, as Deathstalkers
            -- in Shadowfang, stays in progress until it is turned in.
            local objectives = C_QuestLog.GetNumQuestObjectives and C_QuestLog.GetNumQuestObjectives(questID) or 0
            local ready = QuestState(questID) == IN_LOG and objectives > 0 and ReadyToTurnIn(questID)
            -- One that starts from an item inside, as The Glowing Shard from Mutanus:
            -- done here once you have the item, or have started it and it asks
            -- for nothing more.
            local start = quest.start or {}
            if drop and start.item then
                local have = C_Item.GetItemCount and C_Item.GetItemCount(start.item) > 0
                ready = ready or have or (QuestState(questID) == IN_LOG and objectives == 0)
            end
            rows[#rows + 1] = { state = state, title = title, questID = questID, ready = ready }
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
-- yellow waiting mark for in your log, green check for done or for in your
-- log with its objectives complete (one with none stays yellow); one your level is too low for is grey
-- with no mark and the level it needs in front, "[15]".
function ns.QuestRowText(row)
    if row.needsLevel then
        -- Not for you yet: plain grey, no mark, the level it asks for in front as the quest log has it.
        return ("[%d] %s"):format(row.needsLevel, row.title), ns.grey
    elseif row.state == NOT_TAKEN then
        return ns.CROSS .. " " .. row.title, ns.missing
    elseif row.state == IN_LOG and not row.ready then
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

--------------------------------------------------------------------------------
-- The dungeon you are in: its bosses, which are dead, and your quests there
--------------------------------------------------------------------------------

local killed = {}       -- encounter ID -> true, for the dungeon below
local searched = {}     -- spot index -> true, for a quest item's spots, marked in the tracker
local killedIn          -- the instance ID the kills and searched spots are for

-- Bosses die in ENCOUNTER_END. The kills are kept while you are in or return
-- to the same dungeon, as after a corpse run, and start over in another; the
-- searched spots too.
local function OnEnterWorld()
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType == "party" and instanceID ~= killedIn then
        killedIn = instanceID
        wipe(killed)
        wipe(searched)
    end
end

-- Mark a quest item's spot searched, or not any more; the tracker calls it on a click.
function ns.ToggleSearchedSpot(index)
    searched[index] = not searched[index] or nil
    if ns.RefreshTracker then
        ns.RefreshTracker()
    end
end

-- The spots to search for the item that starts a quest, while you have not
-- taken the quest or looted the item: { { index, name, where, searched } }, or nil.
local function SpotsToSearch(questID)
    local itemID = ns.quests[questID].start and ns.quests[questID].start.item
    local item = itemID and ns.questItems[itemID]
    if not (item and item.spots) or QuestState(questID) ~= NOT_TAKEN then
        return nil
    end
    if C_Item.GetItemCount and C_Item.GetItemCount(itemID) > 0 then
        return nil
    end
    local spots = {}
    for index, spot in ipairs(item.spots) do
        spots[#spots + 1] = { index = index, name = spot.name, where = spot.where, searched = searched[index] == true }
    end
    return spots
end

local function OnEncounterEnd(encounterID, success)
    if success == 1 and encounterID and not ns.Secret(encounterID) then
        killed[encounterID] = true
    end
end

-- The dungeon you are in, or nil outside one Sink has bosses or quests for:
-- { name, dungeon, bosses = { { name, dead, rare } }, quests = { { row, objectives, spots } } }.
-- quests are the dungeon's quests in your log, with the objectives your quest
-- log gives, and the ones that start inside ("Kill "The Baron" inside"),
-- with the spots to search for one whose item is in one of several.
function ns.CurrentDungeon()
    local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType ~= "party" or not instanceID then
        return nil
    end
    local dungeon, lists = ns.dungeons[instanceID], ns.dungeonBosses[instanceID]
    if not (dungeon or lists) then
        return nil
    end
    local bosses = {}
    local list = lists and (lists[difficultyID] or lists[0] or select(2, next(lists)))
    for _, boss in ipairs(list or {}) do
        bosses[#bosses + 1] = { name = boss.name, dead = killed[boss.id] == true, rare = boss.rare }
    end
    local quests = {}
    for _, row in ipairs(QuestRows(ns.QuestsForDungeon(instanceID))) do
        -- One done outside the instance is not done in here.
        if row.state == IN_LOG and not ns.quests[row.questID].outside then
            local objectives
            if QuestState(row.questID) == IN_LOG and C_QuestLog.GetQuestObjectives then
                objectives = C_QuestLog.GetQuestObjectives(row.questID)
            end
            quests[#quests + 1] = { row = row, objectives = objectives or {}, spots = SpotsToSearch(row.questID) }
        end
    end
    return { name = dungeon and dungeon.name or name, dungeon = dungeon, bosses = bosses, quests = quests }
end

do
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    pcall(frame.RegisterEvent, frame, "ENCOUNTER_END") -- see Core.lua
    frame:SetScript("OnEvent", function(_, event, encounterID, _, _, _, success)
        if event == "ENCOUNTER_END" then
            OnEncounterEnd(encounterID, success)
        else
            OnEnterWorld()
        end
    end)
end

-- A dungeon's level range coloured as the quest log colours a quest of the
-- range's middle level: GetQuestDifficultyColor, the game's own rule. Red 5
-- or more levels above you, orange 3 to 4, yellow within 2, green below that
-- while inside the game's green range, grey past it. Without that function the
-- same rule is applied here, with the game's green range where it can say.
local function DifficultyColor(level)
    if GetQuestDifficultyColor then
        local color = GetQuestDifficultyColor(level)
        if color and color.r then
            return color
        end
    end
    local diff = level - (UnitLevel and UnitLevel("player") or 0)
    local green = (UnitQuestTrivialLevelRange and UnitQuestTrivialLevelRange("player"))
        or (GetQuestGreenRange and GetQuestGreenRange()) or 8
    if diff >= 5 then
        return { r = 1.0, g = 0.1, b = 0.1 }
    elseif diff >= 3 then
        return { r = 1.0, g = 0.5, b = 0.25 }
    elseif diff >= -2 then
        return { r = 1.0, g = 0.82, b = 0.0 }
    elseif -diff <= green then
        return { r = 0.25, g = 0.75, b = 0.25 }
    end
    return { r = 0.5, g = 0.5, b = 0.5 }
end

-- "[13-18]" in the colour of a quest of the range's middle level.
function ns.DungeonRangeText(dungeon)
    local low, high = dungeon.minLevel or 0, dungeon.maxLevel or dungeon.minLevel or 0
    local color = DifficultyColor(math.floor((low + high) / 2))
    return ("|cff%02x%02x%02x[%d-%d]|r"):format(math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5),
        math.floor(color.b * 255 + 0.5), low, high)
end

-- The dungeons with a quest you can take or do now, sorted by level: { instanceID, dungeon, rows, have, total }.
-- rows are the quests not done; ones your level is still too low for come
-- last, with needsLevel set. A dungeon is left out while every quest it has
-- left is one of those. total counts the dungeon's quests for your
-- faction you have not finished yet, and have the ones of them in your log or
-- that start inside the dungeon.
-- Dungeons this character keeps out of the tracker's Dungeons section:
-- SinkDB.ignoredDungeons[player GUID] = { [instanceID] = true }. Per
-- character, as one may skip a dungeon another still wants.
local function IgnoredDungeonIDs(create)
    local key = ns.db and ns.Readable(UnitGUID("player"))
    if not key then
        return {}
    end
    if create then
        ns.db.ignoredDungeons = ns.db.ignoredDungeons or {}
        ns.db.ignoredDungeons[key] = ns.db.ignoredDungeons[key] or {}
    end
    return ns.db.ignoredDungeons and ns.db.ignoredDungeons[key] or {}
end

-- Ignore a dungeon, or stop ignoring it; the tracker and the Ignored tab follow.
function ns.SetDungeonIgnored(instanceID, ignored)
    IgnoredDungeonIDs(true)[instanceID] = ignored or nil
    if ns.RefreshTracker then
        ns.RefreshTracker()
    end
    if ns.RefreshIgnoredList then
        ns.RefreshIgnoredList()
    end
end

-- The dungeons you ignore, by name: { { instanceID, name }, ... }.
function ns.IgnoredDungeons()
    local list = {}
    for instanceID in pairs(IgnoredDungeonIDs()) do
        local dungeon = ns.dungeons[instanceID]
        list[#list + 1] = { instanceID = instanceID, name = dungeon and dungeon.name or tostring(instanceID) }
    end
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    return list
end

-- How many levels below its recommended range a dungeon joins the tracker's
-- Dungeons: Blackfathom Deeps, from 24, shows at 21.
local DUNGEON_LEAD = 3

function ns.DungeonsToDo()
    local level = UnitLevel and UnitLevel("player") or 0
    local ignored = IgnoredDungeonIDs()
    local list = {}
    -- Whether a dungeon shows is up to its quests: once you can take one, even
    -- below the level the dungeon lets you in at, as Arugal Must Die at 18 for
    -- Shadowfang Keep. A quest without its own level uses the dungeon's. But
    -- not before you are within DUNGEON_LEAD levels of the dungeon's range,
    -- unless one of its quests is already in your log.
    for instanceID, dungeon in pairs(ns.dungeons) do
        local rows, later, have, total = {}, {}, 0, 0
        local near = level >= (dungeon.minLevel or 0) - DUNGEON_LEAD
        for _, row in ipairs(QuestRows(ns.QuestsForDungeon(instanceID))) do
            if row.state ~= DONE then
                total = total + 1
                -- One your level is too low for is listed after the rest, with the level it needs.
                local needs = MinLevel(ns.quests[row.questID])
                -- In your log, or one that starts inside the dungeon: that one is
                -- yellow before you have it, and counts as yours as it looks, once
                -- your level allows it.
                if row.state == IN_LOG and (QuestState(row.questID) == IN_LOG or level >= needs) then
                    have = have + 1
                end
                if QuestState(row.questID) == IN_LOG then
                    near = true
                end
                if level >= needs then
                    rows[#rows + 1] = row
                else
                    row.needsLevel = needs
                    later[#later + 1] = row
                end
            end
        end
        table.sort(later, function(a, b)
            if a.needsLevel ~= b.needsLevel then
                return a.needsLevel < b.needsLevel
            end
            return a.title < b.title
        end)
        -- Only while there is a quest you can do now; then the ones still
        -- to come are listed under it.
        local doable = #rows > 0
        for _, row in ipairs(later) do
            rows[#rows + 1] = row
        end
        if doable and near and not ignored[instanceID] then
            list[#list + 1] = { instanceID = instanceID, dungeon = dungeon, rows = rows, have = have, total = total }
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
