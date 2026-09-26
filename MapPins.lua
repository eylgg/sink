--------------------------------------------------------------------------------
-- Sink / MapPins.lua
--
-- Icons on the world map with a tooltip on mouseover. Built-in icons live in
-- ns.mapPins below; "/sink map add <name>" drops one where you stand and
-- prints the line to paste into that table. "/sink dump loc" and "/sink dump
-- target" (Dump.lua) print the IDs and coordinates for new entries.
--
-- Forever runs the Retail map, which is built for this. WorldMapFrame holds a
-- list of data providers; whenever the map opens or changes zone it asks each
-- one to refresh, and the provider asks the map for pins from a named virtual
-- template (SinkMapPinTemplate in MapPins.xml). A pin is an ordinary frame the
-- map positions from normalized coordinates, and on creation the map wires the
-- pin's mouse scripts to the OnMouseEnter / OnMouseLeave methods of its mixin.
--
-- Coordinates are 0 to 1 across the zone map, Wowhead's numbers divided by
-- 100, keyed by the zone's uiMapID from the client's UiMap table.
--
-- Clicking an icon that marks an NPC targets it and pings it with the game's
-- own ping, so the ping marker shows where it stands. Both are protected
-- actions an addon cannot perform itself, so each pin carries a secure action
-- button as an overlay that runs a macro on a real click: clear the target,
-- "/targetexact <name>", "/ping [@target,exists]" so only a found NPC is
-- pinged, and "/targetlasttarget [@target,noexists]" so a miss gives you your
-- previous target back. Targeting by name finds the NPC when it is loaded
-- around you, so this is for "which one is the blacksmith" in town, not for
-- locating someone across the zone.
--
-- Flight masters come from the client, not from a table: C_TaxiMap's nodes
-- for the map, with their position, name and faction. The client answers
-- with every node on the continent, so only the ones that fall on the map
-- are drawn, and its unused "zz" test nodes are skipped.
--
-- Whether you have a flight path has no API away from a flight master: the
-- nodes' isUndiscovered flag is false for all of them on Forever. So opening
-- a flight master's map records it: that map lists every node, state 0 where
-- you stand, 1 for paths you have, 2 for ones you do not. Until a character
-- has opened one, pins are grey and the tooltip says it is unknown.
-- Drawn on zone and city maps only, and not where Blizzard's own
-- flight point layer already draws them. "/sink dump taxi" shows the raw data.
--------------------------------------------------------------------------------

local _, ns = ...

local TEMPLATE = "SinkMapPinTemplate"
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_Map_01"

-- Built-in icons: uiMapID -> list of { x, y, name, icon, note, npc, class,
-- verified }. verified = true marks a position taken in game, standing
-- there with "/sink dump loc" or next to the NPC with "/sink dump target";
-- without it the position came from somewhere else, such as Wowhead, and
-- "/sink dump npc unverified" lists it.
-- The tooltip shows note ("Fishing Supplies") in Sink's colour, or name when
-- there is no note; npc ties the icon to a vendor in Recipes.lua or a weapon
-- master in Weapons.lua so the tooltip also lists what they sell or teach. A
-- "<Class> Trainer" note makes a class trainer; class = "PRIEST" does the same
-- for one whose note is a title such as "High Priest". atlas draws a map
-- atlas instead of an icon texture. teachesUpTo is the highest level a
-- trainer teaches, for a starting area's class trainer; the pin is hidden
-- once you are past it.
--
-- Dungeon entrances and "Dungeon Quest" pins on quest givers are not listed
-- here: they are built from the dungeon, NPC and quest records in Quests.lua.
-- faction ("Horde", "Alliance" or "Both") says who sees a pin; without it the
-- map's faction below applies, and on other maps a pin is for both.
-- On the Forever build Durotar is map 1411, Mulgore 1412, Tirisfal Glades 1420, Undercity 1458,
-- Orgrimmar 1454, Thunder Bluff 1456, Zephras Isle (the Skyborne starting island) 2521,
-- Teldrassil 1438, Darnassus 1457, Stormwind City 1453, Ironforge 1455, Dun Morogh 1426 and Westfall 1436.
ns.mapPins = {
    [1411] = { -- Durotar
        -- No npc, so clicking it does nothing: no target, no ping.
        { name = "Zeppelin to Undercity", x = 0.5082, y = 0.1386,
          atlas = "poi-horde", verified = true },
        { name = "Zeppelin to Stranglethorn", x = 0.5058, y = 0.1261,
          atlas = "poi-horde", verified = true },
        { npc = 3707, name = "Ken'jai", note = "Priest Trainer", x = 0.4236, y = 0.6882,
          icon = "Interface\\Icons\\ClassIcon_Priest", teachesUpTo = 6, verified = true },
        { npc = 3157, name = "Shikrik", note = "Shaman Trainer", x = 0.4239, y = 0.6900,
          icon = "Interface\\Icons\\ClassIcon_Shaman", verified = true },
        { npc = 5884, name = "Mai'ah", note = "Mage Trainer", x = 0.4251, y = 0.6904,
          icon = "Interface\\Icons\\ClassIcon_Mage", teachesUpTo = 6, verified = true },
        { npc = 3154, name = "Jen'shan", note = "Hunter Trainer", x = 0.4284, y = 0.6933,
          icon = "Interface\\Icons\\ClassIcon_Hunter", teachesUpTo = 6, verified = true },
        { npc = 3153, name = "Frang", note = "Warrior Trainer", x = 0.4289, y = 0.6944,
          icon = "Interface\\Icons\\ClassIcon_Warrior", teachesUpTo = 6, verified = true },
        { npc = 267329, name = "Zor'la", note = "Junior Herbalism Trainer", x = 0.4266, y = 0.6739,
          icon = "Interface\\Icons\\Trade_Herbalism", verified = true },
        { npc = 3155, name = "Rwag", note = "Rogue Trainer", x = 0.4128, y = 0.6800,
          icon = "Interface\\Icons\\ClassIcon_Rogue", teachesUpTo = 6, verified = true },
        { npc = 267327, name = "Kagil", note = "Junior Skinning Trainer", x = 0.4079, y = 0.6786,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", verified = true },
        { npc = 267328, name = "Norzsh", note = "Junior Mining Trainer", x = 0.4053, y = 0.6814,
          icon = "Interface\\Icons\\Trade_Mining", verified = true },
        { npc = 3156, name = "Nartok", note = "Warlock Trainer", x = 0.4065, y = 0.6852,
          icon = "Interface\\Icons\\ClassIcon_Warlock", teachesUpTo = 6, verified = true },
        { npc = 3171, name = "Thotar", note = "Hunter Trainer", x = 0.5185, y = 0.4349,
          icon = "Interface\\Icons\\ClassIcon_Hunter", verified = true },
        { npc = 3170, name = "Kaplak", note = "Rogue Trainer", x = 0.5198, y = 0.4369,
          icon = "Interface\\Icons\\ClassIcon_Rogue", verified = true },
        { npc = 3706, name = "Tai'jin", note = "Priest Trainer", x = 0.5426, y = 0.4294,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 3173, name = "Swart", note = "Shaman Trainer", x = 0.5442, y = 0.4259,
          icon = "Interface\\Icons\\ClassIcon_Shaman", verified = true },
        { npc = 3169, name = "Tarshaw Jaggedscar", note = "Warrior Trainer", x = 0.5419, y = 0.4247,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 5943, name = "Rawrk", note = "First Aid Trainer", x = 0.5417, y = 0.4193,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", verified = true },
        { npc = 3172, name = "Dhugru Gorelust", note = "Warlock Trainer", x = 0.5438, y = 0.4120,
          icon = "Interface\\Icons\\ClassIcon_Warlock", verified = true },
        { npc = 3191, name = "Cook Torka", note = "Cooking Trainer", x = 0.5111, y = 0.4245,
          icon = "Interface\\Icons\\INV_Misc_Food_15", verified = true },
        { npc = 3175, name = "Krunn", note = "Miner", x = 0.5181, y = 0.4088,
          icon = "Interface\\Icons\\Trade_Mining", verified = true },
        { npc = 3174, name = "Dwukk", note = "Journeyman Blacksmith", x = 0.5203, y = 0.4072,
          icon = "Interface\\Icons\\Trade_BlackSmithing", verified = true },
        { npc = 11025, name = "Mukdrak", note = "Journeyman Engineer", x = 0.5218, y = 0.4080,
          icon = "Interface\\Icons\\Trade_Engineering", verified = true },
        { npc = 266881, name = "Pa'zula", note = "Journeyman Enchanter", x = 0.5669, y = 0.7375,
          icon = "Interface\\Icons\\Trade_Engraving", verified = true },
        { npc = 5880, name = "Un'Thuwa", note = "Mage Trainer", x = 0.5631, y = 0.7512,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 3185, name = "Mishiki", note = "Herbalist", x = 0.5544, y = 0.7508,
          icon = "Interface\\Icons\\Trade_Herbalism", verified = true },
        { npc = 3184, name = "Miao'zan", note = "Journeyman Alchemist", x = 0.5541, y = 0.7395,
          icon = "Interface\\Icons\\Trade_Alchemy", verified = true },
        { npc = 5941, name = "Lau'Tiki", note = "Fisherman", x = 0.5325, y = 0.8159,
          icon = "Interface\\Icons\\Trade_Fishing", verified = true },
    },
    [1420] = { -- Tirisfal Glades
        { name = "Zeppelin to Orgrimmar", x = 0.6070, y = 0.5878,
          atlas = "poi-horde", verified = true },
        { name = "Zeppelin to Grom'gol Base Camp", x = 0.6189, y = 0.5911,
          atlas = "poi-horde", verified = true },
        { npc = 3550, name = "Martine Tramblay", note = "Fishing Supplies", x = 0.6586, y = 0.5964,
          icon = "Interface\\Icons\\Trade_Fishing", verified = true },
        { npc = 5690, name = "Clyde Kellen", note = "Fisherman", x = 0.6717, y = 0.5099,
          icon = "Interface\\Icons\\Trade_Fishing", verified = true },
        { npc = 5759, name = "Nurse Neela", note = "First Aid Trainer", x = 0.6182, y = 0.5283,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", verified = true },
        { npc = 2131, name = "Austil de Mon", note = "Warrior Trainer", x = 0.6185, y = 0.5254,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 265944, name = "William Pickman", note = "Cooking Trainer", x = 0.6175, y = 0.5144,
          icon = "Interface\\Icons\\INV_Misc_Food_15", verified = true },
        { npc = 2128, name = "Cain Firesong", note = "Mage Trainer", x = 0.6197, y = 0.5247,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 2127, name = "Rupert Boch", note = "Warlock Trainer", x = 0.6159, y = 0.5240,
          icon = "Interface\\Icons\\ClassIcon_Warlock", verified = true },
        { npc = 2129, name = "Dark Cleric Beryl", note = "Priest Trainer", x = 0.6157, y = 0.5219,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 2130, name = "Marion Call", note = "Rogue Trainer", x = 0.6175, y = 0.5200,
          icon = "Interface\\Icons\\ClassIcon_Rogue", verified = true },
        { npc = 5695, name = "Vance Undergloom", note = "Journeyman Enchanter", x = 0.6177, y = 0.5156,
          icon = "Interface\\Icons\\Trade_Engraving", verified = true },
        { npc = 246152, name = "Shari Stilwell", note = "Paladin Trainer", x = 0.6023, y = 0.5267,
          icon = "Interface\\Icons\\ClassIcon_Paladin", verified = true },
        { npc = 244808, name = "Aramis Hammerhand", note = "Paladin Trainer", x = 0.3109, y = 0.6639,
          icon = "Interface\\Icons\\ClassIcon_Paladin", teachesUpTo = 6, verified = true },
        { npc = 2126, name = "Maximillion", note = "Warlock Trainer", x = 0.3091, y = 0.6634,
          icon = "Interface\\Icons\\ClassIcon_Warlock", verified = true },
        { npc = 2124, name = "Isabella", note = "Mage Trainer", x = 0.3093, y = 0.6606,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 2123, name = "Dark Cleric Duesten", note = "Priest Trainer", x = 0.3111, y = 0.6603,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 2122, name = "David Trias", note = "Rogue Trainer", x = 0.3253, y = 0.6565,
          icon = "Interface\\Icons\\ClassIcon_Rogue", verified = true },
        { npc = 2119, name = "Dannal Stern", note = "Warrior Trainer", x = 0.3268, y = 0.6556,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 267326, name = "Florence Nightshade", note = "Junior Herbalism Trainer", x = 0.3246, y = 0.6514,
          icon = "Interface\\Icons\\Trade_Herbalism", verified = true },
        { npc = 267325, name = "Walter Mason", note = "Junior Mining Trainer", x = 0.3222, y = 0.6582,
          icon = "Interface\\Icons\\Trade_Mining", verified = true },
        { npc = 267324, name = "Margaret Weaver", note = "Junior Skinning Trainer", x = 0.3260, y = 0.6581,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", verified = true },
        { npc = 276067, name = "Angus Hammerhand", note = "Blacksmith", x = 0.2116, y = 0.4572,
          icon = "Interface\\Icons\\Trade_BlackSmithing", verified = true },
        { npc = 246389, name = "Hilda the Breaker", note = "Paladin Trainer", x = 0.2205, y = 0.4717,
          icon = "Interface\\Icons\\ClassIcon_Paladin", verified = true },
        { npc = 6289, name = "Rand Rhobart", note = "Skinner", x = 0.6559, y = 0.6003,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", verified = true },
        { npc = 3549, name = "Shelene Rhobart", note = "Journeyman Leatherworker", x = 0.6542, y = 0.6011,
          icon = "Interface\\Icons\\Trade_LeatherWorking", verified = true },
    },
    [1458] = { -- Undercity
        { npc = 11870, name = "Archibald", note = "Weapon Master", x = 0.5731, y = 0.3277,
          icon = "Interface\\Icons\\Ability_DualWield", verified = true },
        { npc = 4596, name = "James Van Brunt", note = "Expert Blacksmith", x = 0.6126, y = 0.3062,
          icon = "Interface\\Icons\\Trade_BlackSmithing", verified = true },
        { npc = 4598, name = "Brom Killian", note = "Mining Trainer", x = 0.5603, y = 0.3746,
          icon = "Interface\\Icons\\Trade_Mining", verified = true },
        { npc = 15683, name = "Auctioneer Naxxremis", note = "Auction House", x = 0.6440, y = 0.3580,
          icon = "Interface\\Icons\\INV_Misc_Coin_01", verified = true },
        { npc = 4552, name = "Eunice Burch", note = "Cooking Trainer", x = 0.6215, y = 0.4491,
          icon = "Interface\\Icons\\INV_Misc_Food_15", verified = true },
        { npc = 15675, name = "Auctioneer Stockton", note = "Auction House", x = 0.7142, y = 0.4668,
          icon = "Interface\\Icons\\INV_Misc_Coin_01", verified = true },
        { npc = 11048, name = "Victor Ward", note = "Journeyman Tailor", x = 0.7007, y = 0.2982,
          icon = "Interface\\Icons\\Trade_Tailoring", verified = true },
        { npc = 11049, name = "Rhiannon Davis", note = "Expert Tailor", x = 0.7004, y = 0.3055,
          icon = "Interface\\Icons\\Trade_Tailoring", verified = true },
        { npc = 4576, name = "Josef Gregorian", note = "Artisan Tailor", x = 0.7076, y = 0.3069,
          icon = "Interface\\Icons\\Trade_Tailoring", verified = true },
        { npc = 4614, name = "Martha Alliestar", note = "Herbalism Trainer", x = 0.5401, y = 0.4955,
          icon = "Interface\\Icons\\Trade_Herbalism", verified = true },
        { npc = 11067, name = "Malcomb Wynn", note = "Journeyman Enchanter", x = 0.6254, y = 0.6035,
          icon = "Interface\\Icons\\Trade_Engraving", verified = true },
        { npc = 4616, name = "Lavinia Crowe", note = "Expert Enchanter", x = 0.6247, y = 0.6178,
          icon = "Interface\\Icons\\Trade_Engraving", verified = true },
        { npc = 15676, name = "Auctioneer Yarly", note = "Auction House", x = 0.7151, y = 0.4190,
          icon = "Interface\\Icons\\INV_Misc_Coin_01", verified = true },
        { npc = 15682, name = "Auctioneer Cain", note = "Auction House", x = 0.6765, y = 0.3589,
          icon = "Interface\\Icons\\INV_Misc_Coin_01", verified = true },
        { npc = 15684, name = "Auctioneer Tricket", note = "Auction House", x = 0.6049, y = 0.4175,
          icon = "Interface\\Icons\\INV_Misc_Coin_01", verified = true },
        { npc = 15686, name = "Auctioneer Rhyker", note = "Auction House", x = 0.6047, y = 0.4645,
          icon = "Interface\\Icons\\INV_Misc_Coin_01", verified = true },
        { npc = 8721, name = "Auctioneer Epitwee", note = "Auction House", x = 0.6441, y = 0.5241,
          icon = "Interface\\Icons\\INV_Misc_Coin_01", verified = true },
        { npc = 8672, name = "Auctioneer Leeka", note = "Auction House", x = 0.6755, y = 0.5243,
          icon = "Interface\\Icons\\INV_Misc_Coin_01", verified = true },
        { npc = 4573, name = "Armand Cromwell", note = "Fishing Trainer", x = 0.8071, y = 0.3126,
          icon = "Interface\\Icons\\Trade_Fishing", verified = true },
        { npc = 4568, name = "Anastasia Hartwell", note = "Mage Trainer", x = 0.8513, y = 0.1004,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 4567, name = "Pierce Shackleton", note = "Mage Trainer", x = 0.8545, y = 0.1352,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 4566, name = "Kaelystia Hatebringer", note = "Mage Trainer", x = 0.8503, y = 0.1402,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 4564, name = "Luther Pickman", note = "Warlock Trainer", x = 0.8642, y = 0.1525,
          icon = "Interface\\Icons\\ClassIcon_Warlock", verified = true },
        { npc = 4563, name = "Kaal Soulreaper", note = "Warlock Trainer", x = 0.8621, y = 0.1594,
          icon = "Interface\\Icons\\ClassIcon_Warlock", verified = true },
        { npc = 4565, name = "Richard Kerwin", note = "Warlock Trainer", x = 0.8891, y = 0.1586,
          icon = "Interface\\Icons\\ClassIcon_Warlock", verified = true },
        { npc = 260093, name = "Garen Largo", note = "Paladin Trainer", x = 0.4739, y = 0.1492,
          icon = "Interface\\Icons\\ClassIcon_Paladin", verified = true },
        { npc = 4593, name = "Christoph Walker", note = "Warrior Trainer", x = 0.4693, y = 0.1523,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 4594, name = "Angela Curthas", note = "Warrior Trainer", x = 0.4832, y = 0.1596,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 4595, name = "Baltus Fowler", note = "Warrior Trainer", x = 0.4740, y = 0.1729,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 4608, name = "Father Lazarus", note = "Priest Trainer", x = 0.4756, y = 0.1890,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 4606, name = "Aelthalyste", note = "Priest Trainer", x = 0.4900, y = 0.1833,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 4607, name = "Father Lankester", note = "Priest Trainer", x = 0.4936, y = 0.1588,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 4591, name = "Mary Edras", note = "First Aid Trainer", x = 0.7316, y = 0.5514,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", verified = true },
        { npc = 223, name = "Dan Golthas", note = "Journeyman Leatherworker", x = 0.7093, y = 0.5840,
          icon = "Interface\\Icons\\Trade_LeatherWorking", verified = true },
        { npc = 4588, name = "Arthur Moore", note = "Expert Leatherworker", x = 0.7018, y = 0.5742,
          icon = "Interface\\Icons\\Trade_LeatherWorking", verified = true },
        { npc = 7087, name = "Killian Hagey", note = "Skinning Trainer", x = 0.7016, y = 0.5918,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", verified = true },
        { npc = 4586, name = "Graham Van Talen", note = "Journeyman Engineer", x = 0.7534, y = 0.7313,
          icon = "Interface\\Icons\\Trade_Engineering", verified = true },
        { npc = 11031, name = "Franklin Lloyd", note = "Expert Engineer", x = 0.7612, y = 0.7403,
          icon = "Interface\\Icons\\Trade_Engineering", verified = true },
        { npc = 4582, name = "Carolyn Ward", note = "Rogue Trainer", x = 0.8385, y = 0.7207,
          icon = "Interface\\Icons\\ClassIcon_Rogue", verified = true },
        { npc = 4584, name = "Gregory Charles", note = "Rogue Trainer", x = 0.8488, y = 0.7353,
          icon = "Interface\\Icons\\ClassIcon_Rogue", verified = true },
        { npc = 4583, name = "Miles Dexter", note = "Rogue Trainer", x = 0.8521, y = 0.7158,
          icon = "Interface\\Icons\\ClassIcon_Rogue", verified = true },
        { npc = 4609, name = "Doctor Marsh", note = "Expert Alchemist", x = 0.5093, y = 0.7455,
          icon = "Interface\\Icons\\Trade_Alchemy", verified = true },
        { npc = 11044, name = "Doctor Martin Felben", note = "Journeyman Alchemist", x = 0.4660, y = 0.7409,
          icon = "Interface\\Icons\\Trade_Alchemy", verified = true },
        { npc = 4611, name = "Doctor Herbert Halsey", note = "Artisan Alchemist", x = 0.4777, y = 0.7334,
          icon = "Interface\\Icons\\Trade_Alchemy", verified = true },
    },
    [1454] = { -- Orgrimmar
        { npc = 2704, name = "Hanashi", note = "Weapon Master", x = 0.8153, y = 0.1963,
          icon = "Interface\\Icons\\Ability_DualWield", verified = true },
        { npc = 11868, name = "Sayoc", note = "Weapon Master", x = 0.8170, y = 0.1954,
          icon = "Interface\\Icons\\Ability_DualWield", verified = true },
        { npc = 1383, name = "Snarl", note = "Expert Blacksmith", x = 0.7960, y = 0.2330,
          icon = "Interface\\Icons\\Trade_BlackSmithing", verified = true },
        { npc = 3357, name = "Makaru", note = "Mining Trainer", x = 0.7312, y = 0.2609,
          icon = "Interface\\Icons\\Trade_Mining", verified = true },
        { npc = 3399, name = "Zamja", note = "Cooking Trainer", x = 0.5740, y = 0.5396,
          icon = "Interface\\Icons\\INV_Misc_Food_15", verified = true },
        { npc = 3373, name = "Arnok", note = "First Aid Trainer", x = 0.3418, y = 0.8458,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", verified = true },
        { npc = 3404, name = "Jandi", note = "Herbalism Trainer", x = 0.5562, y = 0.3946,
          icon = "Interface\\Icons\\Trade_Herbalism", verified = true },
        { npc = 3332, name = "Lumak", note = "Fishing Trainer", x = 0.6980, y = 0.2921,
          icon = "Interface\\Icons\\Trade_Fishing", verified = true },
        { npc = 3347, name = "Yelmak", note = "Expert Alchemist", x = 0.5684, y = 0.3303,
          icon = "Interface\\Icons\\Trade_Alchemy", verified = true },
        { npc = 7088, name = "Thuwd", note = "Skinning Trainer", x = 0.6335, y = 0.4541,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", verified = true },
        { npc = 3365, name = "Karolek", note = "Expert Leatherworker", x = 0.6281, y = 0.4415,
          icon = "Interface\\Icons\\Trade_LeatherWorking", verified = true },
        { npc = 11017, name = "Roxxik", note = "Artisan Engineer", x = 0.7617, y = 0.2518,
          icon = "Interface\\Icons\\Trade_Engineering", verified = true },
        { npc = 3412, name = "Nogg", note = "Expert Engineer", x = 0.7599, y = 0.2540,
          icon = "Interface\\Icons\\Trade_Engineering", verified = true },
        { npc = 2857, name = "Thund", note = "Journeyman Engineer", x = 0.7596, y = 0.2415,
          icon = "Interface\\Icons\\Trade_Engineering", verified = true },
        { npc = 3345, name = "Godan", note = "Expert Enchanter", x = 0.5390, y = 0.3866,
          icon = "Interface\\Icons\\Trade_Engraving", verified = true },
        { npc = 11066, name = "Jhag", note = "Journeyman Enchanter", x = 0.5347, y = 0.3855,
          icon = "Interface\\Icons\\Trade_Engraving", verified = true },
        { npc = 11046, name = "Whuut", note = "Journeyman Alchemist", x = 0.5579, y = 0.3290,
          icon = "Interface\\Icons\\Trade_Alchemy", verified = true },
        { npc = 5811, name = "Kamari", note = "Journeyman Leatherworker", x = 0.6328, y = 0.4475,
          icon = "Interface\\Icons\\Trade_LeatherWorking", verified = true },
        { npc = 10266, name = "Ug'thok", note = "Journeyman Blacksmith", x = 0.8077, y = 0.2370,
          icon = "Interface\\Icons\\Trade_BlackSmithing", verified = true },
        { npc = 3328, name = "Ormok", note = "Rogue Trainer", x = 0.4390, y = 0.5463,
          icon = "Interface\\Icons\\ClassIcon_Rogue", verified = true },
        { npc = 3401, name = "Shenthul", note = "Rogue Trainer", x = 0.4305, y = 0.5374,
          icon = "Interface\\Icons\\ClassIcon_Rogue", verified = true },
        { npc = 3327, name = "Gest", note = "Rogue Trainer", x = 0.4269, y = 0.5148,
          icon = "Interface\\Icons\\ClassIcon_Rogue", verified = true },
        { npc = 3325, name = "Mirket", note = "Warlock Trainer", x = 0.4862, y = 0.4696,
          icon = "Interface\\Icons\\ClassIcon_Warlock", verified = true },
        { npc = 3326, name = "Zevrost", note = "Warlock Trainer", x = 0.4847, y = 0.4542,
          icon = "Interface\\Icons\\ClassIcon_Warlock", verified = true },
        { npc = 3324, name = "Grol'dar", note = "Warlock Trainer", x = 0.4798, y = 0.4593,
          icon = "Interface\\Icons\\ClassIcon_Warlock", verified = true },
        { npc = 3354, name = "Sorek", note = "Warrior Trainer", x = 0.8039, y = 0.3237,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 3353, name = "Grezz Ragefist", note = "Warrior Trainer", x = 0.7979, y = 0.3142,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 3408, name = "Zel'mak", note = "Warrior Trainer", x = 0.8037, y = 0.2952,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 3403, name = "Sian'tsu", note = "Shaman Trainer", x = 0.3784, y = 0.3646,
          icon = "Interface\\Icons\\ClassIcon_Shaman", verified = true },
        { npc = 13417, name = "Sagorne Creststrider", note = "Shaman Trainer", x = 0.3867, y = 0.3593,
          icon = "Interface\\Icons\\ClassIcon_Shaman", verified = true },
        { npc = 3344, name = "Kardris Dreamseeker", note = "Shaman Trainer", x = 0.3881, y = 0.3636,
          icon = "Interface\\Icons\\ClassIcon_Shaman", verified = true },
        { npc = 6018, name = "Ur'kyo", note = "Priest Trainer", x = 0.3559, y = 0.8782,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 6014, name = "X'yera", note = "Priest Trainer", x = 0.3600, y = 0.8773,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 5994, name = "Zayus", note = "High Priest", class = "PRIEST", x = 0.3572, y = 0.8690,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 5883, name = "Enyo", note = "Mage Trainer", x = 0.3879, y = 0.8567,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 5882, name = "Pephredo", note = "Mage Trainer", x = 0.3836, y = 0.8556,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 5885, name = "Deino", note = "Mage Trainer", x = 0.3845, y = 0.8613,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 3407, name = "Sian'dur", note = "Hunter Trainer", x = 0.6796, y = 0.1779,
          icon = "Interface\\Icons\\ClassIcon_Hunter", verified = true },
        { npc = 3406, name = "Xor'juul", note = "Hunter Trainer", x = 0.6725, y = 0.2019,
          icon = "Interface\\Icons\\ClassIcon_Hunter", verified = true },
        { npc = 3352, name = "Ormak Grimshot", note = "Hunter Trainer", x = 0.6605, y = 0.1853,
          icon = "Interface\\Icons\\ClassIcon_Hunter", verified = true },
    },
    [1412] = { -- Mulgore
        { npc = 3060, name = "Gart Mistrunner", note = "Druid Trainer", x = 0.4465, y = 0.7655,
          icon = "Interface\\Icons\\ClassIcon_Druid", verified = true },
        { npc = 3062, name = "Meela Dawnstrider", note = "Shaman Trainer", x = 0.4459, y = 0.7656,
          icon = "Interface\\Icons\\ClassIcon_Shaman", teachesUpTo = 6, verified = true },
        { npc = 267330, name = "Nawka Wildsong", note = "Junior Skinning Trainer", x = 0.4450, y = 0.7669,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", verified = true },
        { npc = 3061, name = "Lanka Farshot", note = "Hunter Trainer", x = 0.4395, y = 0.7635,
          icon = "Interface\\Icons\\ClassIcon_Hunter", verified = true },
        { npc = 3059, name = "Harutt Thunderhorn", note = "Warrior Trainer", x = 0.4375, y = 0.7672,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 267332, name = "Garan Sunstrider", note = "Junior Herbalism Trainer", x = 0.4413, y = 0.7797,
          icon = "Interface\\Icons\\Trade_Herbalism", verified = true },
        { npc = 267331, name = "Vartha Rockmane", note = "Junior Mining Trainer", x = 0.4430, y = 0.7836,
          icon = "Interface\\Icons\\Trade_Mining", verified = true },
        { npc = 3066, name = "Narm Skychaser", note = "Shaman Trainer", x = 0.4740, y = 0.6254,
          icon = "Interface\\Icons\\ClassIcon_Shaman", verified = true },
        { npc = 3064, name = "Gennia Runetotem", note = "Druid Trainer", x = 0.4748, y = 0.6295,
          icon = "Interface\\Icons\\ClassIcon_Druid", verified = true },
        { npc = 3063, name = "Krang Stonehoof", note = "Warrior Trainer", x = 0.4834, y = 0.6374,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 6290, name = "Yonn Deepcut", note = "Skinner", x = 0.4497, y = 0.6139,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", verified = true },
        { npc = 3069, name = "Chaw Stronghide", note = "Journeyman Leatherworker", x = 0.4494, y = 0.6146,
          icon = "Interface\\Icons\\Trade_LeatherWorking", verified = true },
        { npc = 3067, name = "Pyall Silentstride", note = "Cook", x = 0.4491, y = 0.6167,
          icon = "Interface\\Icons\\INV_Misc_Food_15", verified = true },
        { npc = 5939, name = "Vira Younghoof", note = "First Aid Trainer", x = 0.4608, y = 0.6396,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", verified = true },
        { npc = 6747, name = "Innkeeper Kauth", note = "Innkeeper", x = 0.4593, y = 0.6416,
          atlas = "innkeeper", verified = true },
        { npc = 5938, name = "Uthan Stillwater", note = "Fisherman", x = 0.4416, y = 0.6380,
          icon = "Interface\\Icons\\Trade_Fishing", verified = true },
        { npc = 3065, name = "Yaw Sharpmane", note = "Hunter Trainer", x = 0.4693, y = 0.5965,
          icon = "Interface\\Icons\\ClassIcon_Hunter", verified = true },
        { npc = 5940, name = "Harn Longcast", note = "Fishing Supplies", x = 0.4667, y = 0.5912,
          icon = "Interface\\Icons\\Trade_Fishing", verified = true },
    },
    [2521] = { -- Zephras Isle, where the Skyborne start: both factions, except the
        -- Shaman trainers (Horde) and the Mage trainers (Alliance).
        -- The starting camp's class trainers teach up to level 6.
        { npc = 251374, name = "Windshaper Boro", note = "Shaman Trainer", x = 0.4279, y = 0.2357, faction = "Horde",
          icon = "Interface\\Icons\\ClassIcon_Shaman", teachesUpTo = 6, verified = true },
        { npc = 251376, name = "Tai'ree Farsight", note = "Hunter Trainer", x = 0.4247, y = 0.2373,
          icon = "Interface\\Icons\\ClassIcon_Hunter", teachesUpTo = 6, verified = true },
        { npc = 251389, name = "Akeri Duskblade", note = "Rogue Trainer", x = 0.4375, y = 0.2435,
          icon = "Interface\\Icons\\ClassIcon_Rogue", teachesUpTo = 6, verified = true },
        { npc = 251964, name = "Blademaster Ren", note = "Warrior Trainer", x = 0.4366, y = 0.2413,
          icon = "Interface\\Icons\\ClassIcon_Warrior", teachesUpTo = 6, verified = true },
        { npc = 251373, name = "Xyton Silverwind", note = "Druid Trainer", x = 0.4166, y = 0.2334,
          icon = "Interface\\Icons\\ClassIcon_Druid", teachesUpTo = 6, verified = true },
        { npc = 251379, name = "Dorii Brightwhisper", note = "Mage Trainer", x = 0.4154, y = 0.2368, faction = "Alliance",
          icon = "Interface\\Icons\\ClassIcon_Mage", teachesUpTo = 6, verified = true },
        -- The town further south: its trainers teach every level.
        { npc = 257024, name = "Mendalass Tattermend", note = "Skinner", x = 0.4329, y = 0.4337,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", verified = true },
        { npc = 257020, name = "Nasalanna Windsinger", note = "Enchanter", x = 0.4324, y = 0.4316,
          icon = "Interface\\Icons\\Trade_Engraving", verified = true },
        { npc = 254087, name = "Miriaan Mistblade", note = "Rogue Trainer", x = 0.4315, y = 0.4325,
          icon = "Interface\\Icons\\ClassIcon_Rogue", verified = true },
        { npc = 254089, name = "Coriella Calmbreeze", note = "Innkeeper", x = 0.4302, y = 0.4323,
          atlas = "innkeeper", verified = true },
        { npc = 257021, name = "Halassa Fernbreeze", note = "Herbalist", x = 0.4296, y = 0.4354,
          icon = "Interface\\Icons\\Trade_Herbalism", verified = true },
        { npc = 257019, name = "Nyassa Swiftdraught", note = "Alchemist", x = 0.4369, y = 0.4342,
          icon = "Interface\\Icons\\Trade_Alchemy", verified = true },
        { npc = 251905, name = "Zerril Softbreeze", note = "Cook", x = 0.4385, y = 0.4384,
          icon = "Interface\\Icons\\INV_Misc_Food_15", verified = true },
        { npc = 251991, name = "Taleen Shimmerthread", note = "Tailor", x = 0.4487, y = 0.4419,
          icon = "Interface\\Icons\\Trade_Tailoring", verified = true },
        { npc = 251913, name = "Aedi Thriceforged", note = "Blacksmith", x = 0.4488, y = 0.4435,
          icon = "Interface\\Icons\\Trade_BlackSmithing", verified = true },
        { npc = 257022, name = "Messana Crestwind", note = "Miner", x = 0.4477, y = 0.4455,
          icon = "Interface\\Icons\\Trade_Mining", verified = true },
        { npc = 251993, name = "Indari Sunseam", note = "Leatherworker", x = 0.4468, y = 0.4452,
          icon = "Interface\\Icons\\Trade_LeatherWorking", verified = true },
        { npc = 254088, name = "Corsan Earthrazer", note = "Warrior Trainer", x = 0.4494, y = 0.4510,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 254086, name = "Shenaan Spellwind", note = "Mage Trainer", x = 0.4510, y = 0.4587, faction = "Alliance",
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 254084, name = "Elayaa Easewind", note = "Hunter Trainer", x = 0.4526, y = 0.4425,
          icon = "Interface\\Icons\\ClassIcon_Hunter", verified = true },
        { npc = 254081, name = "Naeluna Swiftmend", note = "Druid Trainer", x = 0.4516, y = 0.4422,
          icon = "Interface\\Icons\\ClassIcon_Druid", verified = true },
        { npc = 251992, name = "Fenn Fairweather", note = "Fisherman", x = 0.4502, y = 0.4844,
          icon = "Interface\\Icons\\Trade_Fishing", verified = true },
        { npc = 254082, name = "Aarnor Galestrike", note = "Shaman Trainer", x = 0.4345, y = 0.4487, faction = "Horde",
          icon = "Interface\\Icons\\ClassIcon_Shaman", verified = true },
    },
    [1438] = { -- Teldrassil, from Wowhead's Forever database, not yet checked in game
        { npc = 3602, name = "Kal", note = "Druid Trainer", x = 0.5600, y = 0.6150,
          icon = "Interface\\Icons\\ClassIcon_Druid" },
        { npc = 3597, name = "Mardant Strongoak", note = "Druid Trainer", x = 0.5860, y = 0.4040,
          icon = "Interface\\Icons\\ClassIcon_Druid", teachesUpTo = 6 },
        { npc = 3596, name = "Ayanna Everstride", note = "Hunter Trainer", x = 0.5853, y = 0.4053,
          icon = "Interface\\Icons\\ClassIcon_Hunter", teachesUpTo = 6 },
        { npc = 3601, name = "Dazalar", note = "Hunter Trainer", x = 0.5660, y = 0.5950,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 3306, name = "Keldas", note = "Pet Trainer", x = 0.5670, y = 0.5950,
          icon = "Interface\\Icons\\Ability_Hunter_BeastTraining" },
        { npc = 3600, name = "Laurna Morninglight", note = "Priest Trainer", x = 0.5550, y = 0.5680,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 3595, name = "Shanda", note = "Priest Trainer", x = 0.5920, y = 0.4050,
          icon = "Interface\\Icons\\ClassIcon_Priest", teachesUpTo = 6 },
        { npc = 3594, name = "Frahun Shadewhisper", note = "Rogue Trainer", x = 0.5950, y = 0.3870,
          icon = "Interface\\Icons\\ClassIcon_Rogue", teachesUpTo = 6 },
        { npc = 3599, name = "Jannok Breezesong", note = "Rogue Trainer", x = 0.5620, y = 0.6000,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 3593, name = "Alyissia", note = "Warrior Trainer", x = 0.5953, y = 0.3853,
          icon = "Interface\\Icons\\ClassIcon_Warrior", teachesUpTo = 6 },
        { npc = 3598, name = "Kyra Windblade", note = "Warrior Trainer", x = 0.5620, y = 0.5920,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 6286, name = "Zarrin", note = "Cook", x = 0.5700, y = 0.6120,
          icon = "Interface\\Icons\\INV_Misc_Food_15" },
        { npc = 6094, name = "Byancie", note = "First Aid Trainer", x = 0.5520, y = 0.5680,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
        { npc = 3607, name = "Androl Oakhand", note = "Fisherman", x = 0.5580, y = 0.9350,
          icon = "Interface\\Icons\\Trade_Fishing" },
        { npc = 3604, name = "Malorne Bladeleaf", note = "Herbalist", x = 0.5750, y = 0.6060,
          icon = "Interface\\Icons\\Trade_Herbalism" },
        { npc = 3603, name = "Cyndra Kindwhisper", note = "Journeyman Alchemist", x = 0.5760, y = 0.6060,
          icon = "Interface\\Icons\\Trade_Alchemy" },
        { npc = 3606, name = "Alanna Raveneye", note = "Journeyman Enchanter", x = 0.3680, y = 0.3420,
          icon = "Interface\\Icons\\Trade_Engraving" },
        { npc = 3605, name = "Nadyia Maneweaver", note = "Journeyman Leatherworker", x = 0.4180, y = 0.4950,
          icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { npc = 267335, name = "Eleyna Duskbreeze", note = "Junior Herbalism Trainer", x = 0.5980, y = 0.4140,
          icon = "Interface\\Icons\\Trade_Herbalism" },
        { npc = 267334, name = "Fanorran Stilloak", note = "Junior Mining Trainer", x = 0.5820, y = 0.4150,
          icon = "Interface\\Icons\\Trade_Mining" },
        { npc = 267333, name = "Terunne Bearshaper", note = "Junior Skinning Trainer", x = 0.5940, y = 0.3860,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
        { npc = 6287, name = "Radnaal Maneweaver", note = "Skinner", x = 0.4200, y = 0.5000,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
        { npc = 10118, name = "Nessa Shadowsong", note = "Fishing Supplies", x = 0.5620, y = 0.9240,
          icon = "Interface\\Icons\\Trade_Fishing" },
        { npc = 6736, name = "Innkeeper Keldamyr", note = "Innkeeper", x = 0.5560, y = 0.5980,
          atlas = "innkeeper" },
    },
    [1453] = { -- Stormwind City, from Wowhead's Forever database, not yet checked in game
        { npc = 5520, name = "Spackle Thornberry", note = "Demon Trainer", x = 0.2560, y = 0.7785,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 5506, name = "Maldryn", note = "Druid Trainer", x = 0.2360, y = 0.5614,
          icon = "Interface\\Icons\\ClassIcon_Druid" },
        { npc = 5504, name = "Sheldras Moontree", note = "Druid Trainer", x = 0.2600, y = 0.5940,
          icon = "Interface\\Icons\\ClassIcon_Druid" },
        { npc = 5505, name = "Theridran", note = "Druid Trainer", x = 0.2436, y = 0.5424,
          icon = "Interface\\Icons\\ClassIcon_Druid" },
        { npc = 5515, name = "Einris Brightspear", note = "Hunter Trainer", x = 0.6305, y = 0.2070,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 5517, name = "Thorfin Stoneshield", note = "Hunter Trainer", x = 0.6247, y = 0.1447,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 5516, name = "Ulfir Ironbeard", note = "Hunter Trainer", x = 0.6380, y = 0.2220,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 5498, name = "Elsharin", note = "Mage Trainer", x = 0.3733, y = 0.8133,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 5497, name = "Jennea Cannon", note = "Mage Trainer", x = 0.3850, y = 0.7950,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 5491, name = "Arthur the Faithful", note = "Paladin Trainer", x = 0.3850, y = 0.3250,
          icon = "Interface\\Icons\\ClassIcon_Paladin" },
        { npc = 928, name = "Lord Grayson Shadowbreaker", note = "Paladin Trainer", x = 0.4113, y = 0.3853,
          icon = "Interface\\Icons\\ClassIcon_Paladin" },
        { npc = 2879, name = "Karrina Mekenda", note = "Pet Trainer", x = 0.6295, y = 0.2120,
          icon = "Interface\\Icons\\Ability_Hunter_BeastTraining" },
        { npc = 2485, name = "Larimaine Purdue", note = "Portal Trainer", x = 0.4164, y = 0.8080,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 5484, name = "Brother Benjamin", note = "Priest Trainer", x = 0.4104, y = 0.2798,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 5489, name = "Brother Joshua", note = "Priest Trainer", x = 0.4140, y = 0.3125,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 376, name = "High Priestess Laurena", note = "Priest Trainer", x = 0.3867, y = 0.2640,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 11397, name = "Nara Meideros", note = "Priest Trainer", x = 0.2065, y = 0.5050,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 13283, name = "Lord Tony Romano", note = "Rogue Trainer", x = 0.7820, y = 0.5760,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 918, name = "Osborne the Night Man", note = "Rogue Trainer", x = 0.7445, y = 0.5295,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 461, name = "Demisette Cloyce", note = "Warlock Trainer", x = 0.2890, y = 0.7995,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 5496, name = "Sandahl", note = "Warlock Trainer", x = 0.2580, y = 0.7860,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 5495, name = "Ursula Deline", note = "Warlock Trainer", x = 0.2633, y = 0.7733,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 914, name = "Ander Germaine", note = "Warrior Trainer", x = 0.7833, y = 0.4713,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 5480, name = "Ilsa Corbin", note = "Warrior Trainer", x = 0.7853, y = 0.4553,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 5479, name = "Wu Shen", note = "Warrior Trainer", x = 0.7880, y = 0.4550,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 11867, name = "Woo Ping", note = "Weapon Master", x = 0.5855, y = 0.6050,
          icon = "Interface\\Icons\\Ability_DualWield" },
        { npc = 1346, name = "Georgio Bolero", note = "Artisan Tailor", x = 0.4580, y = 0.7555,
          icon = "Interface\\Icons\\Trade_Tailoring" },
        { npc = 5482, name = "Stephen Ryback", note = "Cooking Trainer", x = 0.7640, y = 0.4240,
          icon = "Interface\\Icons\\INV_Misc_Food_15" },
        { npc = 5499, name = "Lilyssia Nightbreeze", note = "Expert Alchemist", x = 0.4875, y = 0.8100,
          icon = "Interface\\Icons\\Trade_Alchemy" },
        { npc = 5511, name = "Therum Deepforge", note = "Expert Blacksmith", x = 0.5783, y = 0.1953,
          icon = "Interface\\Icons\\Trade_BlackSmithing" },
        { npc = 1317, name = "Lucan Cordell", note = "Expert Enchanter", x = 0.4633, y = 0.6773,
          icon = "Interface\\Icons\\Trade_Engraving" },
        { npc = 5518, name = "Lilliam Sparkspindle", note = "Expert Engineer", x = 0.5493, y = 0.0793,
          icon = "Interface\\Icons\\Trade_Engineering" },
        { npc = 5564, name = "Simon Tanner", note = "Expert Leatherworker", x = 0.6845, y = 0.5280,
          icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { npc = 5567, name = "Sellandus", note = "Expert Tailor", x = 0.4540, y = 0.7880,
          icon = "Interface\\Icons\\Trade_Tailoring" },
        { npc = 2327, name = "Shaina Fuller", note = "First Aid Trainer", x = 0.4520, y = 0.3115,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
        { npc = 5493, name = "Arnold Leland", note = "Fishing Trainer", x = 0.4932, y = 0.6244,
          icon = "Interface\\Icons\\Trade_Fishing" },
        { npc = 5502, name = "Shylamiir", note = "Herbalism Trainer", x = 0.1930, y = 0.5300,
          icon = "Interface\\Icons\\Trade_Herbalism" },
        { npc = 5566, name = "Tannysa", note = "Herbalism Trainer", x = 0.4470, y = 0.7715,
          icon = "Interface\\Icons\\Trade_Herbalism" },
        { npc = 5500, name = "Tel'Athir", note = "Journeyman Alchemist", x = 0.4860, y = 0.8045,
          icon = "Interface\\Icons\\Trade_Alchemy" },
        { npc = 957, name = "Dane Lindgren", note = "Journeyman Blacksmith", x = 0.5847, y = 0.1983,
          icon = "Interface\\Icons\\Trade_BlackSmithing" },
        { npc = 11068, name = "Betty Quin", note = "Journeyman Enchanter", x = 0.4667, y = 0.6707,
          icon = "Interface\\Icons\\Trade_Engraving" },
        { npc = 11026, name = "Sprite Jumpsprocket", note = "Journeyman Engineer", x = 0.5707, y = 0.1587,
          icon = "Interface\\Icons\\Trade_Engineering" },
        { npc = 11096, name = "Randal Worth", note = "Journeyman Leatherworker", x = 0.6844, y = 0.5212,
          icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { npc = 1300, name = "Lawrence Schneider", note = "Journeyman Tailor", x = 0.4680, y = 0.7640,
          icon = "Interface\\Icons\\Trade_Tailoring" },
        { npc = 5513, name = "Gelman Stonehand", note = "Mining Trainer", x = 0.5100, y = 0.1720,
          icon = "Interface\\Icons\\Trade_Mining" },
        { npc = 1292, name = "Maris Granger", note = "Skinning Trainer", x = 0.6907, y = 0.5347,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
        { npc = 8670, name = "Auctioneer Chilton", note = "Auction House", x = 0.5320, y = 0.6050,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { npc = 8719, name = "Auctioneer Fitch", note = "Auction House", x = 0.5350, y = 0.5990,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { npc = 15659, name = "Auctioneer Jaxon", note = "Auction House", x = 0.5350, y = 0.5950,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { npc = 2457, name = "John Burnside", note = "Banker", x = 0.5640, y = 0.7320,
          icon = "Interface\\Icons\\INV_Misc_Bag_10" },
        { npc = 2456, name = "Newton Burnside", note = "Banker", x = 0.5690, y = 0.7250,
          icon = "Interface\\Icons\\INV_Misc_Bag_10" },
        { npc = 2455, name = "Olivia Burnside", note = "Banker", x = 0.5750, y = 0.7240,
          icon = "Interface\\Icons\\INV_Misc_Bag_10" },
        { npc = 5494, name = "Catherine Leland", note = "Fishing Supplier", x = 0.4940, y = 0.6244,
          icon = "Interface\\Icons\\Trade_Fishing" },
        { npc = 6740, name = "Innkeeper Allison", note = "Innkeeper", x = 0.5260, y = 0.6553,
          atlas = "innkeeper" },
    },
    [1455] = { -- Ironforge, from Wowhead's Forever database, not yet checked in game
        { npc = 6382, name = "Jubahl Corpseseeker", note = "Demon Trainer", x = 0.5307, y = 0.0673,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 5115, name = "Daera Brightspear", note = "Hunter Trainer", x = 0.7063, y = 0.8958,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 5116, name = "Olmin Burningbeard", note = "Hunter Trainer", x = 0.7040, y = 0.8380,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 5117, name = "Regnus Thundergranite", note = "Hunter Trainer", x = 0.6960, y = 0.8412,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 5144, name = "Bink", note = "Mage Trainer", x = 0.2665, y = 0.0895,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 7312, name = "Dink", note = "Mage Trainer", x = 0.2655, y = 0.0900,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 5145, name = "Juli Stormkettle", note = "Mage Trainer", x = 0.2636, y = 0.0780,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 5146, name = "Nittlebur Sparkfizzle", note = "Mage Trainer", x = 0.2604, y = 0.0602,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 5148, name = "Beldruk Doombrow", note = "Paladin Trainer", x = 0.2460, y = 0.0532,
          icon = "Interface\\Icons\\ClassIcon_Paladin" },
        { npc = 5149, name = "Brandur Ironhammer", note = "Paladin Trainer", x = 0.2365, y = 0.0650,
          icon = "Interface\\Icons\\ClassIcon_Paladin" },
        { npc = 5147, name = "Valgar Highforge", note = "Paladin Trainer", x = 0.2337, y = 0.0500,
          icon = "Interface\\Icons\\ClassIcon_Paladin" },
        { npc = 10090, name = "Belia Thundergranite", note = "Pet Trainer", x = 0.7055, y = 0.8510,
          icon = "Interface\\Icons\\Ability_Hunter_BeastTraining" },
        { npc = 2489, name = "Milstaff Stormeye", note = "Portal Trainer", x = 0.2556, y = 0.0772,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 5142, name = "Braenna Flintcrag", note = "Priest Trainer", x = 0.2507, y = 0.0913,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 11406, name = "High Priest Rohan", note = "Priest Trainer", x = 0.2526, y = 0.0764,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 258785, name = "High Priestess Mims", note = "Priest Trainer", x = 0.2480, y = 0.1000,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 5141, name = "Theodrus Frostbeard", note = "Priest Trainer", x = 0.2360, y = 0.0910,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 5143, name = "Toldren Deepiron", note = "Priest Trainer", x = 0.2550, y = 0.1000,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 5167, name = "Fenthwick", note = "Rogue Trainer", x = 0.5170, y = 0.1480,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 5165, name = "Hulfdan Blackbeard", note = "Rogue Trainer", x = 0.5163, y = 0.1480,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 5166, name = "Ormyr Flinteye", note = "Rogue Trainer", x = 0.5250, y = 0.1410,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 258098, name = "Eldrun Stormbreaker", note = "Shaman Trainer", x = 0.4720, y = 0.1320,
          icon = "Interface\\Icons\\ClassIcon_Shaman" },
        { npc = 5173, name = "Alexander Calder", note = "Warlock Trainer", x = 0.5047, y = 0.0697,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 5172, name = "Briarthorn", note = "Warlock Trainer", x = 0.5030, y = 0.0620,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 5171, name = "Thistleheart", note = "Warlock Trainer", x = 0.5064, y = 0.0688,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 5114, name = "Bilban Tosslespanner", note = "Warrior Trainer", x = 0.6650, y = 0.8795,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 1901, name = "Kelstrum Stonebreaker", note = "Warrior Trainer", x = 0.6707, y = 0.8913,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 5113, name = "Kelv Sternhammer", note = "Warrior Trainer", x = 0.7023, y = 0.9063,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 13084, name = "Bixi Wobblebonk", note = "Weapon Master", x = 0.6170, y = 0.8910,
          icon = "Interface\\Icons\\Ability_DualWield" },
        { npc = 11865, name = "Buliwyf Stonehand", note = "Weapon Master", x = 0.6150, y = 0.8940,
          icon = "Interface\\Icons\\Ability_DualWield" },
        { npc = 4258, name = "Bengus Deepforge", note = "Artisan Blacksmith", x = 0.5220, y = 0.4143,
          icon = "Interface\\Icons\\Trade_BlackSmithing" },
        { npc = 5174, name = "Springspindle Fizzlegear", note = "Artisan Engineer", x = 0.6848, y = 0.4428,
          icon = "Interface\\Icons\\Trade_Engineering" },
        { npc = 5159, name = "Daryl Riknussun", note = "Cooking Trainer", x = 0.6020, y = 0.3707,
          icon = "Interface\\Icons\\INV_Misc_Food_15" },
        { npc = 5177, name = "Tally Berryfizz", note = "Expert Alchemist", x = 0.6664, y = 0.5516,
          icon = "Interface\\Icons\\Trade_Alchemy" },
        { npc = 10276, name = "Rotgath Stonebeard", note = "Expert Blacksmith", x = 0.5172, y = 0.4240,
          icon = "Interface\\Icons\\Trade_BlackSmithing" },
        { npc = 5157, name = "Gimble Thistlefuzz", note = "Expert Enchanter", x = 0.6017, y = 0.4523,
          icon = "Interface\\Icons\\Trade_Engraving" },
        { npc = 11029, name = "Trixie Quikswitch", note = "Expert Engineer", x = 0.6780, y = 0.4353,
          icon = "Interface\\Icons\\Trade_Engineering" },
        { npc = 5127, name = "Fimble Finespindle", note = "Expert Leatherworker", x = 0.3976, y = 0.3324,
          icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { npc = 5153, name = "Jormund Stonebrow", note = "Expert Tailor", x = 0.4360, y = 0.2930,
          icon = "Interface\\Icons\\Trade_Tailoring" },
        { npc = 5150, name = "Nissa Firestone", note = "First Aid Trainer", x = 0.5507, y = 0.5873,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
        { npc = 5161, name = "Grimnur Stonebrand", note = "Fishing Trainer", x = 0.4840, y = 0.0640,
          icon = "Interface\\Icons\\Trade_Fishing" },
        { npc = 5137, name = "Reyna Stonebranch", note = "Herbalism Trainer", x = 0.5556, y = 0.5880,
          icon = "Interface\\Icons\\Trade_Herbalism" },
        { npc = 1246, name = "Vosur Brakthel", note = "Journeyman Alchemist", x = 0.6660, y = 0.5505,
          icon = "Interface\\Icons\\Trade_Alchemy" },
        { npc = 10277, name = "Groum Stonebeard", note = "Journeyman Blacksmith", x = 0.5172, y = 0.4224,
          icon = "Interface\\Icons\\Trade_BlackSmithing" },
        { npc = 11065, name = "Thonys Pillarstone", note = "Journeyman Enchanter", x = 0.6050, y = 0.4460,
          icon = "Interface\\Icons\\Trade_Engraving" },
        { npc = 11028, name = "Jemma Quikswitch", note = "Journeyman Engineer", x = 0.6792, y = 0.4412,
          icon = "Interface\\Icons\\Trade_Engineering" },
        { npc = 1466, name = "Gretta Finespindle", note = "Journeyman Leatherworker", x = 0.3920, y = 0.3315,
          icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { npc = 1703, name = "Uthrar Threx", note = "Journeyman Tailor", x = 0.4356, y = 0.2864,
          icon = "Interface\\Icons\\Trade_Tailoring" },
        { npc = 4254, name = "Geofram Bouldertoe", note = "Mining Trainer", x = 0.5040, y = 0.2645,
          icon = "Interface\\Icons\\Trade_Mining" },
        { npc = 6291, name = "Balthus Stoneflayer", note = "Skinning Trainer", x = 0.3950, y = 0.3250,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
        { npc = 8671, name = "Auctioneer Buckler", note = "Auction House", x = 0.2445, y = 0.7210,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { npc = 9859, name = "Auctioneer Lympkin", note = "Auction House", x = 0.2553, y = 0.7490,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { npc = 8720, name = "Auctioneer Redmuse", note = "Auction House", x = 0.2460, y = 0.7400,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { npc = 2461, name = "Bailey Stonemantle", note = "Banker", x = 0.3550, y = 0.6050,
          icon = "Interface\\Icons\\INV_Misc_Bag_10" },
        { npc = 2460, name = "Barnum Stonemantle", note = "Banker", x = 0.3460, y = 0.5924,
          icon = "Interface\\Icons\\INV_Misc_Bag_10" },
        { npc = 5099, name = "Soleil Stonemantle", note = "Banker", x = 0.3655, y = 0.6210,
          icon = "Interface\\Icons\\INV_Misc_Bag_10" },
        { npc = 5162, name = "Tansy Puddlefizz", note = "Fishing Supplier", x = 0.4793, y = 0.0707,
          icon = "Interface\\Icons\\Trade_Fishing" },
        { npc = 5111, name = "Innkeeper Firebrew", note = "Innkeeper", x = 0.1850, y = 0.5150,
          atlas = "innkeeper" },
    },
    [1457] = { -- Darnassus, from Wowhead's Forever database, not yet checked in game
        { npc = 4218, name = "Denatharion", note = "Druid Trainer", x = 0.3460, y = 0.0776,
          icon = "Interface\\Icons\\ClassIcon_Druid" },
        { npc = 4219, name = "Fylerian Nightwing", note = "Druid Trainer", x = 0.3356, y = 0.0824,
          icon = "Interface\\Icons\\ClassIcon_Druid" },
        { npc = 4217, name = "Mathrengyl Bearwalker", note = "Druid Trainer", x = 0.3507, y = 0.0800,
          icon = "Interface\\Icons\\ClassIcon_Druid" },
        { npc = 4205, name = "Dorion", note = "Hunter Trainer", x = 0.4220, y = 0.0787,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 4138, name = "Jeen'ra Nightrunner", note = "Hunter Trainer", x = 0.3950, y = 0.0590,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 4146, name = "Jocaste", note = "Hunter Trainer", x = 0.4020, y = 0.0900,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 10089, name = "Silvaria", note = "Pet Trainer", x = 0.4220, y = 0.0860,
          icon = "Interface\\Icons\\Ability_Hunter_BeastTraining" },
        { npc = 4165, name = "Elissa Dumas", note = "Portal Trainer", x = 0.4040, y = 0.8208,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 4090, name = "Astarii Starseeker", note = "Priest Trainer", x = 0.3824, y = 0.8064,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 4091, name = "Jandria", note = "Priest Trainer", x = 0.3830, y = 0.8240,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 4092, name = "Lariia", note = "Priest Trainer", x = 0.4017, y = 0.8850,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 11401, name = "Priestess Alathea", note = "Priest Trainer", x = 0.3940, y = 0.8072,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 4215, name = "Anishar", note = "Rogue Trainer", x = 0.3812, y = 0.2084,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 4214, name = "Erion Shadewhisper", note = "Rogue Trainer", x = 0.3473, y = 0.2553,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 4163, name = "Syurna", note = "Rogue Trainer", x = 0.3640, y = 0.2160,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 4087, name = "Arias'ta Bladesinger", note = "Warrior Trainer", x = 0.5833, y = 0.3503,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 7315, name = "Darnath Bladesinger", note = "Warrior Trainer", x = 0.5850, y = 0.3550,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 4089, name = "Sildanair", note = "Warrior Trainer", x = 0.6180, y = 0.4220,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 11866, name = "Ilyenia Moonfire", note = "Weapon Master", x = 0.5744, y = 0.4628,
          icon = "Interface\\Icons\\Ability_DualWield" },
        { npc = 4160, name = "Ainethil", note = "Artisan Alchemist", x = 0.5532, y = 0.2416,
          icon = "Interface\\Icons\\Trade_Alchemy" },
        { npc = 4212, name = "Telonis", note = "Artisan Leatherworker", x = 0.6450, y = 0.2150,
          icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { npc = 4210, name = "Alegorn", note = "Cooking Trainer", x = 0.4907, y = 0.2113,
          icon = "Interface\\Icons\\INV_Misc_Food_15" },
        { npc = 11042, name = "Sylvanna Forestmoon", note = "Expert Alchemist", x = 0.5624, y = 0.2424,
          icon = "Interface\\Icons\\Trade_Alchemy" },
        { npc = 4213, name = "Taladan", note = "Expert Enchanter", x = 0.5850, y = 0.1340,
          icon = "Interface\\Icons\\Trade_Engraving" },
        { npc = 11081, name = "Faldron", note = "Expert Leatherworker", x = 0.6450, y = 0.2150,
          icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { npc = 4159, name = "Me'lynn", note = "Expert Tailor", x = 0.6300, y = 0.2243,
          icon = "Interface\\Icons\\Trade_Tailoring" },
        { npc = 4211, name = "Dannelor", note = "First Aid Trainer", x = 0.5152, y = 0.1272,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
        { npc = 4156, name = "Astaia", note = "Fishing Trainer", x = 0.4750, y = 0.5650,
          icon = "Interface\\Icons\\Trade_Fishing" },
        { npc = 4204, name = "Firodren Mooncaller", note = "Herbalism Trainer", x = 0.4800, y = 0.6850,
          icon = "Interface\\Icons\\Trade_Herbalism" },
        { npc = 11041, name = "Milla Fairancora", note = "Journeyman Alchemist", x = 0.5537, y = 0.2287,
          icon = "Interface\\Icons\\Trade_Alchemy" },
        { npc = 11070, name = "Lalina Summermoon", note = "Journeyman Enchanter", x = 0.5900, y = 0.1293,
          icon = "Interface\\Icons\\Trade_Engraving" },
        { npc = 11083, name = "Darianna", note = "Journeyman Leatherworker", x = 0.6444, y = 0.2092,
          icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { npc = 11050, name = "Trianna", note = "Journeyman Tailor", x = 0.6350, y = 0.2150,
          icon = "Interface\\Icons\\Trade_Tailoring" },
        { npc = 6292, name = "Eladriel", note = "Skinning Trainer", x = 0.6440, y = 0.2140,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
        { npc = 15679, name = "Auctioneer Cazarez", note = "Auction House", x = 0.5544, y = 0.5272,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { npc = 8723, name = "Auctioneer Golothas", note = "Auction House", x = 0.5640, y = 0.5367,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { npc = 15678, name = "Auctioneer Silva'las", note = "Auction House", x = 0.5716, y = 0.5344,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { npc = 8669, name = "Auctioneer Tolon", note = "Auction House", x = 0.5645, y = 0.5210,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { npc = 4209, name = "Garryeth", note = "Banker", x = 0.4000, y = 0.4220,
          icon = "Interface\\Icons\\INV_Misc_Bag_10" },
        { npc = 4155, name = "Idriana", note = "Banker", x = 0.3980, y = 0.4250,
          icon = "Interface\\Icons\\INV_Misc_Bag_10" },
        { npc = 4208, name = "Lairn", note = "Banker", x = 0.4000, y = 0.4180,
          icon = "Interface\\Icons\\INV_Misc_Bag_10" },
        { npc = 4222, name = "Voloren", note = "Fishing Supplier", x = 0.4700, y = 0.5635,
          icon = "Interface\\Icons\\Trade_Fishing" },
        { npc = 6735, name = "Innkeeper Saelienne", note = "Innkeeper", x = 0.6720, y = 0.1575,
          atlas = "innkeeper" },
    },
    [1456] = { -- Thunder Bluff
        { npc = 11869, name = "Ansekhwa", note = "Weapon Master", x = 0.4095, y = 0.6273,
          icon = "Interface\\Icons\\Ability_DualWield", verified = true },
        { npc = 3028, name = "Kah Mistrunner", note = "Fishing Trainer", x = 0.5612, y = 0.4643,
          icon = "Interface\\Icons\\Trade_Fishing", verified = true },
        { npc = 3033, name = "Turak Runetotem", note = "Druid Trainer", x = 0.7646, y = 0.2724,
          icon = "Interface\\Icons\\ClassIcon_Druid", verified = true },
        { npc = 3034, name = "Sheal Runetotem", note = "Druid Trainer", x = 0.7714, y = 0.2702,
          icon = "Interface\\Icons\\ClassIcon_Druid", verified = true },
        { npc = 3036, name = "Kym Wildmane", note = "Druid Trainer", x = 0.7715, y = 0.2981,
          icon = "Interface\\Icons\\ClassIcon_Druid", verified = true },
        { npc = 3026, name = "Aska Mistrunner", note = "Cooking Trainer", x = 0.5072, y = 0.5311,
          icon = "Interface\\Icons\\INV_Misc_Food_15", verified = true },
        { npc = 11047, name = "Kray", note = "Journeyman Alchemist", x = 0.4669, y = 0.3445,
          icon = "Interface\\Icons\\Trade_Alchemy", verified = true },
        { npc = 3009, name = "Bena Winterhoof", note = "Expert Alchemist", x = 0.4662, y = 0.3318,
          icon = "Interface\\Icons\\Trade_Alchemy", verified = true },
        { npc = 3013, name = "Komin Winterhoof", note = "Herbalism Trainer", x = 0.4996, y = 0.4039,
          icon = "Interface\\Icons\\Trade_Herbalism", verified = true },
        { npc = 8722, name = "Auctioneer Gullem", note = "Auction House", x = 0.3889, y = 0.5021,
          icon = "Interface\\Icons\\INV_Misc_Coin_01", verified = true },
        { npc = 8674, name = "Auctioneer Stampi", note = "Auction House", x = 0.4040, y = 0.5178,
          icon = "Interface\\Icons\\INV_Misc_Coin_01", verified = true },
        { npc = 3001, name = "Brek Stonehoof", note = "Mining Trainer", x = 0.3438, y = 0.5786,
          icon = "Interface\\Icons\\Trade_Mining", verified = true },
        { npc = 2996, name = "Torn", note = "Banker", x = 0.4762, y = 0.5859,
          icon = "Interface\\Icons\\INV_Misc_Bag_10", verified = true },
        { npc = 8356, name = "Chesmu", note = "Banker", x = 0.4713, y = 0.5790,
          icon = "Interface\\Icons\\INV_Misc_Bag_10", verified = true },
        { npc = 8357, name = "Atepa", note = "Banker", x = 0.4721, y = 0.5930,
          icon = "Interface\\Icons\\INV_Misc_Bag_10", verified = true },
        { npc = 10278, name = "Thrag Stonehoof", note = "Journeyman Blacksmith", x = 0.3943, y = 0.5667,
          icon = "Interface\\Icons\\Trade_BlackSmithing", verified = true },
        { npc = 2998, name = "Karn Stonehoof", note = "Expert Blacksmith", x = 0.3937, y = 0.5509,
          icon = "Interface\\Icons\\Trade_BlackSmithing", verified = true },
        { npc = 11071, name = "Mot Dawnstrider", note = "Journeyman Enchanter", x = 0.4462, y = 0.3849,
          icon = "Interface\\Icons\\Trade_Engraving", verified = true },
        { npc = 3011, name = "Teg Dawnstrider", note = "Expert Enchanter", x = 0.4491, y = 0.3750,
          icon = "Interface\\Icons\\Trade_Engraving", verified = true },
        { npc = 2798, name = "Pand Stonebinder", note = "First Aid Trainer", x = 0.2969, y = 0.2119,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", verified = true },
        { npc = 3031, name = "Tigor Skychaser", note = "Shaman Trainer", x = 0.2364, y = 0.1882,
          icon = "Interface\\Icons\\ClassIcon_Shaman", verified = true },
        { npc = 3032, name = "Beram Skychaser", note = "Shaman Trainer", x = 0.2199, y = 0.1881,
          icon = "Interface\\Icons\\ClassIcon_Shaman", verified = true },
        { npc = 3030, name = "Siln Skychaser", note = "Shaman Trainer", x = 0.2282, y = 0.2111,
          icon = "Interface\\Icons\\ClassIcon_Shaman", verified = true },
        { npc = 7089, name = "Mooranta", note = "Skinning Trainer", x = 0.4444, y = 0.4315,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", verified = true },
        { npc = 11084, name = "Tarn", note = "Expert Leatherworker", x = 0.4234, y = 0.4261,
          icon = "Interface\\Icons\\Trade_LeatherWorking", verified = true },
        { npc = 3007, name = "Una", note = "Artisan Leatherworker", x = 0.4150, y = 0.4257,
          icon = "Interface\\Icons\\Trade_LeatherWorking", verified = true },
        { npc = 3008, name = "Mak", note = "Journeyman Leatherworker", x = 0.4205, y = 0.4344,
          icon = "Interface\\Icons\\Trade_LeatherWorking", verified = true },
        { npc = 11051, name = "Vhan", note = "Journeyman Tailor", x = 0.4425, y = 0.4434,
          icon = "Interface\\Icons\\Trade_Tailoring", verified = true },
        { npc = 3004, name = "Tepa", note = "Expert Tailor", x = 0.4453, y = 0.4535,
          icon = "Interface\\Icons\\Trade_Tailoring", verified = true },
        { npc = 3043, name = "Ker Ragetotem", note = "Warrior Trainer", x = 0.5758, y = 0.8550,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 3041, name = "Torm Ragetotem", note = "Warrior Trainer", x = 0.5726, y = 0.8734,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 3042, name = "Sark Ragetotem", note = "Warrior Trainer", x = 0.5701, y = 0.8949,
          icon = "Interface\\Icons\\ClassIcon_Warrior", verified = true },
        { npc = 3039, name = "Holt Thunderhorn", note = "Hunter Trainer", x = 0.5730, y = 0.8975,
          icon = "Interface\\Icons\\ClassIcon_Hunter", verified = true },
        { npc = 3038, name = "Kary Thunderhorn", note = "Hunter Trainer", x = 0.5848, y = 0.8833,
          icon = "Interface\\Icons\\ClassIcon_Hunter", verified = true },
        { npc = 3040, name = "Urek Thunderhorn", note = "Hunter Trainer", x = 0.5912, y = 0.8686,
          icon = "Interface\\Icons\\ClassIcon_Hunter", verified = true },
        { npc = 3045, name = "Malakai Cross", note = "Priest Trainer", x = 0.2455, y = 0.2256,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 3047, name = "Archmage Shymm", note = "Mage Trainer", x = 0.2275, y = 0.1452,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 5957, name = "Birgitte Cranston", note = "Portal Trainer", x = 0.2250, y = 0.1691,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 3049, name = "Thurston Xane", note = "Mage Trainer", x = 0.2518, y = 0.2096,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 3046, name = "Father Cobb", note = "Priest Trainer", x = 0.2564, y = 0.2069,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 3044, name = "Miles Welsh", note = "Priest Trainer", x = 0.2533, y = 0.1526,
          icon = "Interface\\Icons\\ClassIcon_Priest", verified = true },
        { npc = 3048, name = "Ursyn Ghull", note = "Mage Trainer", x = 0.2570, y = 0.1420,
          icon = "Interface\\Icons\\ClassIcon_Mage", verified = true },
        { npc = 246344, name = "Alodan the Hopeful", note = "Paladin Trainer", x = 0.2520, y = 0.1439,
          icon = "Interface\\Icons\\ClassIcon_Paladin", verified = true },
    },
}

-- Maps whose pins are for one faction unless a pin says otherwise: the Horde
-- capitals, and the Horde starting zones with Razor Hill, Bloodhoof Village
-- and Brill; Stormwind, Ironforge, Darnassus and Teldrassil for the Alliance.
local MAP_FACTION = {
    [1411] = "Horde", -- Durotar
    [1412] = "Horde", -- Mulgore
    [1420] = "Horde", -- Tirisfal Glades
    [1454] = "Horde", -- Orgrimmar
    [1456] = "Horde", -- Thunder Bluff
    [1458] = "Horde", -- Undercity
    [1438] = "Alliance", -- Teldrassil
    [1453] = "Alliance", -- Stormwind City
    [1455] = "Alliance", -- Ironforge
    [1457] = "Alliance", -- Darnassus
}

-- Whether a pin is for your faction.
local function ForMyFaction(pin, mapID)
    local faction = pin.faction or MAP_FACTION[mapID] or "Both"
    if faction == "Both" then
        return true
    end
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    return mine == nil or mine == faction
end

local provider -- our data provider, once added to WorldMapFrame
local refreshAfterCombat = false -- a pin was acquired in combat; redo them all when it ends

-- Pin click buttons are secure, and a frame with a secure child is protected
-- itself: in combat the map could no longer scale or move the pin, so pins
-- shrank to the canvas's scale and each attempt was blocked as "Interface
-- action failed because of an AddOn". So a button sits on its pin only out of
-- combat; the rest of the time it waits here, off the map.
local buttonHolder = CreateFrame("Frame")
buttonHolder:Hide()
local pinFrames = {} -- every pin frame the map has made, for taking the buttons off when combat starts

local function Enabled()
    return ns.db ~= nil and ns.db.mapIcons ~= false
end

local function CustomPins()
    return ns.db and ns.db.mapPins or nil
end

-- A position on a continent map, as "/sink dump loc" gives in a cave with no
-- zone map, moved to the zone it lies in: the map asks which zone is at that
-- point, and the point goes to world coordinates and back onto that zone.
-- Any other position, or one the client cannot place, is returned as it is.
local function ZonePosition(mapID, x, y)
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if not (info and Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Continent)
        or not (C_Map.GetMapInfoAtPosition and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos
            and CreateVector2D) then
        return mapID, x, y
    end
    local zone = C_Map.GetMapInfoAtPosition(mapID, x, y)
    if not zone or zone.mapID == mapID then
        return mapID, x, y
    end
    local continentID, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    if not (continentID and world) then
        return mapID, x, y
    end
    local _, pos = C_Map.GetMapPosFromWorldPos(continentID, world, zone.mapID)
    if not pos then
        return mapID, x, y
    end
    local zx, zy = pos:GetXY()
    return zone.mapID, zx, zy
end

-- Pins built from Quests.lua, by map: each dungeon's entrance and each NPC
-- who gives a quest, on the zone they are in. The records never change, so
-- this is done once, the first time the map opens.
local questPins
local function QuestPins(mapID)
    if not questPins then
        questPins = {}
        local function add(map, pin)
            map, pin.x, pin.y = ZonePosition(map, pin.x, pin.y)
            -- Dungeons are open to both; quest pins follow their quests' factions instead.
            pin.faction = "Both"
            questPins[map] = questPins[map] or {}
            table.insert(questPins[map], pin)
        end
        for instanceID, dungeon in pairs(ns.dungeons or {}) do
            add(dungeon.map, { name = dungeon.name, dungeon = true, minLevel = dungeon.minLevel,
                maxLevel = dungeon.maxLevel, x = dungeon.x, y = dungeon.y, atlas = "Dungeon",
                questIDs = ns.QuestsForDungeon(instanceID) })
        end
        if ns.EachQuestGiver then
            ns.EachQuestGiver(function(npcID, npc)
                if npc.map then
                    local note = ns.GivesDungeonQuest(npcID) and "Dungeon Quest" or "Quest"
                    add(npc.map, { npc = npcID, name = npc.name, note = note, questGiver = true,
                        x = npc.x, y = npc.y, atlas = "QuestNormal", questIDs = ns.QuestsFromGiver(npcID) })
                end
            end)
        end
        if ns.EachObjectiveNPC then
            ns.EachObjectiveNPC(function(npcID, npc)
                if npc.map then
                    add(npc.map, { npc = npcID, name = npc.name, note = "Quest Objective", questObjective = true,
                        x = npc.x, y = npc.y, atlas = "QuestTurnin", questIDs = ns.QuestsWithObjective(npcID) })
                end
            end)
        end
        if ns.EachFinishNPC then
            ns.EachFinishNPC(function(npcID, npc)
                if npc.map then
                    add(npc.map, { npc = npcID, name = npc.name, note = "Turn In", questFinish = true,
                        x = npc.x, y = npc.y, atlas = "QuestTurnin", questIDs = ns.QuestsFinishedAt(npcID) })
                end
            end)
        end
    end
    return questPins[mapID] or {}
end

-- Calls fn(pin) for every icon on mapID: built-in first, then the ones built
-- from Quests.lua, then those added in game.
local function EachPin(mapID, fn)
    for _, pin in ipairs(ns.mapPins[mapID] or {}) do
        fn(pin)
    end
    for _, pin in ipairs(QuestPins(mapID)) do
        fn(pin)
    end
    local custom = CustomPins()
    for _, pin in ipairs(custom and custom[mapID] or {}) do
        fn(pin)
    end
end

local function MapName(mapID)
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return (info and info.name) or ("map " .. tostring(mapID))
end

local function Coords(x, y)
    return ("%.1f, %.1f"):format(x * 100, y * 100)
end

-- A profession trainer's rank says how far they teach. A note that starts
-- with one gets that cap: "Journeyman Blacksmith (150)". Other notes stay as
-- they are.
-- Junior is Forever's, on the Razor Hill trainers, and teaches as far as Apprentice.
local RANK_CAPS = { Junior = 75, Apprentice = 75, Journeyman = 150, Expert = 225, Artisan = 300 }


-- Professions, by the words a trainer's note uses for them: "Expert
-- Blacksmith", "Mining Trainer", or just "Fisherman". line is the skill line
-- that says how far you are; name is how the pin shows a bare "Fisherman":
-- "Fishing Trainer". Primary professions are the ones you can have two of;
-- the rest are secondary and open to everyone.
local PROFESSIONS = {
    { line = 171, name = "Alchemy", primary = true,  words = { "alchemist", "alchemy" } },
    { line = 164, name = "Blacksmithing", primary = true,  words = { "blacksmith", "blacksmithing" } },
    { line = 333, name = "Enchanting", primary = true,  words = { "enchanter", "enchanting" } },
    { line = 202, name = "Engineering", primary = true,  words = { "engineer", "engineering" } },
    { line = 182, name = "Herbalism", primary = true,  words = { "herbalist", "herbalism" } },
    { line = 165, name = "Leatherworking", primary = true,  words = { "leatherworker", "leatherworking" } },
    { line = 186, name = "Mining", primary = true,  words = { "miner", "mining" } },
    { line = 393, name = "Skinning", primary = true,  words = { "skinner", "skinning" } },
    { line = 197, name = "Tailoring", primary = true,  words = { "tailor", "tailoring" } },
    { line = 185, name = "Cooking", primary = false, words = { "cook", "cooking" } },
    { line = 129, name = "First Aid", primary = false, words = { "first aid" } },
    { line = 356, name = "Fishing", primary = false, words = { "fisherman", "fishing" } },
}
local professionByWord = {}
for _, profession in ipairs(PROFESSIONS) do
    for _, word in ipairs(profession.words) do
        professionByWord[word] = profession
    end
end

local function NoteText(pin)
    local note = pin.note or pin.name
    -- A title that is just the profession's word ("Fisherman") reads as "Fishing Trainer".
    local profession = pin.note and professionByWord[pin.note:lower()]
    if profession then
        return profession.name .. " Trainer"
    end
    if pin.minLevel and pin.maxLevel then
        return ("%s (%d - %d)"):format(note, pin.minLevel, pin.maxLevel)
    end
    local cap = RANK_CAPS[note:match("^(%a+)") or ""]
    return cap and (note .. " (" .. cap .. ")") or note
end

-- A "<Class> Trainer" pin is for that class only.
local CLASS_WORDS = {
    warrior = "WARRIOR", paladin = "PALADIN", hunter = "HUNTER", rogue = "ROGUE", priest = "PRIEST",
    shaman = "SHAMAN", mage = "MAGE", warlock = "WARLOCK", druid = "DRUID",
}

-- Class specialties, by the trainer's title: trainers that serve one class
-- but are not its class trainer. They are drawn for that class like the class
-- trainer is, get no class skill lines, and stay a group of their own.
local CLASS_SPECIALTIES = {
    ["portal trainer"] = "MAGE",
    ["demon trainer"] = "WARLOCK",
    ["pet trainer"] = "HUNTER",
}

-- For a trainer pin: its profession (a class trainer gives { class = ... }, a
-- class specialty { class = ..., specialty = true }, an unknown word false),
-- the rank cap (nil for a plain "... Trainer"), and the word. Any other pin
-- returns nil.
local function TrainerInfo(pin)
    if pin.class then
        return { class = pin.class }, nil, pin.class:lower()
    end
    local note = pin.note or ""
    local specialtyClass = CLASS_SPECIALTIES[note:lower()]
    if specialtyClass then
        return { class = specialtyClass, specialty = true }, nil, note:lower()
    end
    local rank, rest = note:match("^(%a+)%s+(.+)$")
    local cap = rank and RANK_CAPS[rank]
    if cap then
        -- "Journeyman Alchemist Trainer", as some NPCs title themselves, is the same as "Journeyman Alchemist".
        local word = rest:lower():gsub("%s+trainer$", "")
        return professionByWord[word] or false, cap, word
    end
    -- A title that is just the profession's word, as Clyde Kellen's "Fisherman".
    if professionByWord[note:lower()] then
        return professionByWord[note:lower()], nil, note:lower()
    end
    local word = note:match("^(.+)%s+Trainer$")
    if word then
        word = word:lower()
        if CLASS_WORDS[word] then
            return { class = CLASS_WORDS[word] }, nil, word
        end
        return professionByWord[word] or false, nil, word
    end
    return nil
end

-- The class a trainer with a map pin teaches, by NPC ID, or nil. Built once
-- from the pins, for the class skill lines on the trainer's own tooltip.
local trainerClassByNPC
function ns.ClassTrainerClass(npcID)
    if not trainerClassByNPC then
        trainerClassByNPC = {}
        for _, pins in pairs(ns.mapPins) do
            for _, pin in ipairs(pins) do
                local profession = pin.npc and TrainerInfo(pin)
                if profession and profession.class and not profession.specialty then
                    trainerClassByNPC[pin.npc] = profession.class
                end
            end
        end
    end
    return trainerClassByNPC[npcID]
end

-- Your current maximum in a profession, or nil if you do not have it.
local function ProfessionMax(profession)
    if not (profession and C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID) then
        return nil
    end
    local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, profession.line)
    if ok and info and not info.isHeader and (info.maxRank or 0) > 0 then
        return info.maxRank
    end
    return nil
end

-- How many primary professions the character has taken.
local function PrimaryCount()
    local count = 0
    for _, profession in ipairs(PROFESSIONS) do
        if profession.primary and ProfessionMax(profession) then
            count = count + 1
        end
    end
    return count
end

-- Of a profession's ranked trainers on one map, the one you need: the lowest
-- rank whose cap is above your current maximum; the lowest of all if you do
-- not have the profession; the highest if you have outgrown every one here.
local function ChooseTrainer(profession, group)
    table.sort(group, function(a, b)
        return a.cap < b.cap
    end)
    local max = ProfessionMax(profession)
    if not max then
        return group[1].pin
    end
    for _, entry in ipairs(group) do
        if entry.cap > max then
            return entry.pin
        end
    end
    return group[#group].pin
end

-- Flight paths this character has, recorded from the flight master's map.
-- Kept by the character's GUID, not its name: a new character with the name
-- of a deleted one must not inherit its flight paths.
local function KnownFlightPaths()
    if not ns.db then
        return {}
    end
    local key = ns.Readable(UnitGUID("player"))
    if not key then
        return {}
    end
    ns.db.knownFlightPaths = ns.db.knownFlightPaths or {}
    ns.db.knownFlightPaths[key] = ns.db.knownFlightPaths[key] or {}
    return ns.db.knownFlightPaths[key]
end

-- At a flight master: every path on the flight map you can take is known,
-- and every one you cannot is not. Each visit replaces what the paths on
-- that map were before, so a path recorded wrongly once does not stay.
local function RecordFlightPaths()
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and Enum and Enum.FlightPathState) then
        return
    end
    local mapID = (GetTaxiMapID and GetTaxiMapID()) or C_Map.GetBestMapForUnit("player")
    if not mapID then
        return
    end
    local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
    if not ok or not nodes then
        return
    end
    local known = KnownFlightPaths()
    for _, node in ipairs(nodes) do
        known[node.nodeID] = node.state ~= Enum.FlightPathState.Unreachable or nil
    end
end

ns.KnownFlightPaths = KnownFlightPaths

-- Pins for the flight masters on a zone or city map, for your faction.
local function FlightPins(mapID)
    local pins = {}
    if ns.db.showFlightMasters == false or not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then
        return pins
    end
    local info = C_Map.GetMapInfo(mapID)
    if not info or not Enum.UIMapType or info.mapType < Enum.UIMapType.Zone then
        return pins -- a continent or the world: too many to be useful
    end
    if C_TaxiMap.ShouldMapShowTaxiNodes and C_TaxiMap.ShouldMapShowTaxiNodes(mapID) then
        return pins -- Blizzard's own layer draws them here
    end
    local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
    if not ok or not nodes then
        return pins
    end
    local mine = UnitFactionGroup("player")
    local known = KnownFlightPaths()
    local checked = next(known) ~= nil -- a flight map was opened; where you stood is always in it
    local factions = Enum.FlightPathFaction or {}
    for _, node in ipairs(nodes) do
        local faction = (node.faction == factions.Horde and "Horde") or (node.faction == factions.Alliance and "Alliance")
        local x, y = node.position and node.position.x, node.position and node.position.y
        local onMap = x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1
        if onMap and (not faction or faction == mine) and not node.name:find("^zz") then
            -- discovered is nil while unknown: no flight map opened yet on this character.
            local discovered = nil
            if checked then
                discovered = known[node.nodeID] == true
            end
            pins[#pins + 1] = { name = node.name, note = "Flight Master", x = x, y = y, atlas = node.atlasName,
                taxiNode = node.nodeID, discovered = discovered }
        end
    end
    return pins
end

-- The pins to draw on a map. Only pins for your faction; dungeons only while
-- "show dungeons" is on; a quest giver only while they have a quest for you,
-- a quest objective NPC only while you still need to go there, and a turn-in
-- NPC only while a quest for them is ready (Quests.lua); a starting area's
-- class trainer only until you are past the level they teach up to. Trainers
-- are filtered first: a class trainer only for your class unless "show all class
-- trainers" is on; with "show all profession trainers" off, secondary
-- professions and your own primary ones always, other primary ones only while
-- you still have a free slot. Then of a profession's ranked trainers only one
-- is drawn. Everything else is drawn as it is.
local function PinsToShow(mapID)
    local shown, groups = {}, {}
    local showAll = ns.db and ns.db.showAllTrainers
    local showAllClasses = ns.db and ns.db.showAllClassTrainers
    local showDungeons = not (ns.db and ns.db.showDungeons == false)
    local freeSlot = PrimaryCount() < 2
    local _, playerClass = UnitClass("player")
    local level = UnitLevel("player") or 0
    EachPin(mapID, function(pin)
        local profession, cap, word = TrainerInfo(pin)
        if not ForMyFaction(pin, mapID) then
            return
        elseif pin.teachesUpTo and level > pin.teachesUpTo then
            return -- a starting area's trainer with nothing left for your level
        elseif pin.dungeon then
            if showDungeons then
                shown[#shown + 1] = pin
            end
        elseif pin.questGiver then
            if ns.HasQuestToGive(pin.npc) then
                shown[#shown + 1] = pin
            end
        elseif pin.questObjective then
            if ns.IsObjectiveOpen(pin.npc) then
                shown[#shown + 1] = pin
            end
        elseif pin.questFinish then
            if ns.HasQuestToTurnIn(pin.npc) then
                shown[#shown + 1] = pin
            end
        elseif profession == nil then
            shown[#shown + 1] = pin
        elseif profession and profession.class then
            if showAllClasses or profession.class == playerClass then
                shown[#shown + 1] = pin
            end
        elseif showAll or not profession or not profession.primary or ProfessionMax(profession) or freeSlot then
            if cap then
                local key = profession and profession.line or word
                groups[key] = groups[key] or { profession = profession }
                table.insert(groups[key], { pin = pin, cap = cap })
            else
                shown[#shown + 1] = pin
            end
        end
    end)
    for _, group in pairs(groups) do
        shown[#shown + 1] = ChooseTrainer(group.profession, group)
    end
    for _, pin in ipairs(FlightPins(mapID)) do
        shown[#shown + 1] = pin
    end
    return shown
end

-- Map ID and position (0 to 1) of a unit on the player's current map, or nil.
-- The client only answers for the player and group members; an NPC target
-- comes back nil, so record an NPC by standing next to it.
local function UnitMapPosition(unit)
    if not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
        return nil
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return nil
    end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
    local x, y
    if ok and pos then
        x, y = pos:GetXY()
    end
    if not x or not y then
        return nil
    end
    return mapID, x, y
end
ns.UnitMapPosition = UnitMapPosition
ns.MapName = MapName

--------------------------------------------------------------------------------
-- The pin: one icon, positioned by the map, with the tooltip
--------------------------------------------------------------------------------

-- The ring is Sink's identity colour (ns.accent, Core.lua) and white under the mouse.
local function TintRing(pin, hovered)
    if hovered then
        pin.Ring:SetVertexColor(1, 1, 1)
    else
        pin.Ring:SetVertexColor(ns.accent.r, ns.accent.g, ns.accent.b)
    end
end

-- Global because MapPins.xml names it as the template's mixin.
SinkMapPinMixin = CreateFromMixins(MapCanvasPinMixin or {})

-- Called by the map once per pin frame. The overlay button forwards mouse
-- enter and leave to the pin so the tooltip still works, and lets right clicks
-- through so the map still zooms out.
function SinkMapPinMixin:OnLoad()
    -- Pins are children of the zoomed canvas. With scaling limits set, the map
    -- divides the pin's scale by the canvas scale on every zoom change; equal
    -- start and end values keep it the same size on screen at any zoom.
    self:SetScalingLimits(1, 1.0, 1.0)

    -- Pins that land on each other push apart on screen; the stored position
    -- stays exact. Every Sink pin is both a nudge source and a target, so two
    -- of them separate symmetrically; pins more than 1.5% of the map apart are
    -- left alone. A fully overlapping pin moves by 1.5% of the map times the
    -- zoom factor, which is the product of the target's zoomed-out or zoomed-in
    -- factor and the source's magnitude. Pins keep a fixed pixel size while the
    -- push is a fraction of the map, so the zoomed-in factor is smaller: two
    -- 24 px pins end up just clear of each other at either end of the zoom.
    self:SetNudgeSourceRadius(1)
    self:SetNudgeSourceMagnitude(1, 1)
    self:SetNudgeTargetFactor(0.015)
    self:SetNudgeZoomedOutFactor(1)
    self:SetNudgeZoomedInFactor(0.5)

    pinFrames[self] = true
    local button = CreateFrame("Button", nil, buttonHolder, "SecureActionButtonTemplate")
    -- The secure handler runs the action once, on down or up per ActionButtonUseKeyDown.
    button:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    button:SetScript("OnEnter", function(b)
        b:GetParent():OnMouseEnter()
    end)
    button:SetScript("OnLeave", function(b)
        b:GetParent():OnMouseLeave()
    end)
    button:Hide()
    self.ClickButton = button
end

-- Take a pin's button off it, back to the holder, so the pin is an ordinary
-- frame again. Only possible out of combat, or as combat starts.
local function DetachClickButton(pinFrame)
    local button = pinFrame.ClickButton
    if button and button:GetParent() ~= buttonHolder then
        button:SetParent(buttonHolder)
        button:ClearAllPoints()
        button:Hide()
    end
end

-- A secure button's attributes can only be changed out of combat. A pin
-- acquired during a fight has no button, and every pin is redone when the
-- fight ends.
function SinkMapPinMixin:SetClickTarget(name)
    local button = self.ClickButton
    if not button then
        return
    end
    if InCombatLockdown() then
        refreshAfterCombat = true
        return
    end
    if name then
        button:SetParent(self)
        button:ClearAllPoints()
        button:SetAllPoints(self)
        -- Right clicks go through to the map, which zooms out. Set here, out of
        -- combat, as SetPassThroughButtons is blocked for addons in combat.
        pcall(button.SetPassThroughButtons, button, "RightButton")
        button:SetAttribute("type", "macro")
        -- Clearing first makes the previous target the "last target". If the
        -- NPC is not found, nothing is pinged and the last line puts the
        -- previous target back; if it is found, that line is skipped. No ping
        -- type means the contextual ping, the plain one.
        button:SetAttribute("macrotext", table.concat({
            "/cleartarget",
            "/targetexact " .. name,
            "/ping [@target,exists]",
            "/targetlasttarget [@target,noexists]",
        }, "\n"))
        button:Show()
    else
        button:SetAttribute("type", nil)
        DetachClickButton(self)
    end
end

function SinkMapPinMixin:OnAcquired(pin) -- pin is the table from ns.mapPins or ns.db.mapPins
    self.pin = pin
    -- An atlas sets its own coordinates; an icon has its dark edge trimmed
    -- before the circle clips it. An atlas the client lacks falls back to the default icon.
    if not (pin.atlas and self.Icon:SetAtlas(pin.atlas)) then
        self.Icon:SetTexture(pin.icon or DEFAULT_ICON)
        self.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    -- A flight path is drawn grey unless you are known to have it, so before
    -- any flight map is opened they all are; pins are reused, so always set it.
    self.Icon:SetDesaturated(pin.taxiNode ~= nil and pin.discovered ~= true)
    TintRing(self, false)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI") -- same layer as Blizzard's points of interest
    self:SetPosition(pin.x, pin.y)
    self:SetClickTarget(pin.npc and pin.name or nil) -- only icons that mark an NPC target on click
end

-- Clicks go through to the map, so a left click zooms in and a right click
-- zooms out. The map calls this after OnAcquired, since pins are reused.
-- SetPassThroughButtons is blocked for addon code in combat ("Interface
-- action failed because of an AddOn"), so then it is skipped: a reused pin
-- keeps the setting it already has, which never changes, and pins are redone
-- when combat ends.
function SinkMapPinMixin:CheckMouseButtonPassthrough(...)
    if InCombatLockdown() then
        refreshAfterCombat = true
        return
    end
    pcall(self.SetPassThroughButtons, self, "LeftButton", "RightButton")
end

-- Make the pin for an NPC pulse for a few seconds so it stands out.
local function Pulse(pinFrame)
    if not pinFrame.PulseAnim then
        local group = pinFrame:CreateAnimationGroup()
        local grow = group:CreateAnimation("Scale")
        grow:SetScale(1.6, 1.6)
        grow:SetDuration(0.35)
        grow:SetOrder(1)
        local shrink = group:CreateAnimation("Scale")
        shrink:SetScale(1 / 1.6, 1 / 1.6)
        shrink:SetDuration(0.35)
        shrink:SetOrder(2)
        group:SetLooping("REPEAT")
        pinFrame.PulseAnim = group
    end
    pinFrame.PulseAnim:Play()
    C_Timer.After(3, function()
        pinFrame.PulseAnim:Stop()
    end)
end

-- Open the world map where an NPC stands and make their pin pulse. The
-- Sink tracker calls it when you click a red quest.
local function ShowNPC(npcID, npc)
    local map = provider and provider:GetMap()
    if not map then
        return
    end
    GameTooltip:Hide()
    if not map:IsShown() then
        -- Opening it goes through the secure panel manager, blocked for addons in combat.
        if InCombatLockdown() then
            return
        end
        ShowUIPanel(map)
    end
    map:SetMapID((ZonePosition(npc.map, npc.x, npc.y)))
    -- The new map's pins are drawn a moment after it opens or changes; look then.
    C_Timer.After(0.1, function()
        for pinFrame in map:EnumeratePinsByTemplate(TEMPLATE) do
            if pinFrame.pin and pinFrame.pin.npc == npcID then
                Pulse(pinFrame)
            end
        end
    end)
end
ns.ShowNPCOnMap = ShowNPC

function SinkMapPinMixin:OnMouseEnter()
    TintRing(self, true)
    local pin = self.pin
    if not pin then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(NoteText(pin), ns.accent.r, ns.accent.g, ns.accent.b)
    if pin.npc and ns.AddRecipeVendorLines then
        ns.AddRecipeVendorLines(GameTooltip, pin.npc)
    end
    if pin.npc and ns.AddWeaponMasterLines then
        ns.AddWeaponMasterLines(GameTooltip, pin.npc)
    end
    if pin.npc and ns.AddClassTrainingLines then
        local profession = TrainerInfo(pin)
        if profession and profession.class and not profession.specialty then
            ns.AddClassTrainingLines(GameTooltip, profession.class)
        end
    end
    if pin.taxiNode then
        GameTooltip:AddLine(pin.name, 1, 1, 1)
        if pin.discovered == nil then
            GameTooltip:AddLine("Unknown until you open a flight master's map", ns.grey.r, ns.grey.g, ns.grey.b)
        elseif pin.discovered then
            GameTooltip:AddLine(ns.CHECK .. " Discovered", ns.known.r, ns.known.g, ns.known.b)
        else
            GameTooltip:AddLine(ns.CROSS .. " Not discovered", ns.missing.r, ns.missing.g, ns.missing.b)
        end
    end
    if pin.questIDs and ns.AddQuestLines then
        ns.AddQuestLines(GameTooltip, pin.questIDs)
    end
    GameTooltip:Show()
end

function SinkMapPinMixin:OnMouseLeave()
    TintRing(self, false)
    GameTooltip:Hide()
end

--------------------------------------------------------------------------------
-- The data provider: asked to refresh whenever the map opens or changes zone
--------------------------------------------------------------------------------

local SinkMapDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin or {})

function SinkMapDataProviderMixin:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function SinkMapDataProviderMixin:RefreshAllData()
    self:RemoveAllData()
    if not Enabled() then
        return
    end
    local map = self:GetMap()
    for _, pin in ipairs(PinsToShow(map:GetMapID())) do
        map:AcquirePin(TEMPLATE, pin)
    end
end

-- Redraw our icons if the map is open; a closed map refreshes itself on show.
local function Refresh()
    local map = provider and provider:GetMap()
    if map and map:IsShown() then
        provider:RefreshAllData()
    end
end
ns.RefreshMapPins = Refresh

local function Install()
    if provider or not WorldMapFrame or not WorldMapFrame.AddDataProvider
        or not MapCanvasDataProviderMixin or not MapCanvasPinMixin then
        return
    end
    provider = CreateFromMixins(SinkMapDataProviderMixin)
    WorldMapFrame:AddDataProvider(provider)
end

--------------------------------------------------------------------------------
-- /sink map ...
--------------------------------------------------------------------------------

local function MapHelp()
    ns.Print("map icon commands")
    print("  /sink map                     list the icons by zone")
    print("  /sink map add <name>          put an icon where you stand (saved per character)")
    print("  /sink map remove <name>       remove an icon you added")
    print("  /sink map on | off            show or hide the icons")
    print("  /sink map trainers all | mine every profession trainer, or only the ones for you")
    print("  /sink map classes all | mine  every class trainer, or only your class's")
end

-- Through the options window when it exists, so its checkboxes follow.
local function SetOption(key, value)
    if ns.SetOption then
        ns.SetOption(key, value)
    else
        ns.db[key] = value
        Refresh()
    end
end

-- The Lua for one icon, as it would sit in ns.mapPins. Dump.lua uses it too.
local function PinLine(mapID, pin)
    local fields = {}
    if pin.npc then
        fields[#fields + 1] = "npc = " .. pin.npc
    end
    fields[#fields + 1] = ("name = %q"):format(pin.name or "?")
    if pin.note then
        fields[#fields + 1] = ("note = %q"):format(pin.note)
    end
    fields[#fields + 1] = ("x = %.4f, y = %.4f"):format(pin.x, pin.y)
    fields[#fields + 1] = "verified = true" -- a dump is taken standing there
    return ("  { %s }, -- ns.mapPins[%d], %s"):format(table.concat(fields, ", "), mapID, MapName(mapID))
end
ns.MapPinLine = PinLine

local function ListPins()
    local seen, mapIDs = {}, {}
    for mapID in pairs(ns.mapPins) do
        seen[mapID] = true
        mapIDs[#mapIDs + 1] = mapID
    end
    for mapID in pairs(CustomPins() or {}) do
        if not seen[mapID] then
            mapIDs[#mapIDs + 1] = mapID
        end
    end
    table.sort(mapIDs)
    if #mapIDs == 0 then
        ns.Print("no map icons. Stand somewhere and use /sink map add <name>.")
        return
    end
    for _, mapID in ipairs(mapIDs) do
        print(("  %s (%d)"):format(MapName(mapID), mapID))
        EachPin(mapID, function(pin)
            print(("    %s at %s%s"):format(pin.name, Coords(pin.x, pin.y), pin.note and (", " .. NoteText(pin)) or ""))
        end)
    end
end

local function AddPin(name)
    local mapID, x, y = UnitMapPosition("player")
    if not mapID then
        ns.Print("the client does not report a map position here.")
        return
    end
    ns.db.mapPins[mapID] = ns.db.mapPins[mapID] or {}
    table.insert(ns.db.mapPins[mapID], { name = name, x = x, y = y, icon = DEFAULT_ICON })
    ns.Print(("%s added at %s in %s. To keep it, paste this into MapPins.lua:"):format(name, Coords(x, y), MapName(mapID)))
    print(PinLine(mapID, { name = name, x = x, y = y }))
    Refresh()
end

local function RemovePin(name)
    local wanted = name:lower()
    for mapID, pins in pairs(ns.db.mapPins) do
        for i = #pins, 1, -1 do
            if pins[i].name:lower() == wanted then
                table.remove(pins, i)
                if #pins == 0 then
                    ns.db.mapPins[mapID] = nil
                end
                ns.Print(("removed %s from %s."):format(name, MapName(mapID)))
                Refresh()
                return
            end
        end
    end
    ns.Print("no icon named " .. name .. " was added in game; built-in ones live in MapPins.lua.")
end

function ns.MapCommand(arg)
    if not ns.db then
        return
    end
    ns.db.mapPins = ns.db.mapPins or {}
    local sub, rest = (arg or ""):match("^(%S*)%s*(.-)%s*$")
    sub = sub:lower()

    if sub == "" or sub == "list" then
        ListPins()
    elseif sub == "add" then
        if rest == "" then
            ns.Print("usage: /sink map add <name>")
            return
        end
        AddPin(rest)
    elseif sub == "remove" then
        if rest == "" then
            ns.Print("usage: /sink map remove <name>")
            return
        end
        RemovePin(rest)
    elseif sub == "on" or sub == "off" then
        SetOption("mapIcons", sub == "on")
        ns.Print("map icons " .. (sub == "on" and "|cff00ff00on|r" or "|cffff0000off|r") .. ".")
    elseif sub == "trainers" then
        local mode = rest:lower()
        if mode ~= "all" and mode ~= "mine" then
            ns.Print("usage: /sink map trainers all | mine")
            return
        end
        SetOption("showAllTrainers", mode == "all")
        ns.Print("profession trainers shown: " .. (mode == "all" and "all of them"
            or "yours, the secondary ones, and every primary one while you have a free slot") .. ".")
    elseif sub == "classes" then
        local mode = rest:lower()
        if mode ~= "all" and mode ~= "mine" then
            ns.Print("usage: /sink map classes all | mine")
            return
        end
        SetOption("showAllClassTrainers", mode == "all")
        ns.Print("class trainers shown: " .. (mode == "all" and "all of them" or "your class's only") .. ".")
    else
        MapHelp()
    end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- QUEST_LOG_UPDATE fires often, and a redraw closes the tooltip under the
-- mouse, so it only redraws when an objective or turn-in pin comes or goes.
local objectivesSeen, finishesSeen = {}, {}
local function ObjectivesChanged()
    local changed = false
    local function check(each, test, seen)
        if not each then
            return
        end
        each(function(npcID)
            local now = test(npcID)
            if seen[npcID] ~= now then
                seen[npcID] = now
                changed = true
            end
        end)
    end
    check(ns.EachObjectiveNPC, ns.IsObjectiveOpen, objectivesSeen)
    check(ns.EachFinishNPC, ns.HasQuestToTurnIn, finishesSeen)
    return changed
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Which trainer to draw depends on your skills; redraw when they change.
pcall(frame.RegisterEvent, frame, "SKILL_LINES_CHANGED")
-- Quest givers show while they have a quest for you, which depends on your
-- quests and your level; redraw when either changes.
pcall(frame.RegisterEvent, frame, "PLAYER_LEVEL_UP")
pcall(frame.RegisterEvent, frame, "QUEST_ACCEPTED")
pcall(frame.RegisterEvent, frame, "QUEST_TURNED_IN")
pcall(frame.RegisterEvent, frame, "QUEST_REMOVED")
-- Objectives completing change which objective NPCs are shown.
pcall(frame.RegisterEvent, frame, "QUEST_LOG_UPDATE")
-- A flight master's map lists the paths you have; talking to one discovers it.
pcall(frame.RegisterEvent, frame, "TAXIMAP_OPENED")
pcall(frame.RegisterEvent, frame, "TAXI_NODE_STATUS_CHANGED")
-- Combat starting: take every click button off its pin. This event comes just
-- before the lockdown, while that is still allowed; they go back when it ends.
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Install()
    elseif event == "PLAYER_REGEN_DISABLED" then
        for pinFrame in pairs(pinFrames) do
            DetachClickButton(pinFrame)
        end
        refreshAfterCombat = true
    elseif event == "TAXIMAP_OPENED" then
        RecordFlightPaths()
        Refresh()
    elseif event == "TAXI_NODE_STATUS_CHANGED" then
        Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" and refreshAfterCombat then
        refreshAfterCombat = false
        Refresh()
    elseif event == "PLAYER_LEVEL_UP" then
        C_Timer.After(1, Refresh) -- UnitLevel still has the old level while this event runs
    elseif event == "SKILL_LINES_CHANGED" or event == "QUEST_ACCEPTED"
        or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        Refresh()
    elseif event == "QUEST_LOG_UPDATE" and ObjectivesChanged() then
        Refresh()
    end
end)
