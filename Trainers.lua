--------------------------------------------------------------------------------
-- Sink / Trainers.lua
--
-- Class training: what your class trainer teaches, which of it you can learn
-- now, and what comes next. Hover your class's trainer, or their map icon,
-- and the tooltip lists each skill you have not learned and can learn now
-- (red cross), then a blank line and "Next Skills (Level N)" with the skills
-- at the next level that has any, in white.
--
-- What a trainer teaches has no API outside the trainer window, so it is
-- built into the addon: ns.classTraining below, one list per class, pasted from
-- "/sink dump trainer" at that class's trainer. Nothing is saved from the
-- window in game. Each skill has its name, level, spell ID, rank and cost.
-- With the spell ID, IsPlayerSpell says whether you know the skill at any
-- time. A skill's rank, "Holy Light (Rank 2)", is the text the trainer shows
-- under it; a skill without one asks the spell for its subtext. Of several
-- ranks you could learn, only the highest is listed. cost is in copper, so
-- the tracker can total what the skills you can learn now will cost. A class
-- with no list here shows nothing.
--------------------------------------------------------------------------------

local _, ns = ...

-- Class skill lists, by class token: { { name, level, spell, rank, cost }, ... },
-- from "/sink dump trainer"; cost is in copper and may be missing. A trainer
-- lists a skill you already know at level 0, so take those levels from a
-- character who does not know it yet, such as the starting area's trainer.
-- rank is the trainer's text for it, "" for none; only "Rank N" is shown. A
-- skill without a rank gets the spell's subtext.
ns.classTraining = {}

ns.classTraining.PALADIN = {
    { name = "Devotion Aura", level = 1, spell = 465, rank = "Rank 1", cost = 10 },
    { name = "Blessing of Might", level = 4, spell = 19740, rank = "Rank 1", cost = 100 },
    { name = "Judgement", level = 4, spell = 20271, rank = "", cost = 100 },
    { name = "Divine Protection", level = 6, spell = 498, rank = "Rank 1", cost = 100 },
    { name = "Holy Light", level = 6, spell = 639, rank = "Rank 2", cost = 100 },
    { name = "Holy Strike", level = 6, spell = 679, rank = "Rank 1", cost = 100 },
    { name = "Seal of the Crusader", level = 6, spell = 21082, rank = "Rank 1", cost = 100 },
    { name = "Hammer of Justice", level = 8, spell = 853, rank = "Rank 1", cost = 100 },
    { name = "Parry", level = 8, spell = 3127, rank = "Passive", cost = 100 },
    { name = "Purify", level = 8, spell = 1152, rank = "", cost = 100 },
    { name = "Blessing of Protection", level = 10, spell = 1022, rank = "Rank 1", cost = 300 },
    { name = "Devotion Aura", level = 10, spell = 10290, rank = "Rank 2", cost = 300 },
    { name = "Lay on Hands", level = 10, spell = 633, rank = "Rank 1", cost = 300 },
    { name = "Seal of Fury", level = 10, spell = 1311649, rank = "Rank 1", cost = 300 },
    { name = "Seal of Righteousness", level = 10, spell = 20287, rank = "Rank 2", cost = 300 },
    { name = "Blessing of Might", level = 12, spell = 19834, rank = "Rank 2", cost = 1000 },
    { name = "Holy Strike", level = 12, spell = 678, rank = "Rank 2", cost = 1000 },
    { name = "Seal of the Crusader", level = 12, spell = 20162, rank = "Rank 2", cost = 1000 },
    { name = "Blessing of Wisdom", level = 14, spell = 19742, rank = "Rank 1", cost = 2000 },
    { name = "Holy Light", level = 14, spell = 647, rank = "Rank 3", cost = 2000 },
    { name = "Retribution Aura", level = 16, spell = 7294, rank = "Rank 1", cost = 3000 },
    { name = "Righteous Fury", level = 16, spell = 25780, rank = "", cost = 3000 },
    { name = "Blessing of Freedom", level = 18, spell = 1044, rank = "", cost = 3500 },
    { name = "Divine Protection", level = 18, spell = 5573, rank = "Rank 2", cost = 3500 },
    { name = "Seal of Fury", level = 18, spell = 1311656, rank = "Rank 2", cost = 3500 },
    { name = "Seal of Righteousness", level = 18, spell = 20288, rank = "Rank 3", cost = 3500 },
    { name = "Blessing of Kings", level = 20, spell = 20217, rank = "", cost = 4000 },
    { name = "Consecration", level = 20, spell = 26573, rank = "Rank 1", cost = 4000 },
    { name = "Devotion Aura", level = 20, spell = 643, rank = "Rank 3", cost = 4000 },
    { name = "Exorcism", level = 20, spell = 879, rank = "Rank 1", cost = 4000 },
    { name = "Flash of Light", level = 20, spell = 19750, rank = "Rank 1", cost = 4000 },
    { name = "Holy Strike", level = 20, spell = 1866, rank = "Rank 3", cost = 4000 },
    { name = "Blessing of Might", level = 22, spell = 19835, rank = "Rank 3", cost = 4000 },
    { name = "Concentration Aura", level = 22, spell = 19746, rank = "", cost = 4000 },
    { name = "Holy Light", level = 22, spell = 1026, rank = "Rank 4", cost = 4000 },
    { name = "Seal of Justice", level = 22, spell = 20164, rank = "", cost = 4000 },
    { name = "Seal of the Crusader", level = 22, spell = 20305, rank = "Rank 3", cost = 4000 },
    { name = "Blessing of Protection", level = 24, spell = 5599, rank = "Rank 2", cost = 5000 },
    { name = "Blessing of Wisdom", level = 24, spell = 19850, rank = "Rank 2", cost = 5000 },
    { name = "Hammer of Justice", level = 24, spell = 5588, rank = "Rank 2", cost = 5000 },
    { name = "Redemption", level = 24, spell = 10322, rank = "Rank 2", cost = 5000 },
    { name = "Turn Undead", level = 24, spell = 2878, rank = "Rank 1", cost = 5000 },
    { name = "Seal of Fury", level = 25, spell = 20163, rank = "Rank 3", cost = 6000 },
    { name = "Blessing of Salvation", level = 26, spell = 1038, rank = "", cost = 6000 },
    { name = "Flash of Light", level = 26, spell = 19939, rank = "Rank 2", cost = 6000 },
    { name = "Retribution Aura", level = 26, spell = 10298, rank = "Rank 2", cost = 6000 },
    { name = "Seal of Righteousness", level = 26, spell = 20289, rank = "Rank 4", cost = 6000 },
    { name = "Exorcism", level = 28, spell = 5614, rank = "Rank 2", cost = 9000 },
    { name = "Holy Strike", level = 28, spell = 680, rank = "Rank 4", cost = 9000 },
    { name = "Shadow Resistance Aura", level = 28, spell = 19876, rank = "Rank 1", cost = 9000 },
    { name = "Consecration", level = 30, spell = 20116, rank = "Rank 2", cost = 11000 },
    { name = "Devotion Aura", level = 30, spell = 10291, rank = "Rank 4", cost = 11000 },
    { name = "Divine Intervention", level = 30, spell = 19752, rank = "", cost = 11000 },
    { name = "Holy Light", level = 30, spell = 1042, rank = "Rank 5", cost = 11000 },
    { name = "Lay on Hands", level = 30, spell = 2800, rank = "Rank 2", cost = 11000 },
    { name = "Seal of Command", level = 30, spell = 20915, rank = "Rank 2", cost = 550 },
    { name = "Seal of Light", level = 30, spell = 20165, rank = "Rank 1", cost = 11000 },
    { name = "Blessing of Might", level = 32, spell = 19836, rank = "Rank 4", cost = 12000 },
    { name = "Frost Resistance Aura", level = 32, spell = 19888, rank = "Rank 1", cost = 12000 },
    { name = "Seal of the Crusader", level = 32, spell = 20306, rank = "Rank 4", cost = 12000 },
    { name = "Blessing of Wisdom", level = 34, spell = 19852, rank = "Rank 3", cost = 13000 },
    { name = "Divine Shield", level = 34, spell = 642, rank = "Rank 1", cost = 13000 },
    { name = "Flash of Light", level = 34, spell = 19940, rank = "Rank 3", cost = 13000 },
    { name = "Seal of Fury", level = 34, spell = 20419, rank = "Rank 4", cost = 13000 },
    { name = "Seal of Righteousness", level = 34, spell = 20290, rank = "Rank 5", cost = 13000 },
    { name = "Exorcism", level = 36, spell = 5615, rank = "Rank 3", cost = 14000 },
    { name = "Fire Resistance Aura", level = 36, spell = 19891, rank = "Rank 1", cost = 14000 },
    { name = "Holy Strike", level = 36, spell = 2495, rank = "Rank 5", cost = 14000 },
    { name = "Redemption", level = 36, spell = 10324, rank = "Rank 3", cost = 14000 },
    { name = "Retribution Aura", level = 36, spell = 10299, rank = "Rank 3", cost = 14000 },
    { name = "Blessing of Protection", level = 38, spell = 10278, rank = "Rank 3", cost = 16000 },
    { name = "Holy Light", level = 38, spell = 3472, rank = "Rank 6", cost = 16000 },
    { name = "Seal of Wisdom", level = 38, spell = 20166, rank = "Rank 1", cost = 16000 },
    { name = "Turn Undead", level = 38, spell = 5627, rank = "Rank 2", cost = 16000 },
    { name = "Blessing of Light", level = 40, spell = 19977, rank = "Rank 1", cost = 20000 },
    { name = "Consecration", level = 40, spell = 20922, rank = "Rank 3", cost = 20000 },
    { name = "Devotion Aura", level = 40, spell = 1032, rank = "Rank 5", cost = 20000 },
    { name = "Hammer of Justice", level = 40, spell = 5589, rank = "Rank 3", cost = 20000 },
    { name = "Holy Shock", level = 40, spell = 20473, rank = "Rank 2", cost = 1000 },
    { name = "Plate Mail", level = 40, spell = 750, rank = "", cost = 20000 },
    { name = "Seal of Command", level = 40, spell = 20918, rank = "Rank 3", cost = 1000 },
    { name = "Seal of Light", level = 40, spell = 20347, rank = "Rank 2", cost = 20000 },
    { name = "Shadow Resistance Aura", level = 40, spell = 19895, rank = "Rank 2", cost = 20000 },
    { name = "Blessing of Might", level = 42, spell = 19837, rank = "Rank 5", cost = 21000 },
    { name = "Cleanse", level = 42, spell = 4987, rank = "", cost = 21000 },
    { name = "Flash of Light", level = 42, spell = 19941, rank = "Rank 4", cost = 21000 },
    { name = "Seal of Fury", level = 42, spell = 20421, rank = "Rank 5", cost = 21000 },
    { name = "Seal of Righteousness", level = 42, spell = 20291, rank = "Rank 6", cost = 21000 },
    { name = "Seal of the Crusader", level = 42, spell = 20307, rank = "Rank 5", cost = 21000 },
    { name = "Blessing of Wisdom", level = 44, spell = 19853, rank = "Rank 4", cost = 22000 },
    { name = "Exorcism", level = 44, spell = 10312, rank = "Rank 4", cost = 22000 },
    { name = "Frost Resistance Aura", level = 44, spell = 19897, rank = "Rank 2", cost = 22000 },
    { name = "Hammer of Wrath", level = 44, spell = 24275, rank = "Rank 1", cost = 22000 },
    { name = "Holy Strike", level = 44, spell = 5569, rank = "Rank 6", cost = 22000 },
    { name = "Blessing of Sacrifice", level = 46, spell = 6940, rank = "Rank 1", cost = 24000 },
    { name = "Holy Light", level = 46, spell = 10328, rank = "Rank 7", cost = 24000 },
    { name = "Retribution Aura", level = 46, spell = 10300, rank = "Rank 4", cost = 24000 },
    { name = "Fire Resistance Aura", level = 48, spell = 19899, rank = "Rank 2", cost = 26000 },
    { name = "Holy Shock", level = 48, spell = 20929, rank = "Rank 3", cost = 1300 },
    { name = "Redemption", level = 48, spell = 20772, rank = "Rank 4", cost = 26000 },
    { name = "Seal of Wisdom", level = 48, spell = 20356, rank = "Rank 2", cost = 26000 },
    { name = "Blessing of Light", level = 50, spell = 19978, rank = "Rank 2", cost = 28000 },
    { name = "Consecration", level = 50, spell = 20923, rank = "Rank 4", cost = 28000 },
    { name = "Devotion Aura", level = 50, spell = 10292, rank = "Rank 6", cost = 28000 },
    { name = "Divine Shield", level = 50, spell = 1020, rank = "Rank 2", cost = 28000 },
    { name = "Flash of Light", level = 50, spell = 19942, rank = "Rank 5", cost = 28000 },
    { name = "Holy Shield", level = 50, spell = 20927, rank = "Rank 2", cost = 1400 },
    { name = "Holy Wrath", level = 50, spell = 2812, rank = "Rank 1", cost = 28000 },
    { name = "Lay on Hands", level = 50, spell = 10310, rank = "Rank 3", cost = 28000 },
    { name = "Light's Vigil", level = 50, spell = 1311590, rank = "Rank 2", cost = 1400 },
    { name = "Seal of Command", level = 50, spell = 20919, rank = "Rank 4", cost = 1400 },
    { name = "Seal of Fury", level = 50, spell = 20422, rank = "Rank 6", cost = 28000 },
    { name = "Seal of Light", level = 50, spell = 20348, rank = "Rank 3", cost = 28000 },
    { name = "Seal of Righteousness", level = 50, spell = 20292, rank = "Rank 7", cost = 28000 },
    { name = "Blessing of Might", level = 52, spell = 19838, rank = "Rank 6", cost = 34000 },
    { name = "Exorcism", level = 52, spell = 10313, rank = "Rank 5", cost = 34000 },
    { name = "Greater Blessing of Might", level = 52, spell = 25782, rank = "Rank 1", cost = 46000 },
    { name = "Hammer of Wrath", level = 52, spell = 24274, rank = "Rank 2", cost = 34000 },
    { name = "Holy Strike", level = 52, spell = 10332, rank = "Rank 7", cost = 34000 },
    { name = "Seal of the Crusader", level = 52, spell = 20308, rank = "Rank 6", cost = 34000 },
    { name = "Shadow Resistance Aura", level = 52, spell = 19896, rank = "Rank 3", cost = 34000 },
    { name = "Turn Undead", level = 52, spell = 10326, rank = "Rank 3", cost = 34000 },
    { name = "Blessing of Sacrifice", level = 54, spell = 20729, rank = "Rank 2", cost = 40000 },
    { name = "Blessing of Wisdom", level = 54, spell = 19854, rank = "Rank 5", cost = 40000 },
    { name = "Greater Blessing of Wisdom", level = 54, spell = 25894, rank = "Rank 1", cost = 46000 },
    { name = "Hammer of Justice", level = 54, spell = 10308, rank = "Rank 4", cost = 40000 },
    { name = "Holy Light", level = 54, spell = 10329, rank = "Rank 8", cost = 40000 },
    { name = "Frost Resistance Aura", level = 56, spell = 19898, rank = "Rank 3", cost = 42000 },
    { name = "Holy Shock", level = 56, spell = 20930, rank = "Rank 4", cost = 2100 },
    { name = "Retribution Aura", level = 56, spell = 10301, rank = "Rank 5", cost = 42000 },
    { name = "Flash of Light", level = 58, spell = 19943, rank = "Rank 6", cost = 44000 },
    { name = "Seal of Fury", level = 58, spell = 20423, rank = "Rank 7", cost = 44000 },
    { name = "Seal of Righteousness", level = 58, spell = 20293, rank = "Rank 8", cost = 44000 },
    { name = "Seal of Wisdom", level = 58, spell = 20357, rank = "Rank 3", cost = 44000 },
    { name = "Blessing of Light", level = 60, spell = 19979, rank = "Rank 3", cost = 46000 },
    { name = "Consecration", level = 60, spell = 20924, rank = "Rank 5", cost = 46000 },
    { name = "Devotion Aura", level = 60, spell = 10293, rank = "Rank 7", cost = 46000 },
    { name = "Exorcism", level = 60, spell = 10314, rank = "Rank 6", cost = 46000 },
    { name = "Fire Resistance Aura", level = 60, spell = 19900, rank = "Rank 3", cost = 46000 },
    { name = "Greater Blessing of Kings", level = 60, spell = 25898, rank = "", cost = 46000 },
    { name = "Greater Blessing of Light", level = 60, spell = 25890, rank = "", cost = 46000 },
    { name = "Greater Blessing of Might", level = 60, spell = 25916, rank = "Rank 2", cost = 46000 },
    { name = "Greater Blessing of Salvation", level = 60, spell = 25895, rank = "", cost = 46000 },
    { name = "Greater Blessing of Wisdom", level = 60, spell = 25918, rank = "Rank 2", cost = 46000 },
    { name = "Hammer of Wrath", level = 60, spell = 24239, rank = "Rank 3", cost = 46000 },
    { name = "Holy Shield", level = 60, spell = 20928, rank = "Rank 3", cost = 2300 },
    { name = "Holy Strike", level = 60, spell = 10333, rank = "Rank 8", cost = 46000 },
    { name = "Holy Wrath", level = 60, spell = 10318, rank = "Rank 2", cost = 46000 },
    { name = "Light's Vigil", level = 60, spell = 1311595, rank = "Rank 3", cost = 2300 },
    { name = "Redemption", level = 60, spell = 20773, rank = "Rank 5", cost = 46000 },
    { name = "Seal of Command", level = 60, spell = 20920, rank = "Rank 5", cost = 2300 },
    { name = "Seal of Light", level = 60, spell = 20349, rank = "Rank 4", cost = 46000 },
}

ns.classTraining.WARLOCK = {
    { name = "Immolate", level = 1, spell = 348, rank = "Rank 1", cost = 10 },
    { name = "Corruption", level = 4, spell = 172, rank = "Rank 1", cost = 100 },
    { name = "Curse of Weakness", level = 4, spell = 702, rank = "Rank 1", cost = 100 },
    { name = "Life Tap", level = 6, spell = 1454, rank = "Rank 1", cost = 100 },
    { name = "Shadow Bolt", level = 6, spell = 695, rank = "Rank 2", cost = 100 },
    { name = "Bane of Agony", level = 8, spell = 980, rank = "Rank 1", cost = 200 },
    { name = "Fear", level = 8, spell = 5782, rank = "Rank 1", cost = 200 },
    { name = "Create Healthstone", level = 10, spell = 6201, rank = "Rank 1", cost = 300 },
    { name = "Demon Skin", level = 10, spell = 696, rank = "Rank 2", cost = 300 },
    { name = "Drain Soul", level = 10, spell = 1120, rank = "Rank 1", cost = 300 },
    { name = "Immolate", level = 10, spell = 707, rank = "Rank 2", cost = 300 },
    { name = "Curse of Weakness", level = 12, spell = 1108, rank = "Rank 2", cost = 600 },
    { name = "Health Funnel", level = 12, spell = 755, rank = "Rank 1", cost = 600 },
    { name = "Shadow Bolt", level = 12, spell = 705, rank = "Rank 3", cost = 600 },
    { name = "Corruption", level = 14, spell = 6222, rank = "Rank 2", cost = 900 },
    { name = "Curse of Recklessness", level = 14, spell = 704, rank = "Rank 1", cost = 900 },
    { name = "Drain Life", level = 14, spell = 689, rank = "Rank 1", cost = 900 },
    { name = "Life Tap", level = 16, spell = 1455, rank = "Rank 2", cost = 1200 },
    { name = "Unending Breath", level = 16, spell = 5697, rank = "", cost = 1200 },
    { name = "Bane of Agony", level = 18, spell = 1014, rank = "Rank 2", cost = 1500 },
    { name = "Create Soulstone", level = 18, spell = 693, rank = "Rank 1", cost = 1500 },
    { name = "Searing Pain", level = 18, spell = 5676, rank = "Rank 1", cost = 1500 },
    { name = "Curse of the Elements", level = 20, spell = 440892, rank = "Rank 1", cost = 2000 },
    { name = "Demon Armor", level = 20, spell = 706, rank = "Rank 1", cost = 2000 },
    { name = "Health Funnel", level = 20, spell = 3698, rank = "Rank 2", cost = 2000 },
    { name = "Immolate", level = 20, spell = 1094, rank = "Rank 3", cost = 2000 },
    { name = "Rain of Fire", level = 20, spell = 5740, rank = "Rank 1", cost = 2000 },
    { name = "Ritual of Summoning", level = 20, spell = 698, rank = "", cost = 2000 },
    { name = "Shadow Bolt", level = 20, spell = 1088, rank = "Rank 4", cost = 2000 },
    { name = "Create Healthstone", level = 22, spell = 6202, rank = "Rank 2", cost = 2500 },
    { name = "Curse of Weakness", level = 22, spell = 6205, rank = "Rank 3", cost = 2500 },
    { name = "Drain Life", level = 22, spell = 699, rank = "Rank 2", cost = 2500 },
    { name = "Eye of Kilrogg", level = 22, spell = 126, rank = "Summon", cost = 2500 },
    { name = "Corruption", level = 24, spell = 6223, rank = "Rank 3", cost = 3000 },
    { name = "Drain Mana", level = 24, spell = 5138, rank = "Rank 1", cost = 3000 },
    { name = "Drain Soul", level = 24, spell = 8288, rank = "Rank 2", cost = 3000 },
    { name = "Sense Demons", level = 24, spell = 5500, rank = "", cost = 3000 },
    { name = "Shadowburn", level = 24, spell = 18867, rank = "Rank 2", cost = 150 },
    { name = "Curse of Tongues", level = 26, spell = 1714, rank = "Rank 1", cost = 4000 },
    { name = "Detect Invisibility", level = 26, spell = 132, rank = "Rank 1", cost = 4000 },
    { name = "Life Tap", level = 26, spell = 1456, rank = "Rank 3", cost = 4000 },
    { name = "Searing Pain", level = 26, spell = 17919, rank = "Rank 2", cost = 4000 },
    { name = "Bane of Agony", level = 28, spell = 6217, rank = "Rank 3", cost = 5000 },
    { name = "Banish", level = 28, spell = 710, rank = "Rank 1", cost = 5000 },
    { name = "Create Firestone", level = 28, spell = 6366, rank = "Rank 1", cost = 5000 },
    { name = "Curse of Recklessness", level = 28, spell = 7658, rank = "Rank 2", cost = 5000 },
    { name = "Health Funnel", level = 28, spell = 3699, rank = "Rank 3", cost = 5000 },
    { name = "Shadow Bolt", level = 28, spell = 1106, rank = "Rank 5", cost = 5000 },
    { name = "Create Soulstone", level = 30, spell = 20752, rank = "Rank 2", cost = 6000 },
    { name = "Curse of the Elements", level = 30, spell = 1311676, rank = "Rank 2", cost = 6000 },
    { name = "Demon Armor", level = 30, spell = 1086, rank = "Rank 2", cost = 6000 },
    { name = "Drain Life", level = 30, spell = 709, rank = "Rank 3", cost = 6000 },
    { name = "Hellfire", level = 30, spell = 1949, rank = "Rank 1", cost = 6000 },
    { name = "Immolate", level = 30, spell = 2941, rank = "Rank 4", cost = 6000 },
    { name = "Subjugate Demon", level = 30, spell = 1098, rank = "Rank 1", cost = 6000 },
    { name = "Conflagrate", level = 32, spell = 1293818, rank = "Rank 2", cost = 300 },
    { name = "Curse of Weakness", level = 32, spell = 7646, rank = "Rank 4", cost = 7000 },
    { name = "Fear", level = 32, spell = 6213, rank = "Rank 2", cost = 7000 },
    { name = "Shadow Ward", level = 32, spell = 6229, rank = "Rank 1", cost = 7000 },
    { name = "Shadowburn", level = 32, spell = 18868, rank = "Rank 3", cost = 350 },
    { name = "Corruption", level = 34, spell = 7648, rank = "Rank 4", cost = 8000 },
    { name = "Create Healthstone", level = 34, spell = 5699, rank = "Rank 3", cost = 8000 },
    { name = "Drain Mana", level = 34, spell = 6226, rank = "Rank 2", cost = 8000 },
    { name = "Rain of Fire", level = 34, spell = 6219, rank = "Rank 2", cost = 8000 },
    { name = "Searing Pain", level = 34, spell = 17920, rank = "Rank 3", cost = 8000 },
    { name = "Create Firestone", level = 36, spell = 17951, rank = "Rank 2", cost = 9000 },
    { name = "Create Spellstone", level = 36, spell = 2362, rank = "Rank 1", cost = 9000 },
    { name = "Health Funnel", level = 36, spell = 3700, rank = "Rank 4", cost = 9000 },
    { name = "Life Tap", level = 36, spell = 11687, rank = "Rank 4", cost = 9000 },
    { name = "Shadow Bolt", level = 36, spell = 7641, rank = "Rank 6", cost = 9000 },
    { name = "Bane of Agony", level = 38, spell = 11711, rank = "Rank 4", cost = 10000 },
    { name = "Detect Invisibility", level = 38, spell = 2970, rank = "Rank 2", cost = 10000 },
    { name = "Drain Life", level = 38, spell = 7651, rank = "Rank 4", cost = 10000 },
    { name = "Drain Soul", level = 38, spell = 8289, rank = "Rank 3", cost = 10000 },
    { name = "Siphon Life", level = 38, spell = 18879, rank = "Rank 2", cost = 1000 },
    { name = "Conflagrate", level = 40, spell = 17962, rank = "Rank 3", cost = 500 },
    { name = "Create Soulstone", level = 40, spell = 20755, rank = "Rank 3", cost = 11000 },
    { name = "Curse of the Elements", level = 40, spell = 1311677, rank = "Rank 3", cost = 11000 },
    { name = "Demon Armor", level = 40, spell = 11733, rank = "Rank 3", cost = 11000 },
    { name = "Howl of Terror", level = 40, spell = 5484, rank = "Rank 1", cost = 11000 },
    { name = "Immolate", level = 40, spell = 11665, rank = "Rank 5", cost = 11000 },
    { name = "Shadowburn", level = 40, spell = 18869, rank = "Rank 4", cost = 550 },
    { name = "Curse of Recklessness", level = 42, spell = 7659, rank = "Rank 3", cost = 11000 },
    { name = "Curse of Weakness", level = 42, spell = 11707, rank = "Rank 5", cost = 11000 },
    { name = "Death Coil", level = 42, spell = 6789, rank = "Rank 1", cost = 11000 },
    { name = "Hellfire", level = 42, spell = 11683, rank = "Rank 2", cost = 11000 },
    { name = "Searing Pain", level = 42, spell = 17921, rank = "Rank 4", cost = 11000 },
    { name = "Shadow Ward", level = 42, spell = 11739, rank = "Rank 2", cost = 11000 },
    { name = "Corruption", level = 44, spell = 11671, rank = "Rank 5", cost = 12000 },
    { name = "Drain Mana", level = 44, spell = 11703, rank = "Rank 3", cost = 12000 },
    { name = "Health Funnel", level = 44, spell = 11693, rank = "Rank 5", cost = 12000 },
    { name = "Shadow Bolt", level = 44, spell = 11659, rank = "Rank 7", cost = 12000 },
    { name = "Subjugate Demon", level = 44, spell = 11725, rank = "Rank 2", cost = 12000 },
    { name = "Create Firestone", level = 46, spell = 17952, rank = "Rank 3", cost = 13000 },
    { name = "Create Healthstone", level = 46, spell = 11729, rank = "Rank 4", cost = 13000 },
    { name = "Drain Life", level = 46, spell = 11699, rank = "Rank 5", cost = 13000 },
    { name = "Life Tap", level = 46, spell = 11688, rank = "Rank 5", cost = 13000 },
    { name = "Rain of Fire", level = 46, spell = 11677, rank = "Rank 3", cost = 13000 },
    { name = "Bane of Agony", level = 48, spell = 11712, rank = "Rank 5", cost = 14000 },
    { name = "Banish", level = 48, spell = 18647, rank = "Rank 2", cost = 14000 },
    { name = "Conflagrate", level = 48, spell = 18930, rank = "Rank 4", cost = 700 },
    { name = "Create Spellstone", level = 48, spell = 17727, rank = "Rank 2", cost = 14000 },
    { name = "Shadowburn", level = 48, spell = 18870, rank = "Rank 5", cost = 700 },
    { name = "Siphon Life", level = 48, spell = 18880, rank = "Rank 3", cost = 1400 },
    { name = "Soul Fire", level = 48, spell = 6353, rank = "Rank 1", cost = 14000 },
    { name = "Create Soulstone", level = 50, spell = 20756, rank = "Rank 4", cost = 15000 },
    { name = "Curse of the Elements", level = 50, spell = 1311680, rank = "Rank 4", cost = 15000 },
    { name = "Curse of Tongues", level = 50, spell = 11719, rank = "Rank 2", cost = 15000 },
    { name = "Death Coil", level = 50, spell = 17925, rank = "Rank 2", cost = 15000 },
    { name = "Demon Armor", level = 50, spell = 11734, rank = "Rank 4", cost = 15000 },
    { name = "Detect Invisibility", level = 50, spell = 11743, rank = "Rank 3", cost = 15000 },
    { name = "Immolate", level = 50, spell = 11667, rank = "Rank 6", cost = 15000 },
    { name = "Incinerate", level = 50, spell = 1293812, rank = "Rank 2", cost = 900 },
    { name = "Searing Pain", level = 50, spell = 17922, rank = "Rank 5", cost = 15000 },
    { name = "Curse of Weakness", level = 52, spell = 11708, rank = "Rank 6", cost = 18000 },
    { name = "Drain Soul", level = 52, spell = 11675, rank = "Rank 4", cost = 18000 },
    { name = "Health Funnel", level = 52, spell = 11694, rank = "Rank 6", cost = 18000 },
    { name = "Shadow Bolt", level = 52, spell = 11660, rank = "Rank 8", cost = 18000 },
    { name = "Shadow Ward", level = 52, spell = 11740, rank = "Rank 3", cost = 18000 },
    { name = "Conflagrate", level = 54, spell = 18931, rank = "Rank 5", cost = 1000 },
    { name = "Corruption", level = 54, spell = 11672, rank = "Rank 6", cost = 20000 },
    { name = "Drain Life", level = 54, spell = 11700, rank = "Rank 6", cost = 20000 },
    { name = "Drain Mana", level = 54, spell = 11704, rank = "Rank 4", cost = 20000 },
    { name = "Hellfire", level = 54, spell = 11684, rank = "Rank 3", cost = 20000 },
    { name = "Howl of Terror", level = 54, spell = 17928, rank = "Rank 2", cost = 20000 },
    { name = "Create Firestone", level = 56, spell = 17953, rank = "Rank 4", cost = 22000 },
    { name = "Curse of Recklessness", level = 56, spell = 11717, rank = "Rank 4", cost = 22000 },
    { name = "Fear", level = 56, spell = 6215, rank = "Rank 3", cost = 22000 },
    { name = "Life Tap", level = 56, spell = 11689, rank = "Rank 6", cost = 22000 },
    { name = "Shadowburn", level = 56, spell = 18871, rank = "Rank 6", cost = 1100 },
    { name = "Soul Fire", level = 56, spell = 17924, rank = "Rank 2", cost = 22000 },
    { name = "Bane of Agony", level = 58, spell = 11713, rank = "Rank 6", cost = 24000 },
    { name = "Create Healthstone", level = 58, spell = 11730, rank = "Rank 5", cost = 24000 },
    { name = "Death Coil", level = 58, spell = 17926, rank = "Rank 3", cost = 24000 },
    { name = "Rain of Fire", level = 58, spell = 11678, rank = "Rank 4", cost = 24000 },
    { name = "Searing Pain", level = 58, spell = 17923, rank = "Rank 6", cost = 24000 },
    { name = "Siphon Life", level = 58, spell = 18881, rank = "Rank 4", cost = 2400 },
    { name = "Subjugate Demon", level = 58, spell = 11726, rank = "Rank 3", cost = 24000 },
    { name = "Bane of Doom", level = 60, spell = 603, rank = "", cost = 26000 },
    { name = "Conflagrate", level = 60, spell = 18932, rank = "Rank 6", cost = 1300 },
    { name = "Create Soulstone", level = 60, spell = 20757, rank = "Rank 5", cost = 26000 },
    { name = "Create Spellstone", level = 60, spell = 17728, rank = "Rank 3", cost = 26000 },
    { name = "Demon Armor", level = 60, spell = 11735, rank = "Rank 5", cost = 26000 },
    { name = "Health Funnel", level = 60, spell = 11695, rank = "Rank 7", cost = 26000 },
    { name = "Immolate", level = 60, spell = 11668, rank = "Rank 7", cost = 26000 },
    { name = "Incinerate", level = 60, spell = 1293813, rank = "Rank 3", cost = 1100 },
    { name = "Shadow Bolt", level = 60, spell = 11661, rank = "Rank 9", cost = 26000 },
}

ns.classTraining.SHAMAN = {
    { name = "Rockbiter Weapon", level = 1, spell = 8017, rank = "Rank 1", cost = 10 },
    { name = "Earth Shock", level = 4, spell = 8042, rank = "Rank 1", cost = 100 },
    { name = "Earthbind Totem", level = 6, spell = 2484, rank = "", cost = 100 },
    { name = "Healing Wave", level = 6, spell = 332, rank = "Rank 2", cost = 100 },
    { name = "Earth Shock", level = 8, spell = 8044, rank = "Rank 2", cost = 100 },
    { name = "Lightning Bolt", level = 8, spell = 529, rank = "Rank 2", cost = 100 },
    { name = "Lightning Shield", level = 8, spell = 324, rank = "Rank 1", cost = 100 },
    { name = "Rockbiter Weapon", level = 8, spell = 8018, rank = "Rank 2", cost = 100 },
    { name = "Stoneclaw Totem", level = 8, spell = 5730, rank = "Rank 1", cost = 100 },
    { name = "Flame Shock", level = 10, spell = 8050, rank = "Rank 1", cost = 400 },
    { name = "Flametongue Weapon", level = 10, spell = 8024, rank = "Rank 1", cost = 400 },
    { name = "Strength of Earth Totem", level = 10, spell = 8075, rank = "Rank 1", cost = 400 },
    { name = "Ancestral Spirit", level = 12, spell = 2008, rank = "Rank 1", cost = 800 },
    { name = "Fire Nova", level = 12, spell = 408341, rank = "Rank 1", cost = 800 },
    { name = "Healing Wave", level = 12, spell = 547, rank = "Rank 3", cost = 800 },
    { name = "Purge", level = 12, spell = 370, rank = "Rank 1", cost = 800 },
    { name = "Earth Shock", level = 14, spell = 8045, rank = "Rank 3", cost = 900 },
    { name = "Lightning Bolt", level = 14, spell = 548, rank = "Rank 3", cost = 900 },
    { name = "Stoneskin Totem", level = 14, spell = 8154, rank = "Rank 2", cost = 900 },
    { name = "Cure Poison", level = 16, spell = 526, rank = "", cost = 1800 },
    { name = "Lightning Shield", level = 16, spell = 325, rank = "Rank 2", cost = 1800 },
    { name = "Rockbiter Weapon", level = 16, spell = 8019, rank = "Rank 3", cost = 1800 },
    { name = "Flame Shock", level = 18, spell = 8052, rank = "Rank 2", cost = 2000 },
    { name = "Flametongue Weapon", level = 18, spell = 8027, rank = "Rank 2", cost = 2000 },
    { name = "Healing Wave", level = 18, spell = 913, rank = "Rank 4", cost = 2000 },
    { name = "Stoneclaw Totem", level = 18, spell = 6390, rank = "Rank 2", cost = 2000 },
    { name = "Tremor Totem", level = 18, spell = 8143, rank = "", cost = 2000 },
    { name = "Call of the Elements", level = 20, spell = 66842, rank = "", cost = 7000 },
    { name = "Frost Shock", level = 20, spell = 8056, rank = "Rank 1", cost = 2200 },
    { name = "Frostbrand Weapon", level = 20, spell = 8033, rank = "Rank 1", cost = 2200 },
    { name = "Ghost Wolf", level = 20, spell = 2645, rank = "", cost = 2200 },
    { name = "Lesser Healing Wave", level = 20, spell = 8004, rank = "Rank 1", cost = 2200 },
    { name = "Lightning Bolt", level = 20, spell = 915, rank = "Rank 4", cost = 2200 },
    { name = "Searing Totem", level = 20, spell = 6363, rank = "Rank 2", cost = 2200 },
    { name = "Totemic Recall", level = 20, spell = 36936, rank = "", cost = 7000 },
    { name = "Cure Disease", level = 22, spell = 2870, rank = "", cost = 3000 },
    { name = "Fire Nova", level = 22, spell = 408342, rank = "Rank 2", cost = 3000 },
    { name = "Poison Cleansing Totem", level = 22, spell = 8166, rank = "", cost = 3000 },
    { name = "Totemic Projection", level = 22, spell = 437009, rank = "", cost = 3000 },
    { name = "Water Breathing", level = 22, spell = 131, rank = "", cost = 3000 },
    { name = "Ancestral Spirit", level = 24, spell = 20609, rank = "Rank 2", cost = 3500 },
    { name = "Earth Shock", level = 24, spell = 8046, rank = "Rank 4", cost = 3500 },
    { name = "Frost Resistance Totem", level = 24, spell = 8181, rank = "Rank 1", cost = 3500 },
    { name = "Healing Wave", level = 24, spell = 939, rank = "Rank 5", cost = 3500 },
    { name = "Lightning Shield", level = 24, spell = 905, rank = "Rank 3", cost = 3500 },
    { name = "Rockbiter Weapon", level = 24, spell = 10399, rank = "Rank 4", cost = 3500 },
    { name = "Stoneskin Totem", level = 24, spell = 8155, rank = "Rank 3", cost = 3500 },
    { name = "Strength of Earth Totem", level = 24, spell = 8160, rank = "Rank 2", cost = 3500 },
    { name = "Far Sight", level = 26, spell = 6196, rank = "", cost = 4000 },
    { name = "Flametongue Weapon", level = 26, spell = 8030, rank = "Rank 3", cost = 4000 },
    { name = "Lightning Bolt", level = 26, spell = 943, rank = "Rank 5", cost = 4000 },
    { name = "Magma Totem", level = 26, spell = 8190, rank = "Rank 1", cost = 4000 },
    { name = "Mana Spring Totem", level = 26, spell = 5675, rank = "Rank 1", cost = 4000 },
    { name = "Fire Resistance Totem", level = 28, spell = 8184, rank = "Rank 1", cost = 6000 },
    { name = "Flame Shock", level = 28, spell = 8053, rank = "Rank 3", cost = 6000 },
    { name = "Flametongue Totem", level = 28, spell = 8227, rank = "Rank 1", cost = 6000 },
    { name = "Frostbrand Weapon", level = 28, spell = 8038, rank = "Rank 2", cost = 6000 },
    { name = "Lesser Healing Wave", level = 28, spell = 8008, rank = "Rank 2", cost = 6000 },
    { name = "Stoneclaw Totem", level = 28, spell = 6391, rank = "Rank 3", cost = 6000 },
    { name = "Water Walking", level = 28, spell = 546, rank = "", cost = 6000 },
    { name = "Astral Recall", level = 30, spell = 556, rank = "", cost = 7000 },
    { name = "Call of the Ancestors", level = 30, spell = 66843, rank = "", cost = 7000 },
    { name = "Grounding Totem", level = 30, spell = 8177, rank = "", cost = 7000 },
    { name = "Healing Stream Totem", level = 30, spell = 6375, rank = "Rank 2", cost = 7000 },
    { name = "Nature Resistance Totem", level = 30, spell = 10595, rank = "Rank 1", cost = 7000 },
    { name = "Reincarnation", level = 30, spell = 20608, rank = "Passive", cost = 7000 },
    { name = "Searing Totem", level = 30, spell = 6364, rank = "Rank 3", cost = 7000 },
    { name = "Windfury Weapon", level = 30, spell = 8232, rank = "Rank 1", cost = 7000 },
    { name = "Chain Lightning", level = 32, spell = 421, rank = "Rank 1", cost = 8000 },
    { name = "Fire Nova", level = 32, spell = 408343, rank = "Rank 3", cost = 8000 },
    { name = "Healing Wave", level = 32, spell = 959, rank = "Rank 6", cost = 8000 },
    { name = "Lightning Bolt", level = 32, spell = 6041, rank = "Rank 6", cost = 8000 },
    { name = "Lightning Shield", level = 32, spell = 945, rank = "Rank 4", cost = 8000 },
    { name = "Purge", level = 32, spell = 8012, rank = "Rank 2", cost = 8000 },
    { name = "Windfury Totem", level = 32, spell = 8512, rank = "Rank 1", cost = 8000 },
    { name = "Frost Shock", level = 34, spell = 8058, rank = "Rank 2", cost = 9000 },
    { name = "Rockbiter Weapon", level = 34, spell = 16314, rank = "Rank 5", cost = 9000 },
    { name = "Sentry Totem", level = 34, spell = 6495, rank = "", cost = 9000 },
    { name = "Stoneskin Totem", level = 34, spell = 10406, rank = "Rank 4", cost = 9000 },
    { name = "Ancestral Spirit", level = 36, spell = 20610, rank = "Rank 3", cost = 10000 },
    { name = "Earth Shock", level = 36, spell = 10412, rank = "Rank 5", cost = 10000 },
    { name = "Flametongue Weapon", level = 36, spell = 16339, rank = "Rank 4", cost = 10000 },
    { name = "Lesser Healing Wave", level = 36, spell = 8010, rank = "Rank 3", cost = 10000 },
    { name = "Magma Totem", level = 36, spell = 10585, rank = "Rank 2", cost = 10000 },
    { name = "Mana Spring Totem", level = 36, spell = 10495, rank = "Rank 2", cost = 10000 },
    { name = "Windwall Totem", level = 36, spell = 15107, rank = "Rank 1", cost = 10000 },
    { name = "Disease Cleansing Totem", level = 38, spell = 8170, rank = "", cost = 11000 },
    { name = "Flametongue Totem", level = 38, spell = 8249, rank = "Rank 2", cost = 11000 },
    { name = "Frost Resistance Totem", level = 38, spell = 10478, rank = "Rank 2", cost = 11000 },
    { name = "Frostbrand Weapon", level = 38, spell = 10456, rank = "Rank 3", cost = 11000 },
    { name = "Lightning Bolt", level = 38, spell = 10391, rank = "Rank 7", cost = 11000 },
    { name = "Stoneclaw Totem", level = 38, spell = 6392, rank = "Rank 4", cost = 11000 },
    { name = "Strength of Earth Totem", level = 38, spell = 8161, rank = "Rank 3", cost = 11000 },
    { name = "Call of the Spirits", level = 40, spell = 66844, rank = "", cost = 7000 },
    { name = "Chain Heal", level = 40, spell = 1064, rank = "Rank 1", cost = 12000 },
    { name = "Chain Lightning", level = 40, spell = 930, rank = "Rank 2", cost = 12000 },
    { name = "Flame Shock", level = 40, spell = 10447, rank = "Rank 4", cost = 12000 },
    { name = "Healing Stream Totem", level = 40, spell = 6377, rank = "Rank 3", cost = 12000 },
    { name = "Healing Wave", level = 40, spell = 8005, rank = "Rank 7", cost = 12000 },
    { name = "Lightning Shield", level = 40, spell = 8134, rank = "Rank 5", cost = 12000 },
    { name = "Mail", level = 40, spell = 8737, rank = "", cost = 12000 },
    { name = "Searing Totem", level = 40, spell = 6365, rank = "Rank 4", cost = 12000 },
    { name = "Windfury Weapon", level = 40, spell = 8235, rank = "Rank 2", cost = 12000 },
    { name = "Fire Nova", level = 42, spell = 408344, rank = "Rank 4", cost = 16000 },
    { name = "Fire Resistance Totem", level = 42, spell = 10537, rank = "Rank 2", cost = 16000 },
    { name = "Grace of Air Totem", level = 42, spell = 8835, rank = "Rank 1", cost = 16000 },
    { name = "Windfury Totem", level = 42, spell = 10613, rank = "Rank 2", cost = 16000 },
    { name = "Lesser Healing Wave", level = 44, spell = 10466, rank = "Rank 4", cost = 18000 },
    { name = "Lightning Bolt", level = 44, spell = 10392, rank = "Rank 8", cost = 18000 },
    { name = "Nature Resistance Totem", level = 44, spell = 10600, rank = "Rank 2", cost = 18000 },
    { name = "Rockbiter Weapon", level = 44, spell = 16315, rank = "Rank 6", cost = 18000 },
    { name = "Stoneskin Totem", level = 44, spell = 10407, rank = "Rank 5", cost = 18000 },
    { name = "Chain Heal", level = 46, spell = 10622, rank = "Rank 2", cost = 20000 },
    { name = "Flametongue Weapon", level = 46, spell = 16341, rank = "Rank 5", cost = 20000 },
    { name = "Frost Shock", level = 46, spell = 10472, rank = "Rank 3", cost = 20000 },
    { name = "Magma Totem", level = 46, spell = 10586, rank = "Rank 3", cost = 20000 },
    { name = "Mana Spring Totem", level = 46, spell = 10496, rank = "Rank 3", cost = 20000 },
    { name = "Windwall Totem", level = 46, spell = 15111, rank = "Rank 2", cost = 20000 },
    { name = "Ancestral Spirit", level = 48, spell = 20776, rank = "Rank 4", cost = 22000 },
    { name = "Chain Lightning", level = 48, spell = 2860, rank = "Rank 3", cost = 22000 },
    { name = "Earth Shock", level = 48, spell = 10413, rank = "Rank 6", cost = 22000 },
    { name = "Flametongue Totem", level = 48, spell = 10526, rank = "Rank 3", cost = 22000 },
    { name = "Frostbrand Weapon", level = 48, spell = 16355, rank = "Rank 4", cost = 22000 },
    { name = "Healing Wave", level = 48, spell = 10395, rank = "Rank 8", cost = 22000 },
    { name = "Lightning Shield", level = 48, spell = 10431, rank = "Rank 6", cost = 22000 },
    { name = "Mana Tide Totem", level = 48, spell = 17354, rank = "Rank 2", cost = 800 },
    { name = "Stoneclaw Totem", level = 48, spell = 10427, rank = "Rank 5", cost = 22000 },
    { name = "Healing Stream Totem", level = 50, spell = 10462, rank = "Rank 4", cost = 24000 },
    { name = "Lava Burst", level = 50, spell = 1238299, rank = "Rank 2", cost = 24000 },
    { name = "Lightning Bolt", level = 50, spell = 15207, rank = "Rank 9", cost = 24000 },
    { name = "Riptide", level = 50, spell = 1239242, rank = "Rank 2", cost = 800 },
    { name = "Searing Totem", level = 50, spell = 10437, rank = "Rank 5", cost = 24000 },
    { name = "Windfury Weapon", level = 50, spell = 10486, rank = "Rank 3", cost = 24000 },
    { name = "Fire Nova", level = 52, spell = 408345, rank = "Rank 5", cost = 27000 },
    { name = "Flame Shock", level = 52, spell = 10448, rank = "Rank 5", cost = 27000 },
    { name = "Lesser Healing Wave", level = 52, spell = 10467, rank = "Rank 5", cost = 27000 },
    { name = "Strength of Earth Totem", level = 52, spell = 10442, rank = "Rank 4", cost = 27000 },
    { name = "Windfury Totem", level = 52, spell = 10614, rank = "Rank 3", cost = 27000 },
    { name = "Chain Heal", level = 54, spell = 10623, rank = "Rank 3", cost = 29000 },
    { name = "Frost Resistance Totem", level = 54, spell = 10479, rank = "Rank 3", cost = 29000 },
    { name = "Rockbiter Weapon", level = 54, spell = 16316, rank = "Rank 7", cost = 29000 },
    { name = "Stoneskin Totem", level = 54, spell = 10408, rank = "Rank 6", cost = 29000 },
    { name = "Chain Lightning", level = 56, spell = 10605, rank = "Rank 4", cost = 30000 },
    { name = "Flametongue Weapon", level = 56, spell = 16342, rank = "Rank 6", cost = 30000 },
    { name = "Grace of Air Totem", level = 56, spell = 10627, rank = "Rank 2", cost = 30000 },
    { name = "Healing Wave", level = 56, spell = 10396, rank = "Rank 9", cost = 30000 },
    { name = "Lightning Bolt", level = 56, spell = 15208, rank = "Rank 10", cost = 30000 },
    { name = "Lightning Shield", level = 56, spell = 10432, rank = "Rank 7", cost = 30000 },
    { name = "Magma Totem", level = 56, spell = 10587, rank = "Rank 4", cost = 30000 },
    { name = "Mana Spring Totem", level = 56, spell = 10497, rank = "Rank 4", cost = 30000 },
    { name = "Windwall Totem", level = 56, spell = 15112, rank = "Rank 3", cost = 30000 },
    { name = "Fire Resistance Totem", level = 58, spell = 10538, rank = "Rank 3", cost = 32000 },
    { name = "Flametongue Totem", level = 58, spell = 16387, rank = "Rank 4", cost = 32000 },
    { name = "Frost Shock", level = 58, spell = 10473, rank = "Rank 4", cost = 32000 },
    { name = "Frostbrand Weapon", level = 58, spell = 16356, rank = "Rank 5", cost = 32000 },
    { name = "Mana Tide Totem", level = 58, spell = 17359, rank = "Rank 3", cost = 1600 },
    { name = "Stoneclaw Totem", level = 58, spell = 10428, rank = "Rank 6", cost = 32000 },
    { name = "Ancestral Spirit", level = 60, spell = 20777, rank = "Rank 5", cost = 34000 },
    { name = "Earth Shock", level = 60, spell = 10414, rank = "Rank 7", cost = 34000 },
    { name = "Healing Stream Totem", level = 60, spell = 10463, rank = "Rank 5", cost = 34000 },
    { name = "Lava Burst", level = 60, spell = 1238300, rank = "Rank 3", cost = 34000 },
    { name = "Lesser Healing Wave", level = 60, spell = 10468, rank = "Rank 6", cost = 34000 },
    { name = "Nature Resistance Totem", level = 60, spell = 10601, rank = "Rank 3", cost = 34000 },
    { name = "Riptide", level = 60, spell = 1239243, rank = "Rank 3", cost = 1600 },
    { name = "Searing Totem", level = 60, spell = 10438, rank = "Rank 6", cost = 34000 },
    { name = "Windfury Weapon", level = 60, spell = 16362, rank = "Rank 4", cost = 34000 },
}

ns.classTraining.WARRIOR = {
    { name = "Battle Shout", level = 1, spell = 6673, rank = "Rank 1", cost = 10 },
    { name = "Charge", level = 4, spell = 100, rank = "Rank 1", cost = 100 },
    { name = "Rend", level = 4, spell = 772, rank = "Rank 1", cost = 100 },
    { name = "Parry", level = 6, spell = 3127, rank = "Passive", cost = 100 },
    { name = "Thunder Clap", level = 6, spell = 6343, rank = "Rank 1", cost = 100 },
    { name = "Hamstring", level = 8, spell = 1715, rank = "Rank 1", cost = 200 },
    { name = "Heroic Strike", level = 8, spell = 284, rank = "Rank 2", cost = 200 },
    { name = "Bloodrage", level = 10, spell = 2687, rank = "", cost = 600 },
    { name = "Rend", level = 10, spell = 6546, rank = "Rank 2", cost = 600 },
    { name = "Battle Shout", level = 12, spell = 5242, rank = "Rank 2", cost = 1000 },
    { name = "Overpower", level = 12, spell = 7384, rank = "Rank 1", cost = 1000 },
    { name = "Shield Bash", level = 12, spell = 72, rank = "Rank 1", cost = 1000 },
    { name = "Demoralizing Shout", level = 14, spell = 1160, rank = "Rank 1", cost = 1500 },
    { name = "Revenge", level = 14, spell = 6572, rank = "Rank 1", cost = 1500 },
    { name = "Tactical Mastery", level = 14, spell = 1310185, rank = "", cost = 1500 },
    { name = "Heroic Strike", level = 16, spell = 285, rank = "Rank 3", cost = 2000 },
    { name = "Mocking Blow", level = 16, spell = 694, rank = "Rank 1", cost = 2000 },
    { name = "Shield Block", level = 16, spell = 2565, rank = "", cost = 2000 },
    { name = "Disarm", level = 18, spell = 676, rank = "", cost = 3000 },
    { name = "Thunder Clap", level = 18, spell = 8198, rank = "Rank 2", cost = 3000 },
    { name = "Cleave", level = 20, spell = 845, rank = "Rank 1", cost = 4000 },
    { name = "Dual Wield", level = 20, spell = 674, rank = "Passive", cost = 4000 },
    { name = "Rend", level = 20, spell = 6547, rank = "Rank 3", cost = 4000 },
    { name = "Retaliation", level = 20, spell = 20230, rank = "", cost = 4000 },
    { name = "Slam", level = 20, spell = 1240193, rank = "Rank 1", cost = 4000 },
    { name = "Victory Rush", level = 20, spell = 402927, rank = "", cost = 4000 },
    { name = "Battle Shout", level = 22, spell = 6192, rank = "Rank 3", cost = 6000 },
    { name = "Intimidating Shout", level = 22, spell = 5246, rank = "", cost = 6000 },
    { name = "Sunder Armor", level = 22, spell = 7405, rank = "Rank 2", cost = 6000 },
    { name = "Demoralizing Shout", level = 24, spell = 6190, rank = "Rank 2", cost = 8000 },
    { name = "Execute", level = 24, spell = 5308, rank = "Rank 1", cost = 8000 },
    { name = "Heroic Strike", level = 24, spell = 1608, rank = "Rank 4", cost = 8000 },
    { name = "Revenge", level = 24, spell = 6574, rank = "Rank 2", cost = 8000 },
    { name = "Challenging Shout", level = 26, spell = 1161, rank = "", cost = 10000 },
    { name = "Charge", level = 26, spell = 6178, rank = "Rank 2", cost = 10000 },
    { name = "Mocking Blow", level = 26, spell = 7400, rank = "Rank 2", cost = 10000 },
    { name = "Overpower", level = 28, spell = 7887, rank = "Rank 2", cost = 11000 },
    { name = "Shield Wall", level = 28, spell = 871, rank = "", cost = 11000 },
    { name = "Thunder Clap", level = 28, spell = 8204, rank = "Rank 3", cost = 11000 },
    { name = "Cleave", level = 30, spell = 7369, rank = "Rank 2", cost = 12000 },
    { name = "Rend", level = 30, spell = 6548, rank = "Rank 4", cost = 12000 },
    { name = "Slam", level = 30, spell = 1464, rank = "Rank 2", cost = 12000 },
    { name = "Battle Shout", level = 32, spell = 11549, rank = "Rank 4", cost = 14000 },
    { name = "Berserker Rage", level = 32, spell = 18499, rank = "", cost = 14000 },
    { name = "Execute", level = 32, spell = 20658, rank = "Rank 2", cost = 14000 },
    { name = "Hamstring", level = 32, spell = 7372, rank = "Rank 2", cost = 14000 },
    { name = "Heroic Strike", level = 32, spell = 11564, rank = "Rank 5", cost = 14000 },
    { name = "Shield Bash", level = 32, spell = 1671, rank = "Rank 2", cost = 14000 },
    { name = "Demoralizing Shout", level = 34, spell = 11554, rank = "Rank 3", cost = 16000 },
    { name = "Revenge", level = 34, spell = 7379, rank = "Rank 3", cost = 16000 },
    { name = "Sunder Armor", level = 34, spell = 8380, rank = "Rank 3", cost = 16000 },
    { name = "Mocking Blow", level = 36, spell = 7402, rank = "Rank 3", cost = 18000 },
    { name = "Whirlwind", level = 36, spell = 1680, rank = "", cost = 18000 },
    { name = "Pummel", level = 38, spell = 6552, rank = "Rank 1", cost = 20000 },
    { name = "Slam", level = 38, spell = 8820, rank = "Rank 3", cost = 20000 },
    { name = "Thunder Clap", level = 38, spell = 8205, rank = "Rank 4", cost = 20000 },
    { name = "Cleave", level = 40, spell = 11608, rank = "Rank 3", cost = 22000 },
    { name = "Execute", level = 40, spell = 20660, rank = "Rank 3", cost = 22000 },
    { name = "Heroic Strike", level = 40, spell = 11565, rank = "Rank 6", cost = 22000 },
    { name = "Plate Mail", level = 40, spell = 750, rank = "", cost = 22000 },
    { name = "Rend", level = 40, spell = 11572, rank = "Rank 5", cost = 22000 },
    { name = "Battle Shout", level = 42, spell = 11550, rank = "Rank 5", cost = 32000 },
    { name = "Intercept", level = 42, spell = 20616, rank = "Rank 2", cost = 32000 },
    { name = "Demoralizing Shout", level = 44, spell = 11555, rank = "Rank 4", cost = 34000 },
    { name = "Overpower", level = 44, spell = 11584, rank = "Rank 3", cost = 34000 },
    { name = "Revenge", level = 44, spell = 11600, rank = "Rank 4", cost = 34000 },
    { name = "Charge", level = 46, spell = 11578, rank = "Rank 3", cost = 36000 },
    { name = "Mocking Blow", level = 46, spell = 20559, rank = "Rank 4", cost = 36000 },
    { name = "Slam", level = 46, spell = 11604, rank = "Rank 4", cost = 36000 },
    { name = "Sunder Armor", level = 46, spell = 11596, rank = "Rank 4", cost = 36000 },
    { name = "Bloodthirst", level = 48, spell = 23892, rank = "Rank 2", cost = 2000 },
    { name = "Execute", level = 48, spell = 20661, rank = "Rank 4", cost = 40000 },
    { name = "Heroic Strike", level = 48, spell = 11566, rank = "Rank 7", cost = 40000 },
    { name = "Mortal Strike", level = 48, spell = 21551, rank = "Rank 2", cost = 2000 },
    { name = "Shield Slam", level = 48, spell = 23923, rank = "Rank 2", cost = 2000 },
    { name = "Thunder Clap", level = 48, spell = 11580, rank = "Rank 5", cost = 40000 },
    { name = "Cleave", level = 50, spell = 11609, rank = "Rank 4", cost = 42000 },
    { name = "Recklessness", level = 50, spell = 1719, rank = "", cost = 42000 },
    { name = "Rend", level = 50, spell = 11573, rank = "Rank 6", cost = 42000 },
    { name = "Battle Shout", level = 52, spell = 11551, rank = "Rank 6", cost = 54000 },
    { name = "Intercept", level = 52, spell = 20617, rank = "Rank 3", cost = 54000 },
    { name = "Shield Bash", level = 52, spell = 1672, rank = "Rank 3", cost = 54000 },
    { name = "Bloodthirst", level = 54, spell = 23893, rank = "Rank 3", cost = 2800 },
    { name = "Demoralizing Shout", level = 54, spell = 11556, rank = "Rank 5", cost = 56000 },
    { name = "Hamstring", level = 54, spell = 7373, rank = "Rank 3", cost = 56000 },
    { name = "Mortal Strike", level = 54, spell = 21552, rank = "Rank 3", cost = 2800 },
    { name = "Revenge", level = 54, spell = 11601, rank = "Rank 5", cost = 56000 },
    { name = "Shield Slam", level = 54, spell = 23924, rank = "Rank 3", cost = 2800 },
    { name = "Slam", level = 54, spell = 11605, rank = "Rank 5", cost = 56000 },
    { name = "Execute", level = 56, spell = 20662, rank = "Rank 5", cost = 58000 },
    { name = "Heroic Strike", level = 56, spell = 11567, rank = "Rank 8", cost = 58000 },
    { name = "Mocking Blow", level = 56, spell = 20560, rank = "Rank 5", cost = 58000 },
    { name = "Pummel", level = 58, spell = 6554, rank = "Rank 2", cost = 60000 },
    { name = "Sunder Armor", level = 58, spell = 11597, rank = "Rank 5", cost = 60000 },
    { name = "Thunder Clap", level = 58, spell = 11581, rank = "Rank 6", cost = 60000 },
    { name = "Bloodthirst", level = 60, spell = 23894, rank = "Rank 4", cost = 3100 },
    { name = "Cleave", level = 60, spell = 20569, rank = "Rank 5", cost = 62000 },
    { name = "Mortal Strike", level = 60, spell = 21553, rank = "Rank 4", cost = 3100 },
    { name = "Overpower", level = 60, spell = 11585, rank = "Rank 4", cost = 62000 },
    { name = "Rend", level = 60, spell = 11574, rank = "Rank 7", cost = 62000 },
    { name = "Shield Slam", level = 60, spell = 23925, rank = "Rank 4", cost = 3100 },
}

ns.classTraining.ROGUE = {
    { name = "Stealth", level = 1, spell = 1784, rank = "Rank 1", cost = 10 },
    { name = "Backstab", level = 4, spell = 53, rank = "Rank 1", cost = 100 },
    { name = "Pick Pocket", level = 4, spell = 921, rank = "", cost = 100 },
    { name = "Gouge", level = 6, spell = 1776, rank = "Rank 1", cost = 100 },
    { name = "Sinister Strike", level = 6, spell = 1757, rank = "Rank 2", cost = 100 },
    { name = "Evasion", level = 8, spell = 5277, rank = "", cost = 200 },
    { name = "Eviscerate", level = 8, spell = 6760, rank = "Rank 2", cost = 200 },
    { name = "Dual Wield", level = 10, spell = 674, rank = "Passive", cost = 300 },
    { name = "Sap", level = 10, spell = 6770, rank = "Rank 1", cost = 300 },
    { name = "Slice and Dice", level = 10, spell = 5171, rank = "Rank 1", cost = 300 },
    { name = "Sprint", level = 10, spell = 2983, rank = "Rank 1", cost = 300 },
    { name = "Backstab", level = 12, spell = 2589, rank = "Rank 2", cost = 800 },
    { name = "Kick", level = 12, spell = 1766, rank = "Rank 1", cost = 800 },
    { name = "Parry", level = 12, spell = 3127, rank = "Passive", cost = 800 },
    { name = "Expose Armor", level = 14, spell = 8647, rank = "Rank 1", cost = 1200 },
    { name = "Garrote", level = 14, spell = 703, rank = "Rank 1", cost = 1200 },
    { name = "Sinister Strike", level = 14, spell = 1758, rank = "Rank 3", cost = 1200 },
    { name = "Eviscerate", level = 16, spell = 6761, rank = "Rank 3", cost = 1800 },
    { name = "Feint", level = 16, spell = 1966, rank = "Rank 1", cost = 1800 },
    { name = "Pick Lock", level = 16, spell = 1804, rank = "", cost = 1800 },
    { name = "Ambush", level = 18, spell = 8676, rank = "Rank 1", cost = 2900 },
    { name = "Gouge", level = 18, spell = 1777, rank = "Rank 2", cost = 2900 },
    { name = "Backstab", level = 20, spell = 2590, rank = "Rank 3", cost = 3000 },
    { name = "Crippling Poison", level = 20, spell = 3420, rank = "Rank 1", cost = 3000 },
    { name = "Rupture", level = 20, spell = 1943, rank = "Rank 1", cost = 3000 },
    { name = "Stealth", level = 20, spell = 1785, rank = "Rank 2", cost = 3000 },
    { name = "Distract", level = 22, spell = 1725, rank = "", cost = 4000 },
    { name = "Garrote", level = 22, spell = 8631, rank = "Rank 2", cost = 4000 },
    { name = "Sinister Strike", level = 22, spell = 1759, rank = "Rank 4", cost = 4000 },
    { name = "Vanish", level = 22, spell = 1856, rank = "Rank 1", cost = 4000 },
    { name = "Detect Traps", level = 24, spell = 2836, rank = "Passive", cost = 5000 },
    { name = "Eviscerate", level = 24, spell = 6762, rank = "Rank 4", cost = 5000 },
    { name = "Mind-numbing Poison", level = 24, spell = 5763, rank = "Rank 1", cost = 5000 },
    { name = "Ambush", level = 26, spell = 8724, rank = "Rank 2", cost = 6000 },
    { name = "Cheap Shot", level = 26, spell = 1833, rank = "", cost = 6000 },
    { name = "Expose Armor", level = 26, spell = 8649, rank = "Rank 2", cost = 6000 },
    { name = "Kick", level = 26, spell = 1767, rank = "Rank 2", cost = 6000 },
    { name = "Backstab", level = 28, spell = 2591, rank = "Rank 4", cost = 8000 },
    { name = "Feint", level = 28, spell = 6768, rank = "Rank 2", cost = 8000 },
    { name = "Instant Poison II", level = 28, spell = 8687, rank = "Rank 2", cost = 8000 },
    { name = "Rupture", level = 28, spell = 8639, rank = "Rank 2", cost = 8000 },
    { name = "Sap", level = 28, spell = 2070, rank = "Rank 2", cost = 8000 },
    { name = "Deadly Poison", level = 30, spell = 2835, rank = "Rank 1", cost = 10000 },
    { name = "Disarm Trap", level = 30, spell = 1842, rank = "", cost = 10000 },
    { name = "Garrote", level = 30, spell = 8632, rank = "Rank 3", cost = 10000 },
    { name = "Kidney Shot", level = 30, spell = 408, rank = "Rank 1", cost = 10000 },
    { name = "Sinister Strike", level = 30, spell = 1760, rank = "Rank 5", cost = 10000 },
    { name = "Eviscerate", level = 32, spell = 8623, rank = "Rank 5", cost = 12000 },
    { name = "Gouge", level = 32, spell = 8629, rank = "Rank 3", cost = 12000 },
    { name = "Wound Poison", level = 32, spell = 13220, rank = "Rank 1", cost = 12000 },
    { name = "Ambush", level = 34, spell = 8725, rank = "Rank 3", cost = 14000 },
    { name = "Blind", level = 34, spell = 2094, rank = "", cost = 14000 },
    { name = "Blinding Powder", level = 34, spell = 6510, rank = "", cost = 14000 },
    { name = "Sprint", level = 34, spell = 8696, rank = "Rank 2", cost = 14000 },
    { name = "Backstab", level = 36, spell = 8721, rank = "Rank 5", cost = 16000 },
    { name = "Expose Armor", level = 36, spell = 8650, rank = "Rank 3", cost = 16000 },
    { name = "Instant Poison III", level = 36, spell = 8691, rank = "Rank 3", cost = 16000 },
    { name = "Rupture", level = 36, spell = 8640, rank = "Rank 3", cost = 16000 },
    { name = "Deadly Poison II", level = 38, spell = 2837, rank = "Rank 2", cost = 18000 },
    { name = "Garrote", level = 38, spell = 8633, rank = "Rank 4", cost = 18000 },
    { name = "Mind-numbing Poison II", level = 38, spell = 8694, rank = "Rank 2", cost = 18000 },
    { name = "Sinister Strike", level = 38, spell = 8621, rank = "Rank 6", cost = 18000 },
    { name = "Eviscerate", level = 40, spell = 8624, rank = "Rank 6", cost = 20000 },
    { name = "Feint", level = 40, spell = 8637, rank = "Rank 3", cost = 20000 },
    { name = "Mutilate", level = 40, spell = 399956, rank = "Rank 2", cost = 10000 },
    { name = "Safe Fall", level = 40, spell = 1860, rank = "Passive", cost = 20000 },
    { name = "Stealth", level = 40, spell = 1786, rank = "Rank 3", cost = 20000 },
    { name = "Wound Poison II", level = 40, spell = 13228, rank = "Rank 2", cost = 20000 },
    { name = "Ambush", level = 42, spell = 11267, rank = "Rank 4", cost = 27000 },
    { name = "Kick", level = 42, spell = 1768, rank = "Rank 3", cost = 27000 },
    { name = "Slice and Dice", level = 42, spell = 6774, rank = "Rank 2", cost = 27000 },
    { name = "Vanish", level = 42, spell = 1857, rank = "Rank 2", cost = 27000 },
    { name = "Backstab", level = 44, spell = 11279, rank = "Rank 6", cost = 29000 },
    { name = "Instant Poison IV", level = 44, spell = 11341, rank = "Rank 4", cost = 29000 },
    { name = "Rupture", level = 44, spell = 11273, rank = "Rank 4", cost = 29000 },
    { name = "Deadly Poison III", level = 46, spell = 11357, rank = "Rank 3", cost = 31000 },
    { name = "Expose Armor", level = 46, spell = 11197, rank = "Rank 4", cost = 31000 },
    { name = "Garrote", level = 46, spell = 11289, rank = "Rank 5", cost = 31000 },
    { name = "Gouge", level = 46, spell = 11285, rank = "Rank 4", cost = 31000 },
    { name = "Sinister Strike", level = 46, spell = 11293, rank = "Rank 7", cost = 31000 },
    { name = "Eviscerate", level = 48, spell = 11299, rank = "Rank 7", cost = 33000 },
    { name = "Sap", level = 48, spell = 11297, rank = "Rank 3", cost = 33000 },
    { name = "Wound Poison III", level = 48, spell = 13229, rank = "Rank 3", cost = 33000 },
    { name = "Ambush", level = 50, spell = 11268, rank = "Rank 5", cost = 35000 },
    { name = "Crippling Poison II", level = 50, spell = 3421, rank = "Rank 2", cost = 35000 },
    { name = "Kidney Shot", level = 50, spell = 8643, rank = "Rank 2", cost = 35000 },
    { name = "Mutilate", level = 50, spell = 1241582, rank = "Rank 3", cost = 35000 },
    { name = "Backstab", level = 52, spell = 11280, rank = "Rank 7", cost = 46000 },
    { name = "Feint", level = 52, spell = 11303, rank = "Rank 4", cost = 46000 },
    { name = "Instant Poison V", level = 52, spell = 11342, rank = "Rank 5", cost = 46000 },
    { name = "Mind-numbing Poison III", level = 52, spell = 11400, rank = "Rank 3", cost = 46000 },
    { name = "Rupture", level = 52, spell = 11274, rank = "Rank 5", cost = 46000 },
    { name = "Deadly Poison IV", level = 54, spell = 11358, rank = "Rank 4", cost = 48000 },
    { name = "Garrote", level = 54, spell = 11290, rank = "Rank 6", cost = 48000 },
    { name = "Sinister Strike", level = 54, spell = 11294, rank = "Rank 8", cost = 48000 },
    { name = "Eviscerate", level = 56, spell = 11300, rank = "Rank 8", cost = 50000 },
    { name = "Expose Armor", level = 56, spell = 11198, rank = "Rank 5", cost = 50000 },
    { name = "Wound Poison IV", level = 56, spell = 13230, rank = "Rank 4", cost = 50000 },
    { name = "Ambush", level = 58, spell = 11269, rank = "Rank 6", cost = 52000 },
    { name = "Kick", level = 58, spell = 1769, rank = "Rank 4", cost = 52000 },
    { name = "Sprint", level = 58, spell = 11305, rank = "Rank 3", cost = 52000 },
    { name = "Backstab", level = 60, spell = 11281, rank = "Rank 8", cost = 54000 },
    { name = "Gouge", level = 60, spell = 11286, rank = "Rank 5", cost = 54000 },
    { name = "Instant Poison VI", level = 60, spell = 11343, rank = "Rank 6", cost = 54000 },
    { name = "Mutilate", level = 60, spell = 1241584, rank = "Rank 4", cost = 54000 },
    { name = "Rupture", level = 60, spell = 11275, rank = "Rank 6", cost = 54000 },
    { name = "Stealth", level = 60, spell = 1787, rank = "Rank 4", cost = 54000 },
}

ns.classTraining.MAGE = {
    { name = "Arcane Intellect", level = 1, spell = 1459, rank = "Rank 1", cost = 10 },
    { name = "Conjure Water", level = 4, spell = 5504, rank = "Rank 1", cost = 100 },
    { name = "Frostbolt", level = 4, spell = 116, rank = "Rank 1", cost = 100 },
    { name = "Comprehend Scroll", level = 6, spell = 1296017, rank = "", cost = 100 },
    { name = "Conjure Food", level = 6, spell = 587, rank = "Rank 1", cost = 100 },
    { name = "Fire Blast", level = 6, spell = 2136, rank = "Rank 1", cost = 100 },
    { name = "Fireball", level = 6, spell = 143, rank = "Rank 2", cost = 100 },
    { name = "Arcane Missiles", level = 8, spell = 5143, rank = "Rank 1", cost = 200 },
    { name = "Frostbolt", level = 8, spell = 205, rank = "Rank 2", cost = 200 },
    { name = "Polymorph", level = 8, spell = 118, rank = "Rank 1", cost = 200 },
    { name = "Conjure Water", level = 10, spell = 5505, rank = "Rank 2", cost = 400 },
    { name = "Frost Armor", level = 10, spell = 7300, rank = "Rank 2", cost = 400 },
    { name = "Frost Nova", level = 10, spell = 122, rank = "Rank 1", cost = 400 },
    { name = "Conjure Food", level = 12, spell = 597, rank = "Rank 2", cost = 600 },
    { name = "Dampen Magic", level = 12, spell = 604, rank = "Rank 1", cost = 600 },
    { name = "Fireball", level = 12, spell = 145, rank = "Rank 3", cost = 600 },
    { name = "Slow Fall", level = 12, spell = 130, rank = "", cost = 600 },
    { name = "Arcane Explosion", level = 14, spell = 1449, rank = "Rank 1", cost = 900 },
    { name = "Arcane Intellect", level = 14, spell = 1460, rank = "Rank 2", cost = 900 },
    { name = "Fire Blast", level = 14, spell = 2137, rank = "Rank 2", cost = 900 },
    { name = "Frostbolt", level = 14, spell = 837, rank = "Rank 3", cost = 900 },
    { name = "Arcane Missiles", level = 16, spell = 5144, rank = "Rank 2", cost = 1500 },
    { name = "Flamestrike", level = 16, spell = 2120, rank = "Rank 1", cost = 1500 },
    { name = "Amplify Magic", level = 18, spell = 1008, rank = "Rank 1", cost = 1800 },
    { name = "Fireball", level = 18, spell = 3140, rank = "Rank 4", cost = 1800 },
    { name = "Remove Lesser Curse", level = 18, spell = 475, rank = "", cost = 1800 },
    { name = "Blink", level = 20, spell = 1953, rank = "", cost = 2000 },
    { name = "Blizzard", level = 20, spell = 10, rank = "Rank 1", cost = 2000 },
    { name = "Conjure Water", level = 20, spell = 5506, rank = "Rank 3", cost = 2000 },
    { name = "Evocation", level = 20, spell = 12051, rank = "", cost = 2000 },
    { name = "Fire Ward", level = 20, spell = 543, rank = "Rank 1", cost = 2000 },
    { name = "Frost Armor", level = 20, spell = 7301, rank = "Rank 3", cost = 2000 },
    { name = "Frostbolt", level = 20, spell = 7322, rank = "Rank 4", cost = 2000 },
    { name = "Mana Shield", level = 20, spell = 1463, rank = "Rank 1", cost = 2000 },
    { name = "Polymorph", level = 20, spell = 12824, rank = "Rank 2", cost = 2000 },
    { name = "Arcane Explosion", level = 22, spell = 8437, rank = "Rank 2", cost = 3000 },
    { name = "Conjure Food", level = 22, spell = 990, rank = "Rank 3", cost = 3000 },
    { name = "Fire Blast", level = 22, spell = 2138, rank = "Rank 3", cost = 3000 },
    { name = "Frost Ward", level = 22, spell = 6143, rank = "Rank 1", cost = 3000 },
    { name = "Scorch", level = 22, spell = 2948, rank = "Rank 1", cost = 3000 },
    { name = "Arcane Missiles", level = 24, spell = 5145, rank = "Rank 3", cost = 4000 },
    { name = "Counterspell", level = 24, spell = 2139, rank = "", cost = 4000 },
    { name = "Dampen Magic", level = 24, spell = 8450, rank = "Rank 2", cost = 4000 },
    { name = "Fireball", level = 24, spell = 8400, rank = "Rank 5", cost = 4000 },
    { name = "Flamestrike", level = 24, spell = 2121, rank = "Rank 2", cost = 4000 },
    { name = "Pyroblast", level = 24, spell = 12505, rank = "Rank 2", cost = 200 },
    { name = "Cone of Cold", level = 26, spell = 120, rank = "Rank 1", cost = 5000 },
    { name = "Frost Nova", level = 26, spell = 865, rank = "Rank 2", cost = 5000 },
    { name = "Frostbolt", level = 26, spell = 8406, rank = "Rank 5", cost = 5000 },
    { name = "Arcane Intellect", level = 28, spell = 1461, rank = "Rank 3", cost = 7000 },
    { name = "Blizzard", level = 28, spell = 6141, rank = "Rank 2", cost = 7000 },
    { name = "Conjure Mana Agate", level = 28, spell = 759, rank = "", cost = 7000 },
    { name = "Ice Lance", level = 28, spell = 400640, rank = "Rank 2", cost = 3000 },
    { name = "Mana Shield", level = 28, spell = 8494, rank = "Rank 2", cost = 7000 },
    { name = "Scorch", level = 28, spell = 8444, rank = "Rank 2", cost = 7000 },
    { name = "Amplify Magic", level = 30, spell = 8455, rank = "Rank 2", cost = 8000 },
    { name = "Arcane Blast", level = 30, spell = 1239696, rank = "Rank 2", cost = 8000 },
    { name = "Arcane Explosion", level = 30, spell = 8438, rank = "Rank 3", cost = 8000 },
    { name = "Conjure Water", level = 30, spell = 6127, rank = "Rank 4", cost = 8000 },
    { name = "Fire Blast", level = 30, spell = 8412, rank = "Rank 4", cost = 8000 },
    { name = "Fire Ward", level = 30, spell = 8457, rank = "Rank 2", cost = 8000 },
    { name = "Fireball", level = 30, spell = 8401, rank = "Rank 6", cost = 8000 },
    { name = "Ice Armor", level = 30, spell = 7302, rank = "Rank 1", cost = 8000 },
    { name = "Pyroblast", level = 30, spell = 12522, rank = "Rank 3", cost = 400 },
    { name = "Arcane Missiles", level = 32, spell = 8416, rank = "Rank 4", cost = 10000 },
    { name = "Conjure Food", level = 32, spell = 6129, rank = "Rank 4", cost = 10000 },
    { name = "Flamestrike", level = 32, spell = 8422, rank = "Rank 3", cost = 10000 },
    { name = "Frost Ward", level = 32, spell = 8461, rank = "Rank 2", cost = 10000 },
    { name = "Frostbolt", level = 32, spell = 8407, rank = "Rank 6", cost = 10000 },
    { name = "Cone of Cold", level = 34, spell = 8492, rank = "Rank 2", cost = 12000 },
    { name = "Ice Lance", level = 34, spell = 1240044, rank = "Rank 3", cost = 14500 },
    { name = "Mage Armor", level = 34, spell = 6117, rank = "Rank 1", cost = 12000 },
    { name = "Scorch", level = 34, spell = 8445, rank = "Rank 3", cost = 12000 },
    { name = "Blast Wave", level = 36, spell = 13018, rank = "Rank 2", cost = 650 },
    { name = "Blizzard", level = 36, spell = 8427, rank = "Rank 3", cost = 13000 },
    { name = "Dampen Magic", level = 36, spell = 8451, rank = "Rank 3", cost = 13000 },
    { name = "Fireball", level = 36, spell = 8402, rank = "Rank 7", cost = 13000 },
    { name = "Mana Shield", level = 36, spell = 8495, rank = "Rank 3", cost = 13000 },
    { name = "Pyroblast", level = 36, spell = 12523, rank = "Rank 4", cost = 650 },
    { name = "Arcane Explosion", level = 38, spell = 8439, rank = "Rank 4", cost = 14000 },
    { name = "Conjure Mana Jade", level = 38, spell = 3552, rank = "", cost = 14000 },
    { name = "Fire Blast", level = 38, spell = 8413, rank = "Rank 5", cost = 14000 },
    { name = "Frostbolt", level = 38, spell = 8408, rank = "Rank 7", cost = 14000 },
    { name = "Arcane Blast", level = 40, spell = 1239697, rank = "Rank 3", cost = 15000 },
    { name = "Arcane Missiles", level = 40, spell = 8417, rank = "Rank 5", cost = 15000 },
    { name = "Conjure Water", level = 40, spell = 10138, rank = "Rank 5", cost = 15000 },
    { name = "Fire Ward", level = 40, spell = 8458, rank = "Rank 3", cost = 15000 },
    { name = "Flamestrike", level = 40, spell = 8423, rank = "Rank 4", cost = 15000 },
    { name = "Frost Nova", level = 40, spell = 6131, rank = "Rank 3", cost = 15000 },
    { name = "Frostfire Bolt", level = 40, spell = 401502, rank = "Rank 1", cost = 15000 },
    { name = "Ice Armor", level = 40, spell = 7320, rank = "Rank 2", cost = 15000 },
    { name = "Polymorph", level = 40, spell = 12825, rank = "Rank 3", cost = 15000 },
    { name = "Scorch", level = 40, spell = 8446, rank = "Rank 4", cost = 15000 },
    { name = "Amplify Magic", level = 42, spell = 10169, rank = "Rank 3", cost = 18000 },
    { name = "Arcane Intellect", level = 42, spell = 10156, rank = "Rank 4", cost = 18000 },
    { name = "Cone of Cold", level = 42, spell = 10159, rank = "Rank 3", cost = 18000 },
    { name = "Conjure Food", level = 42, spell = 10144, rank = "Rank 5", cost = 18000 },
    { name = "Fireball", level = 42, spell = 10148, rank = "Rank 8", cost = 18000 },
    { name = "Frost Ward", level = 42, spell = 8462, rank = "Rank 3", cost = 18000 },
    { name = "Ice Lance", level = 42, spell = 1240045, rank = "Rank 4", cost = 18000 },
    { name = "Pyroblast", level = 42, spell = 12524, rank = "Rank 5", cost = 900 },
    { name = "Blast Wave", level = 44, spell = 13019, rank = "Rank 3", cost = 1150 },
    { name = "Blizzard", level = 44, spell = 10185, rank = "Rank 4", cost = 23000 },
    { name = "Frostbolt", level = 44, spell = 10179, rank = "Rank 8", cost = 23000 },
    { name = "Mana Shield", level = 44, spell = 10191, rank = "Rank 4", cost = 23000 },
    { name = "Arcane Explosion", level = 46, spell = 10201, rank = "Rank 5", cost = 26000 },
    { name = "Fire Blast", level = 46, spell = 10197, rank = "Rank 6", cost = 26000 },
    { name = "Ice Barrier", level = 46, spell = 13031, rank = "Rank 2", cost = 1300 },
    { name = "Mage Armor", level = 46, spell = 22782, rank = "Rank 2", cost = 28000 },
    { name = "Scorch", level = 46, spell = 10205, rank = "Rank 5", cost = 26000 },
    { name = "Arcane Missiles", level = 48, spell = 10211, rank = "Rank 6", cost = 28000 },
    { name = "Conjure Mana Citrine", level = 48, spell = 10053, rank = "", cost = 28000 },
    { name = "Dampen Magic", level = 48, spell = 10173, rank = "Rank 4", cost = 28000 },
    { name = "Fireball", level = 48, spell = 10149, rank = "Rank 9", cost = 28000 },
    { name = "Flamestrike", level = 48, spell = 10215, rank = "Rank 5", cost = 28000 },
    { name = "Ice Lance", level = 48, spell = 1240046, rank = "Rank 5", cost = 32000 },
    { name = "Pyroblast", level = 48, spell = 12525, rank = "Rank 6", cost = 1400 },
    { name = "Arcane Blast", level = 50, spell = 1239699, rank = "Rank 4", cost = 32000 },
    { name = "Cone of Cold", level = 50, spell = 10160, rank = "Rank 4", cost = 32000 },
    { name = "Conjure Water", level = 50, spell = 10139, rank = "Rank 6", cost = 32000 },
    { name = "Fire Ward", level = 50, spell = 10223, rank = "Rank 4", cost = 32000 },
    { name = "Frostbolt", level = 50, spell = 10180, rank = "Rank 9", cost = 32000 },
    { name = "Frostfire Bolt", level = 50, spell = 1237312, rank = "Rank 2", cost = 32000 },
    { name = "Ice Armor", level = 50, spell = 10219, rank = "Rank 3", cost = 32000 },
    { name = "Blast Wave", level = 52, spell = 13020, rank = "Rank 4", cost = 1750 },
    { name = "Blizzard", level = 52, spell = 10186, rank = "Rank 5", cost = 35000 },
    { name = "Conjure Food", level = 52, spell = 10145, rank = "Rank 6", cost = 35000 },
    { name = "Frost Ward", level = 52, spell = 10177, rank = "Rank 4", cost = 35000 },
    { name = "Ice Barrier", level = 52, spell = 13032, rank = "Rank 3", cost = 1750 },
    { name = "Mana Shield", level = 52, spell = 10192, rank = "Rank 5", cost = 35000 },
    { name = "Scorch", level = 52, spell = 10206, rank = "Rank 6", cost = 35000 },
    { name = "Amplify Magic", level = 54, spell = 10170, rank = "Rank 4", cost = 36000 },
    { name = "Arcane Explosion", level = 54, spell = 10202, rank = "Rank 6", cost = 36000 },
    { name = "Fire Blast", level = 54, spell = 10199, rank = "Rank 7", cost = 36000 },
    { name = "Fireball", level = 54, spell = 10150, rank = "Rank 10", cost = 36000 },
    { name = "Frost Nova", level = 54, spell = 10230, rank = "Rank 4", cost = 36000 },
    { name = "Pyroblast", level = 54, spell = 12526, rank = "Rank 7", cost = 1800 },
    { name = "Arcane Intellect", level = 56, spell = 10157, rank = "Rank 5", cost = 38000 },
    { name = "Arcane Missiles", level = 56, spell = 10212, rank = "Rank 7", cost = 38000 },
    { name = "Flamestrike", level = 56, spell = 10216, rank = "Rank 6", cost = 38000 },
    { name = "Frostbolt", level = 56, spell = 10181, rank = "Rank 10", cost = 38000 },
    { name = "Ice Lance", level = 56, spell = 1240047, rank = "Rank 6", cost = 40000 },
    { name = "Cone of Cold", level = 58, spell = 10161, rank = "Rank 5", cost = 40000 },
    { name = "Conjure Mana Ruby", level = 58, spell = 10054, rank = "", cost = 40000 },
    { name = "Ice Barrier", level = 58, spell = 13033, rank = "Rank 4", cost = 2000 },
    { name = "Mage Armor", level = 58, spell = 22783, rank = "Rank 3", cost = 40000 },
    { name = "Scorch", level = 58, spell = 10207, rank = "Rank 7", cost = 40000 },
    { name = "Arcane Blast", level = 60, spell = 1239700, rank = "Rank 5", cost = 42000 },
    { name = "Blast Wave", level = 60, spell = 13021, rank = "Rank 5", cost = 2100 },
    { name = "Blizzard", level = 60, spell = 10187, rank = "Rank 6", cost = 42000 },
    { name = "Dampen Magic", level = 60, spell = 10174, rank = "Rank 5", cost = 42000 },
    { name = "Fire Ward", level = 60, spell = 10225, rank = "Rank 5", cost = 42000 },
    { name = "Fireball", level = 60, spell = 10151, rank = "Rank 11", cost = 42000 },
    { name = "Frostfire Bolt", level = 60, spell = 1237313, rank = "Rank 3", cost = 42000 },
    { name = "Ice Armor", level = 60, spell = 10220, rank = "Rank 4", cost = 42000 },
    { name = "Mana Shield", level = 60, spell = 10193, rank = "Rank 6", cost = 42000 },
    { name = "Polymorph", level = 60, spell = 12826, rank = "Rank 4", cost = 42000 },
    { name = "Pyroblast", level = 60, spell = 18809, rank = "Rank 8", cost = 2100 },
}

ns.classTraining.HUNTER = {
    { name = "Track Beasts", level = 1, spell = 1494, rank = "", cost = 10 },
    { name = "Aspect of the Monkey", level = 4, spell = 13163, rank = "", cost = 100 },
    { name = "Serpent Sting", level = 4, spell = 1978, rank = "Rank 1", cost = 100 },
    { name = "Arcane Shot", level = 6, spell = 3044, rank = "Rank 1", cost = 100 },
    { name = "Hunter's Mark", level = 6, spell = 1130, rank = "Rank 1", cost = 100 },
    { name = "Concussive Shot", level = 8, spell = 5116, rank = "", cost = 200 },
    { name = "Parry", level = 8, spell = 3127, rank = "Passive", cost = 200 },
    { name = "Raptor Strike", level = 8, spell = 14260, rank = "Rank 2", cost = 200 },
    { name = "Aspect of the Hawk", level = 10, spell = 13165, rank = "Rank 1", cost = 400 },
    { name = "Serpent Sting", level = 10, spell = 13549, rank = "Rank 2", cost = 400 },
    { name = "Track Humanoids", level = 10, spell = 19883, rank = "", cost = 400 },
    { name = "Arcane Shot", level = 12, spell = 14281, rank = "Rank 2", cost = 600 },
    { name = "Distracting Shot", level = 12, spell = 20736, rank = "Rank 1", cost = 600 },
    { name = "Mend Pet", level = 12, spell = 136, rank = "Rank 1", cost = 600 },
    { name = "Wing Clip", level = 12, spell = 2974, rank = "Rank 1", cost = 600 },
    { name = "Eagle Eye", level = 14, spell = 6197, rank = "", cost = 1200 },
    { name = "Eyes of the Beast", level = 14, spell = 1002, rank = "", cost = 1200 },
    { name = "Scare Beast", level = 14, spell = 1513, rank = "Rank 1", cost = 1200 },
    { name = "Immolation Trap", level = 16, spell = 13795, rank = "Rank 1", cost = 1500 },
    { name = "Mongoose Bite", level = 16, spell = 1495, rank = "Rank 1", cost = 1500 },
    { name = "Raptor Strike", level = 16, spell = 14261, rank = "Rank 3", cost = 1500 },
    { name = "Aspect of the Hawk", level = 18, spell = 14318, rank = "Rank 2", cost = 1600 },
    { name = "Multi-Shot", level = 18, spell = 2643, rank = "", cost = 1600 },
    { name = "Serpent Sting", level = 18, spell = 13550, rank = "Rank 3", cost = 1600 },
    { name = "Track Undead", level = 18, spell = 19884, rank = "", cost = 1600 },
    { name = "Aimed Shot", level = 20, spell = 19434, rank = "Rank 1", cost = 2100 },
    { name = "Arcane Shot", level = 20, spell = 14282, rank = "Rank 3", cost = 2100 },
    { name = "Aspect of the Cheetah", level = 20, spell = 5118, rank = "", cost = 2100 },
    { name = "Disengage", level = 20, spell = 781, rank = "Rank 1", cost = 2100 },
    { name = "Distracting Shot", level = 20, spell = 14274, rank = "Rank 2", cost = 2100 },
    { name = "Dual Wield", level = 20, spell = 674, rank = "Passive", cost = 2100 },
    { name = "Freezing Trap", level = 20, spell = 1499, rank = "Rank 1", cost = 2100 },
    { name = "Mend Pet", level = 20, spell = 3111, rank = "Rank 2", cost = 2100 },
    { name = "Hunter's Mark", level = 22, spell = 14323, rank = "Rank 2", cost = 7000 },
    { name = "Scorpid Sting", level = 22, spell = 3043, rank = "", cost = 7000 },
    { name = "Beast Lore", level = 24, spell = 1462, rank = "", cost = 7200 },
    { name = "Raptor Strike", level = 24, spell = 14262, rank = "Rank 4", cost = 7200 },
    { name = "Track Hidden", level = 24, spell = 19885, rank = "", cost = 7200 },
    { name = "Immolation Trap", level = 26, spell = 14302, rank = "Rank 2", cost = 7400 },
    { name = "Rapid Fire", level = 26, spell = 3045, rank = "", cost = 7400 },
    { name = "Serpent Sting", level = 26, spell = 13551, rank = "Rank 4", cost = 7400 },
    { name = "Track Elementals", level = 26, spell = 19880, rank = "", cost = 7400 },
    { name = "Aimed Shot", level = 28, spell = 20900, rank = "Rank 2", cost = 7500 },
    { name = "Arcane Shot", level = 28, spell = 14283, rank = "Rank 4", cost = 7500 },
    { name = "Aspect of the Hawk", level = 28, spell = 14319, rank = "Rank 3", cost = 7500 },
    { name = "Frost Trap", level = 28, spell = 13809, rank = "", cost = 7500 },
    { name = "Mend Pet", level = 28, spell = 3661, rank = "Rank 3", cost = 7500 },
    { name = "Aspect of the Beast", level = 30, spell = 13161, rank = "Rank 1", cost = 7600 },
    { name = "Counterattack", level = 30, spell = 1242634, rank = "Rank 2", cost = 7600 },
    { name = "Distracting Shot", level = 30, spell = 15629, rank = "Rank 3", cost = 7600 },
    { name = "Feign Death", level = 30, spell = 5384, rank = "", cost = 7600 },
    { name = "Mongoose Bite", level = 30, spell = 14269, rank = "Rank 2", cost = 7600 },
    { name = "Scare Beast", level = 30, spell = 14326, rank = "Rank 2", cost = 7600 },
    { name = "Flare", level = 32, spell = 1543, rank = "", cost = 10000 },
    { name = "Raptor Strike", level = 32, spell = 14263, rank = "Rank 5", cost = 10000 },
    { name = "Track Demons", level = 32, spell = 19878, rank = "", cost = 10000 },
    { name = "Trueshot Aura", level = 32, spell = 1299348, rank = "Rank 2", cost = 10000 },
    { name = "Disengage", level = 34, spell = 14272, rank = "Rank 2", cost = 11000 },
    { name = "Explosive Trap", level = 34, spell = 13813, rank = "Rank 1", cost = 11000 },
    { name = "Serpent Sting", level = 34, spell = 13552, rank = "Rank 5", cost = 11000 },
    { name = "Aimed Shot", level = 36, spell = 20901, rank = "Rank 3", cost = 13000 },
    { name = "Arcane Shot", level = 36, spell = 14284, rank = "Rank 5", cost = 13000 },
    { name = "Immolation Trap", level = 36, spell = 14303, rank = "Rank 3", cost = 13000 },
    { name = "Mend Pet", level = 36, spell = 3662, rank = "Rank 4", cost = 13000 },
    { name = "Summon Hawk", level = 36, spell = 1293525, rank = "Rank 2", cost = 13000 },
    { name = "Viper Sting", level = 36, spell = 3034, rank = "Rank 1", cost = 13000 },
    { name = "Aspect of the Hawk", level = 38, spell = 14320, rank = "Rank 4", cost = 15000 },
    { name = "Wing Clip", level = 38, spell = 14267, rank = "Rank 2", cost = 15000 },
    { name = "Aspect of the Beast", level = 40, spell = 1299445, rank = "Rank 2", cost = 16000 },
    { name = "Aspect of the Pack", level = 40, spell = 13159, rank = "", cost = 16000 },
    { name = "Distracting Shot", level = 40, spell = 15630, rank = "Rank 4", cost = 16000 },
    { name = "Freezing Trap", level = 40, spell = 14310, rank = "Rank 2", cost = 16000 },
    { name = "Hunter's Mark", level = 40, spell = 14324, rank = "Rank 3", cost = 16000 },
    { name = "Mail", level = 40, spell = 8737, rank = "", cost = 16000 },
    { name = "Raptor Strike", level = 40, spell = 14264, rank = "Rank 6", cost = 16000 },
    { name = "Track Giants", level = 40, spell = 19882, rank = "", cost = 16000 },
    { name = "Trueshot Aura", level = 40, spell = 19506, rank = "Rank 3", cost = 16000 },
    { name = "Volley", level = 40, spell = 1510, rank = "Rank 1", cost = 16000 },
    { name = "Counterattack", level = 42, spell = 20909, rank = "Rank 3", cost = 22000 },
    { name = "Serpent Sting", level = 42, spell = 13553, rank = "Rank 6", cost = 22000 },
    { name = "Aimed Shot", level = 44, spell = 20902, rank = "Rank 4", cost = 23000 },
    { name = "Arcane Shot", level = 44, spell = 14285, rank = "Rank 6", cost = 23000 },
    { name = "Explosive Trap", level = 44, spell = 14316, rank = "Rank 2", cost = 23000 },
    { name = "Mend Pet", level = 44, spell = 13542, rank = "Rank 5", cost = 23000 },
    { name = "Mongoose Bite", level = 44, spell = 14270, rank = "Rank 3", cost = 23000 },
    { name = "Aspect of the Wild", level = 46, spell = 20043, rank = "Rank 1", cost = 28000 },
    { name = "Immolation Trap", level = 46, spell = 14304, rank = "Rank 4", cost = 28000 },
    { name = "Scare Beast", level = 46, spell = 14327, rank = "Rank 3", cost = 28000 },
    { name = "Viper Sting", level = 46, spell = 14279, rank = "Rank 2", cost = 28000 },
    { name = "Aspect of the Hawk", level = 48, spell = 14321, rank = "Rank 5", cost = 29000 },
    { name = "Disengage", level = 48, spell = 14273, rank = "Rank 3", cost = 29000 },
    { name = "Raptor Strike", level = 48, spell = 14265, rank = "Rank 7", cost = 29000 },
    { name = "Sniper Shot", level = 48, spell = 1310785, rank = "Rank 2", cost = 29000 },
    { name = "Summon Hawk", level = 48, spell = 1293526, rank = "Rank 3", cost = 29000 },
    { name = "Aspect of the Beast", level = 50, spell = 1299446, rank = "Rank 3", cost = 30000 },
    { name = "Distracting Shot", level = 50, spell = 15631, rank = "Rank 5", cost = 30000 },
    { name = "Serpent Sting", level = 50, spell = 13554, rank = "Rank 7", cost = 30000 },
    { name = "Track Dragonkin", level = 50, spell = 19879, rank = "", cost = 30000 },
    { name = "Trueshot Aura", level = 50, spell = 20905, rank = "Rank 4", cost = 30000 },
    { name = "Volley", level = 50, spell = 14294, rank = "Rank 2", cost = 30000 },
    { name = "Aimed Shot", level = 52, spell = 20903, rank = "Rank 5", cost = 36000 },
    { name = "Arcane Shot", level = 52, spell = 14286, rank = "Rank 7", cost = 36000 },
    { name = "Mend Pet", level = 52, spell = 13543, rank = "Rank 6", cost = 36000 },
    { name = "Counterattack", level = 54, spell = 20910, rank = "Rank 4", cost = 37000 },
    { name = "Explosive Trap", level = 54, spell = 14317, rank = "Rank 3", cost = 37000 },
    { name = "Aspect of the Wild", level = 56, spell = 20190, rank = "Rank 2", cost = 38000 },
    { name = "Immolation Trap", level = 56, spell = 14305, rank = "Rank 5", cost = 38000 },
    { name = "Raptor Strike", level = 56, spell = 14266, rank = "Rank 8", cost = 38000 },
    { name = "Viper Sting", level = 56, spell = 14280, rank = "Rank 3", cost = 38000 },
    { name = "Aspect of the Hawk", level = 58, spell = 14322, rank = "Rank 6", cost = 39000 },
    { name = "Hunter's Mark", level = 58, spell = 14325, rank = "Rank 4", cost = 39000 },
    { name = "Mongoose Bite", level = 58, spell = 14271, rank = "Rank 4", cost = 39000 },
    { name = "Serpent Sting", level = 58, spell = 13555, rank = "Rank 8", cost = 39000 },
    { name = "Sniper Shot", level = 58, spell = 1310786, rank = "Rank 3", cost = 39000 },
    { name = "Volley", level = 58, spell = 14295, rank = "Rank 3", cost = 39000 },
    { name = "Aimed Shot", level = 60, spell = 20904, rank = "Rank 6", cost = 42000 },
    { name = "Arcane Shot", level = 60, spell = 14287, rank = "Rank 8", cost = 42000 },
    { name = "Aspect of the Beast", level = 60, spell = 1299447, rank = "Rank 4", cost = 39000 },
    { name = "Distracting Shot", level = 60, spell = 15632, rank = "Rank 6", cost = 42000 },
    { name = "Freezing Trap", level = 60, spell = 14311, rank = "Rank 3", cost = 42000 },
    { name = "Mend Pet", level = 60, spell = 13544, rank = "Rank 7", cost = 42000 },
    { name = "Summon Hawk", level = 60, spell = 1293527, rank = "Rank 4", cost = 42000 },
    { name = "Trueshot Aura", level = 60, spell = 20906, rank = "Rank 5", cost = 42000 },
    { name = "Wing Clip", level = 60, spell = 14268, rank = "Rank 3", cost = 42000 },
}

ns.classTraining.PRIEST = {
    { name = "Power Word: Fortitude", level = 1, spell = 1243, rank = "Rank 1", cost = 10 },
    { name = "Lesser Heal", level = 4, spell = 2052, rank = "Rank 2", cost = 100 },
    { name = "Shadow Word: Pain", level = 4, spell = 589, rank = "Rank 1", cost = 100 },
    { name = "Power Word: Shield", level = 6, spell = 17, rank = "Rank 1", cost = 100 },
    { name = "Smite", level = 6, spell = 591, rank = "Rank 2", cost = 100 },
    { name = "Fade", level = 8, spell = 586, rank = "Rank 1", cost = 200 },
    { name = "Renew", level = 8, spell = 139, rank = "Rank 1", cost = 200 },
    { name = "Lesser Heal", level = 10, spell = 2053, rank = "Rank 3", cost = 300 },
    { name = "Mind Blast", level = 10, spell = 8092, rank = "Rank 1", cost = 300 },
    { name = "Resurrection", level = 10, spell = 2006, rank = "Rank 1", cost = 300 },
    { name = "Shadow Word: Pain", level = 10, spell = 594, rank = "Rank 2", cost = 300 },
    { name = "Inner Fire", level = 12, spell = 588, rank = "Rank 1", cost = 800 },
    { name = "Power Word: Fortitude", level = 12, spell = 1244, rank = "Rank 2", cost = 800 },
    { name = "Power Word: Shield", level = 12, spell = 592, rank = "Rank 2", cost = 800 },
    { name = "Cure Disease", level = 14, spell = 528, rank = "", cost = 1200 },
    { name = "Psychic Scream", level = 14, spell = 8122, rank = "Rank 1", cost = 1200 },
    { name = "Renew", level = 14, spell = 6074, rank = "Rank 2", cost = 1200 },
    { name = "Smite", level = 14, spell = 598, rank = "Rank 3", cost = 1200 },
    { name = "Heal", level = 16, spell = 2054, rank = "Rank 1", cost = 1600 },
    { name = "Mind Blast", level = 16, spell = 8102, rank = "Rank 2", cost = 1600 },
    { name = "Dispel Magic", level = 18, spell = 527, rank = "Rank 1", cost = 2000 },
    { name = "Power Word: Shield", level = 18, spell = 600, rank = "Rank 3", cost = 2000 },
    { name = "Shadow Word: Pain", level = 18, spell = 970, rank = "Rank 3", cost = 2000 },
    { name = "Devouring Plague", level = 20, spell = 2944, rank = "Rank 1", cost = 300 },
    { name = "Fade", level = 20, spell = 9578, rank = "Rank 2", cost = 3000 },
    { name = "Fear Ward", level = 20, spell = 6346, rank = "", cost = 300 },
    { name = "Flash Heal", level = 20, spell = 2061, rank = "Rank 1", cost = 3000 },
    { name = "Hex of Weakness", level = 20, spell = 19281, rank = "Rank 2", cost = 150 },
    { name = "Holy Fire", level = 20, spell = 14914, rank = "Rank 1", cost = 3000 },
    { name = "Inner Fire", level = 20, spell = 7128, rank = "Rank 2", cost = 3000 },
    { name = "Mind Soothe", level = 20, spell = 453, rank = "Rank 1", cost = 3000 },
    { name = "Renew", level = 20, spell = 6075, rank = "Rank 3", cost = 3000 },
    { name = "Shackle Undead", level = 20, spell = 9484, rank = "Rank 1", cost = 3000 },
    { name = "Heal", level = 22, spell = 2055, rank = "Rank 2", cost = 4000 },
    { name = "Mind Blast", level = 22, spell = 8103, rank = "Rank 3", cost = 4000 },
    { name = "Mind Vision", level = 22, spell = 2096, rank = "Rank 1", cost = 4000 },
    { name = "Resurrection", level = 22, spell = 2010, rank = "Rank 2", cost = 4000 },
    { name = "Smite", level = 22, spell = 984, rank = "Rank 4", cost = 4000 },
    { name = "Holy Fire", level = 24, spell = 15262, rank = "Rank 2", cost = 5000 },
    { name = "Mana Burn", level = 24, spell = 8129, rank = "Rank 1", cost = 5000 },
    { name = "Power Word: Fortitude", level = 24, spell = 1245, rank = "Rank 3", cost = 5000 },
    { name = "Power Word: Shield", level = 24, spell = 3747, rank = "Rank 4", cost = 5000 },
    { name = "Flash Heal", level = 26, spell = 9472, rank = "Rank 2", cost = 6000 },
    { name = "Renew", level = 26, spell = 6076, rank = "Rank 4", cost = 6000 },
    { name = "Shadow Word: Pain", level = 26, spell = 992, rank = "Rank 4", cost = 6000 },
    { name = "Devouring Plague", level = 28, spell = 19276, rank = "Rank 2", cost = 400 },
    { name = "Heal", level = 28, spell = 6063, rank = "Rank 3", cost = 8000 },
    { name = "Holy Nova", level = 28, spell = 15430, rank = "Rank 2", cost = 400 },
    { name = "Mind Blast", level = 28, spell = 8104, rank = "Rank 4", cost = 8000 },
    { name = "Mind Flay", level = 28, spell = 17311, rank = "Rank 2", cost = 400 },
    { name = "Psychic Scream", level = 28, spell = 8124, rank = "Rank 2", cost = 8000 },
    { name = "Shadowguard", level = 28, spell = 19308, rank = "Rank 2", cost = 400 },
    { name = "Divine Spirit", level = 30, spell = 14752, rank = "Rank 1", cost = 10000 },
    { name = "Fade", level = 30, spell = 9579, rank = "Rank 3", cost = 10000 },
    { name = "Hex of Weakness", level = 30, spell = 19282, rank = "Rank 3", cost = 500 },
    { name = "Holy Fire", level = 30, spell = 15263, rank = "Rank 3", cost = 10000 },
    { name = "Inner Fire", level = 30, spell = 602, rank = "Rank 3", cost = 10000 },
    { name = "Mind Control", level = 30, spell = 605, rank = "Rank 1", cost = 10000 },
    { name = "Power Word: Shield", level = 30, spell = 6065, rank = "Rank 5", cost = 10000 },
    { name = "Prayer of Healing", level = 30, spell = 596, rank = "Rank 1", cost = 10000 },
    { name = "Shadow Protection", level = 30, spell = 976, rank = "Rank 1", cost = 10000 },
    { name = "Smite", level = 30, spell = 1004, rank = "Rank 5", cost = 10000 },
    { name = "Abolish Disease", level = 32, spell = 552, rank = "", cost = 11000 },
    { name = "Binding Heal", level = 32, spell = 1240770, rank = "Rank 2", cost = 11000 },
    { name = "Flash Heal", level = 32, spell = 9473, rank = "Rank 3", cost = 11000 },
    { name = "Mana Burn", level = 32, spell = 8131, rank = "Rank 2", cost = 11000 },
    { name = "Renew", level = 32, spell = 6077, rank = "Rank 5", cost = 11000 },
    { name = "Shadow Word: Death", level = 32, spell = 1309595, rank = "Rank 1", cost = 11000 },
    { name = "Heal", level = 34, spell = 6064, rank = "Rank 4", cost = 12000 },
    { name = "Levitate", level = 34, spell = 1706, rank = "", cost = 12000 },
    { name = "Mind Blast", level = 34, spell = 8105, rank = "Rank 5", cost = 12000 },
    { name = "Resurrection", level = 34, spell = 10880, rank = "Rank 3", cost = 12000 },
    { name = "Shadow Word: Pain", level = 34, spell = 2767, rank = "Rank 5", cost = 12000 },
    { name = "Devouring Plague", level = 36, spell = 19277, rank = "Rank 3", cost = 700 },
    { name = "Dispel Magic", level = 36, spell = 988, rank = "Rank 2", cost = 14000 },
    { name = "Holy Fire", level = 36, spell = 15264, rank = "Rank 4", cost = 14000 },
    { name = "Holy Nova", level = 36, spell = 15431, rank = "Rank 3", cost = 700 },
    { name = "Mind Flay", level = 36, spell = 17312, rank = "Rank 3", cost = 700 },
    { name = "Mind Soothe", level = 36, spell = 8192, rank = "Rank 2", cost = 14000 },
    { name = "Power Word: Fortitude", level = 36, spell = 2791, rank = "Rank 4", cost = 14000 },
    { name = "Power Word: Shield", level = 36, spell = 6066, rank = "Rank 6", cost = 14000 },
    { name = "Shadowguard", level = 36, spell = 19309, rank = "Rank 3", cost = 700 },
    { name = "Binding Heal", level = 38, spell = 1240771, rank = "Rank 3", cost = 16000 },
    { name = "Flash Heal", level = 38, spell = 9474, rank = "Rank 4", cost = 16000 },
    { name = "Renew", level = 38, spell = 6078, rank = "Rank 6", cost = 16000 },
    { name = "Smite", level = 38, spell = 6060, rank = "Rank 6", cost = 16000 },
    { name = "Divine Spirit", level = 40, spell = 14818, rank = "Rank 2", cost = 900 },
    { name = "Fade", level = 40, spell = 9592, rank = "Rank 4", cost = 18000 },
    { name = "Greater Heal", level = 40, spell = 2060, rank = "Rank 1", cost = 18000 },
    { name = "Hex of Weakness", level = 40, spell = 19283, rank = "Rank 4", cost = 900 },
    { name = "Inner Fire", level = 40, spell = 1006, rank = "Rank 4", cost = 18000 },
    { name = "Mana Burn", level = 40, spell = 10874, rank = "Rank 3", cost = 18000 },
    { name = "Mind Blast", level = 40, spell = 8106, rank = "Rank 6", cost = 18000 },
    { name = "Penance", level = 40, spell = 1240720, rank = "Rank 2", cost = 16000 },
    { name = "Prayer of Healing", level = 40, spell = 996, rank = "Rank 2", cost = 18000 },
    { name = "Shackle Undead", level = 40, spell = 9485, rank = "Rank 2", cost = 18000 },
    { name = "Shadow Word: Death", level = 40, spell = 1309633, rank = "Rank 2", cost = 18000 },
    { name = "Holy Fire", level = 42, spell = 15265, rank = "Rank 5", cost = 22000 },
    { name = "Power Word: Shield", level = 42, spell = 10898, rank = "Rank 7", cost = 22000 },
    { name = "Psychic Scream", level = 42, spell = 10888, rank = "Rank 3", cost = 22000 },
    { name = "Shadow Protection", level = 42, spell = 10957, rank = "Rank 2", cost = 22000 },
    { name = "Shadow Word: Pain", level = 42, spell = 10892, rank = "Rank 6", cost = 22000 },
    { name = "Binding Heal", level = 44, spell = 1240772, rank = "Rank 4", cost = 24000 },
    { name = "Devouring Plague", level = 44, spell = 19278, rank = "Rank 4", cost = 1200 },
    { name = "Flash Heal", level = 44, spell = 10915, rank = "Rank 5", cost = 24000 },
    { name = "Holy Nova", level = 44, spell = 27799, rank = "Rank 4", cost = 1200 },
    { name = "Mind Control", level = 44, spell = 10911, rank = "Rank 2", cost = 24000 },
    { name = "Mind Flay", level = 44, spell = 17313, rank = "Rank 4", cost = 1200 },
    { name = "Mind Vision", level = 44, spell = 10909, rank = "Rank 2", cost = 24000 },
    { name = "Renew", level = 44, spell = 10927, rank = "Rank 7", cost = 24000 },
    { name = "Shadowguard", level = 44, spell = 19310, rank = "Rank 4", cost = 1200 },
    { name = "Greater Heal", level = 46, spell = 10963, rank = "Rank 2", cost = 26000 },
    { name = "Mind Blast", level = 46, spell = 10945, rank = "Rank 7", cost = 26000 },
    { name = "Resurrection", level = 46, spell = 10881, rank = "Rank 4", cost = 26000 },
    { name = "Smite", level = 46, spell = 10933, rank = "Rank 7", cost = 26000 },
    { name = "Holy Fire", level = 48, spell = 15266, rank = "Rank 6", cost = 28000 },
    { name = "Mana Burn", level = 48, spell = 10875, rank = "Rank 4", cost = 28000 },
    { name = "Power Word: Fortitude", level = 48, spell = 10937, rank = "Rank 5", cost = 28000 },
    { name = "Power Word: Shield", level = 48, spell = 10899, rank = "Rank 8", cost = 28000 },
    { name = "Shadow Word: Death", level = 48, spell = 1309635, rank = "Rank 3", cost = 28000 },
    { name = "Binding Heal", level = 50, spell = 1240773, rank = "Rank 5", cost = 30000 },
    { name = "Divine Spirit", level = 50, spell = 14819, rank = "Rank 3", cost = 1500 },
    { name = "Fade", level = 50, spell = 10941, rank = "Rank 5", cost = 30000 },
    { name = "Flash Heal", level = 50, spell = 10916, rank = "Rank 6", cost = 30000 },
    { name = "Hex of Weakness", level = 50, spell = 19284, rank = "Rank 5", cost = 1500 },
    { name = "Inner Fire", level = 50, spell = 10951, rank = "Rank 5", cost = 30000 },
    { name = "Penance", level = 50, spell = 1240721, rank = "Rank 3", cost = 30000 },
    { name = "Prayer of Healing", level = 50, spell = 10960, rank = "Rank 3", cost = 30000 },
    { name = "Prayer of Mending", level = 50, spell = 1240826, rank = "Rank 2", cost = 30000 },
    { name = "Renew", level = 50, spell = 10928, rank = "Rank 8", cost = 30000 },
    { name = "Shadow Word: Pain", level = 50, spell = 10893, rank = "Rank 7", cost = 30000 },
    { name = "Devouring Plague", level = 52, spell = 19279, rank = "Rank 5", cost = 1900 },
    { name = "Greater Heal", level = 52, spell = 10964, rank = "Rank 3", cost = 38000 },
    { name = "Holy Nova", level = 52, spell = 27800, rank = "Rank 5", cost = 1900 },
    { name = "Mind Blast", level = 52, spell = 10946, rank = "Rank 8", cost = 38000 },
    { name = "Mind Flay", level = 52, spell = 17314, rank = "Rank 5", cost = 1900 },
    { name = "Mind Soothe", level = 52, spell = 10953, rank = "Rank 3", cost = 38000 },
    { name = "Shadowguard", level = 52, spell = 19311, rank = "Rank 5", cost = 1900 },
    { name = "Holy Fire", level = 54, spell = 15267, rank = "Rank 7", cost = 40000 },
    { name = "Power Word: Shield", level = 54, spell = 10900, rank = "Rank 9", cost = 40000 },
    { name = "Smite", level = 54, spell = 10934, rank = "Rank 8", cost = 40000 },
    { name = "Binding Heal", level = 56, spell = 1240774, rank = "Rank 6", cost = 42000 },
    { name = "Flash Heal", level = 56, spell = 10917, rank = "Rank 7", cost = 42000 },
    { name = "Mana Burn", level = 56, spell = 10876, rank = "Rank 5", cost = 42000 },
    { name = "Psychic Scream", level = 56, spell = 10890, rank = "Rank 4", cost = 42000 },
    { name = "Renew", level = 56, spell = 10929, rank = "Rank 9", cost = 42000 },
    { name = "Shadow Protection", level = 56, spell = 10958, rank = "Rank 3", cost = 42000 },
    { name = "Shadow Word: Death", level = 56, spell = 1309636, rank = "Rank 4", cost = 42000 },
    { name = "Greater Heal", level = 58, spell = 10965, rank = "Rank 4", cost = 44000 },
    { name = "Mind Blast", level = 58, spell = 10947, rank = "Rank 9", cost = 44000 },
    { name = "Mind Control", level = 58, spell = 10912, rank = "Rank 3", cost = 44000 },
    { name = "Resurrection", level = 58, spell = 20770, rank = "Rank 5", cost = 44000 },
    { name = "Shadow Word: Pain", level = 58, spell = 10894, rank = "Rank 8", cost = 44000 },
    { name = "Devouring Plague", level = 60, spell = 19280, rank = "Rank 6", cost = 2300 },
    { name = "Divine Spirit", level = 60, spell = 27841, rank = "Rank 4", cost = 2300 },
    { name = "Fade", level = 60, spell = 10942, rank = "Rank 6", cost = 46000 },
    { name = "Hex of Weakness", level = 60, spell = 19285, rank = "Rank 6", cost = 2300 },
    { name = "Holy Fire", level = 60, spell = 15261, rank = "Rank 8", cost = 46000 },
    { name = "Holy Nova", level = 60, spell = 27801, rank = "Rank 6", cost = 2300 },
    { name = "Inner Fire", level = 60, spell = 10952, rank = "Rank 6", cost = 46000 },
    { name = "Mind Flay", level = 60, spell = 18807, rank = "Rank 6", cost = 2300 },
    { name = "Penance", level = 60, spell = 1316995, rank = "Rank 4", cost = 46000 },
    { name = "Power Word: Fortitude", level = 60, spell = 10938, rank = "Rank 6", cost = 46000 },
    { name = "Power Word: Shield", level = 60, spell = 10901, rank = "Rank 10", cost = 46000 },
    { name = "Prayer of Healing", level = 60, spell = 10961, rank = "Rank 4", cost = 46000 },
    { name = "Prayer of Mending", level = 60, spell = 1240827, rank = "Rank 3", cost = 46000 },
    { name = "Prayer of Spirit", level = 60, spell = 27681, rank = "Rank 1", cost = 2300 },
    { name = "Shackle Undead", level = 60, spell = 10955, rank = "Rank 3", cost = 46000 },
    { name = "Shadowguard", level = 60, spell = 19312, rank = "Rank 6", cost = 2300 },
}

ns.classTraining.DRUID = {
    { name = "Mark of the Wild", level = 1, spell = 1126, rank = "Rank 1", cost = 10 },
    { name = "Moonfire", level = 4, spell = 8921, rank = "Rank 1", cost = 100 },
    { name = "Rejuvenation", level = 4, spell = 774, rank = "Rank 1", cost = 100 },
    { name = "Thorns", level = 6, spell = 467, rank = "Rank 1", cost = 100 },
    { name = "Wrath", level = 6, spell = 5177, rank = "Rank 2", cost = 100 },
    { name = "Entangling Roots", level = 8, spell = 339, rank = "Rank 1", cost = 200 },
    { name = "Healing Touch", level = 8, spell = 5186, rank = "Rank 2", cost = 200 },
    { name = "Demoralizing Roar", level = 10, spell = 99, rank = "Rank 1", cost = 300 },
    { name = "Mark of the Wild", level = 10, spell = 5232, rank = "Rank 2", cost = 300 },
    { name = "Moonfire", level = 10, spell = 8924, rank = "Rank 2", cost = 300 },
    { name = "Nature's Grasp", level = 10, spell = 16689, rank = "Rank 1", cost = 300 },
    { name = "Rejuvenation", level = 10, spell = 1058, rank = "Rank 2", cost = 300 },
    { name = "Enrage", level = 12, spell = 5229, rank = "", cost = 800 },
    { name = "Regrowth", level = 12, spell = 8936, rank = "Rank 1", cost = 800 },
    { name = "Revive", level = 12, spell = 437138, rank = "Rank 1", cost = 800 },
    { name = "Bash", level = 14, spell = 5211, rank = "Rank 1", cost = 900 },
    { name = "Healing Touch", level = 14, spell = 5187, rank = "Rank 3", cost = 900 },
    { name = "Thorns", level = 14, spell = 782, rank = "Rank 2", cost = 900 },
    { name = "Wrath", level = 14, spell = 5178, rank = "Rank 3", cost = 900 },
    { name = "Moonfire", level = 16, spell = 8925, rank = "Rank 3", cost = 1400 },
    { name = "Rejuvenation", level = 16, spell = 1430, rank = "Rank 3", cost = 1400 },
    { name = "Swipe", level = 16, spell = 779, rank = "Rank 1", cost = 1400 },
    { name = "Entangling Roots", level = 18, spell = 1062, rank = "Rank 2", cost = 1500 },
    { name = "Faerie Fire", level = 18, spell = 770, rank = "Rank 1", cost = 1500 },
    { name = "Hibernate", level = 18, spell = 2637, rank = "Rank 1", cost = 1500 },
    { name = "Maul", level = 18, spell = 6808, rank = "Rank 2", cost = 1500 },
    { name = "Nature's Grasp", level = 18, spell = 16810, rank = "Rank 2", cost = 1500 },
    { name = "Regrowth", level = 18, spell = 8938, rank = "Rank 2", cost = 1500 },
    { name = "Demoralizing Roar", level = 20, spell = 1735, rank = "Rank 2", cost = 2400 },
    { name = "Healing Touch", level = 20, spell = 5188, rank = "Rank 4", cost = 2400 },
    { name = "Mark of the Wild", level = 20, spell = 6756, rank = "Rank 3", cost = 2400 },
    { name = "Omen of Clarity", level = 20, spell = 16864, rank = "", cost = 2400 },
    { name = "Rebirth", level = 20, spell = 20484, rank = "Rank 1", cost = 2400 },
    { name = "Starfire", level = 20, spell = 2912, rank = "Rank 1", cost = 2400 },
    { name = "Moonfire", level = 22, spell = 8926, rank = "Rank 4", cost = 3300 },
    { name = "Rejuvenation", level = 22, spell = 2090, rank = "Rank 4", cost = 3300 },
    { name = "Shred", level = 22, spell = 5221, rank = "Rank 1", cost = 3300 },
    { name = "Soothe Animal", level = 22, spell = 2908, rank = "Rank 1", cost = 3300 },
    { name = "Wrath", level = 22, spell = 5179, rank = "Rank 4", cost = 3300 },
    { name = "Rake", level = 24, spell = 1822, rank = "Rank 1", cost = 3800 },
    { name = "Regrowth", level = 24, spell = 8939, rank = "Rank 3", cost = 3800 },
    { name = "Remove Curse", level = 24, spell = 2782, rank = "", cost = 3800 },
    { name = "Revive", level = 24, spell = 1237948, rank = "Rank 2", cost = 3800 },
    { name = "Swipe", level = 24, spell = 780, rank = "Rank 2", cost = 3800 },
    { name = "Thorns", level = 24, spell = 1075, rank = "Rank 3", cost = 3800 },
    { name = "Tiger's Fury", level = 24, spell = 5217, rank = "", cost = 3800 },
    { name = "Abolish Poison", level = 26, spell = 2893, rank = "", cost = 4400 },
    { name = "Dash", level = 26, spell = 1850, rank = "Rank 1", cost = 4400 },
    { name = "Healing Touch", level = 26, spell = 5189, rank = "Rank 5", cost = 4400 },
    { name = "Maul", level = 26, spell = 6809, rank = "Rank 3", cost = 4400 },
    { name = "Starfire", level = 26, spell = 8949, rank = "Rank 2", cost = 4400 },
    { name = "Challenging Roar", level = 28, spell = 5209, rank = "", cost = 4500 },
    { name = "Claw", level = 28, spell = 3029, rank = "Rank 2", cost = 4500 },
    { name = "Cower", level = 28, spell = 8998, rank = "Rank 1", cost = 4500 },
    { name = "Entangling Roots", level = 28, spell = 5195, rank = "Rank 3", cost = 4500 },
    { name = "Moonfire", level = 28, spell = 8927, rank = "Rank 5", cost = 4500 },
    { name = "Nature's Grasp", level = 28, spell = 16811, rank = "Rank 3", cost = 4500 },
    { name = "Rejuvenation", level = 28, spell = 2091, rank = "Rank 5", cost = 4500 },
    { name = "Rip", level = 28, spell = 9492, rank = "Rank 2", cost = 4500 },
    { name = "Bash", level = 30, spell = 6798, rank = "Rank 2", cost = 4600 },
    { name = "Faerie Fire", level = 30, spell = 778, rank = "Rank 2", cost = 4600 },
    { name = "Insect Swarm", level = 30, spell = 24974, rank = "Rank 2", cost = 4600 },
    { name = "Mark of the Wild", level = 30, spell = 5234, rank = "Rank 4", cost = 4600 },
    { name = "Rebirth", level = 30, spell = 20739, rank = "Rank 2", cost = 4600 },
    { name = "Regrowth", level = 30, spell = 8940, rank = "Rank 4", cost = 4600 },
    { name = "Shred", level = 30, spell = 6800, rank = "Rank 2", cost = 4600 },
    { name = "Tranquility", level = 30, spell = 740, rank = "Rank 1", cost = 4600 },
    { name = "Travel Form", level = 30, spell = 783, rank = "Shapeshift", cost = 4600 },
    { name = "Wrath", level = 30, spell = 5180, rank = "Rank 5", cost = 4600 },
    { name = "Demoralizing Roar", level = 32, spell = 9490, rank = "Rank 3", cost = 5000 },
    { name = "Ferocious Bite", level = 32, spell = 22568, rank = "Rank 1", cost = 5000 },
    { name = "Healing Touch", level = 32, spell = 6778, rank = "Rank 6", cost = 5000 },
    { name = "Ravage", level = 32, spell = 6785, rank = "Rank 1", cost = 5000 },
    { name = "Track Humanoids", level = 32, spell = 5225, rank = "", cost = 5000 },
    { name = "Maul", level = 34, spell = 8972, rank = "Rank 4", cost = 7000 },
    { name = "Moonfire", level = 34, spell = 8928, rank = "Rank 6", cost = 7000 },
    { name = "Rake", level = 34, spell = 1823, rank = "Rank 2", cost = 7000 },
    { name = "Rejuvenation", level = 34, spell = 3627, rank = "Rank 6", cost = 7000 },
    { name = "Starfire", level = 34, spell = 8950, rank = "Rank 3", cost = 7000 },
    { name = "Swipe", level = 34, spell = 769, rank = "Rank 3", cost = 7000 },
    { name = "Thorns", level = 34, spell = 8914, rank = "Rank 4", cost = 7000 },
    { name = "Frenzied Regeneration", level = 36, spell = 22842, rank = "", cost = 8000 },
    { name = "Pounce", level = 36, spell = 9005, rank = "Rank 1", cost = 8000 },
    { name = "Regrowth", level = 36, spell = 8941, rank = "Rank 5", cost = 8000 },
    { name = "Revive", level = 36, spell = 1237949, rank = "Rank 3", cost = 8000 },
    { name = "Rip", level = 36, spell = 9493, rank = "Rank 3", cost = 8000 },
    { name = "Claw", level = 38, spell = 5201, rank = "Rank 3", cost = 10000 },
    { name = "Entangling Roots", level = 38, spell = 5196, rank = "Rank 4", cost = 10000 },
    { name = "Healing Touch", level = 38, spell = 8903, rank = "Rank 7", cost = 10000 },
    { name = "Hibernate", level = 38, spell = 18657, rank = "Rank 2", cost = 10000 },
    { name = "Nature's Grasp", level = 38, spell = 16812, rank = "Rank 4", cost = 10000 },
    { name = "Shred", level = 38, spell = 8992, rank = "Rank 3", cost = 10000 },
    { name = "Soothe Animal", level = 38, spell = 8955, rank = "Rank 2", cost = 10000 },
    { name = "Wrath", level = 38, spell = 6780, rank = "Rank 6", cost = 10000 },
    { name = "Cower", level = 40, spell = 9000, rank = "Rank 2", cost = 11000 },
    { name = "Dire Bear Form", level = 40, spell = 9634, rank = "Shapeshift", cost = 11000 },
    { name = "Feline Grace", level = 40, spell = 20719, rank = "Passive", cost = 11000 },
    { name = "Ferocious Bite", level = 40, spell = 22827, rank = "Rank 2", cost = 11000 },
    { name = "Hurricane", level = 40, spell = 16914, rank = "Rank 1", cost = 11000 },
    { name = "Innervate", level = 40, spell = 29166, rank = "", cost = 11000 },
    { name = "Insect Swarm", level = 40, spell = 24975, rank = "Rank 3", cost = 11000 },
    { name = "Mark of the Wild", level = 40, spell = 8907, rank = "Rank 5", cost = 11000 },
    { name = "Moonfire", level = 40, spell = 8929, rank = "Rank 7", cost = 11000 },
    { name = "Prowl", level = 40, spell = 6783, rank = "Rank 2", cost = 11000 },
    { name = "Rebirth", level = 40, spell = 20742, rank = "Rank 3", cost = 11000 },
    { name = "Rejuvenation", level = 40, spell = 8910, rank = "Rank 7", cost = 11000 },
    { name = "Tranquility", level = 40, spell = 8918, rank = "Rank 2", cost = 11000 },
    { name = "Demoralizing Roar", level = 42, spell = 9747, rank = "Rank 4", cost = 12000 },
    { name = "Faerie Fire", level = 42, spell = 9749, rank = "Rank 3", cost = 12000 },
    { name = "Lacerate", level = 42, spell = 414644, rank = "Rank 1", cost = 12000 },
    { name = "Maul", level = 42, spell = 9745, rank = "Rank 5", cost = 12000 },
    { name = "Ravage", level = 42, spell = 6787, rank = "Rank 2", cost = 12000 },
    { name = "Regrowth", level = 42, spell = 9750, rank = "Rank 6", cost = 12000 },
    { name = "Starfire", level = 42, spell = 8951, rank = "Rank 4", cost = 12000 },
    { name = "Barkskin", level = 44, spell = 22812, rank = "", cost = 13000 },
    { name = "Healing Touch", level = 44, spell = 9758, rank = "Rank 8", cost = 13000 },
    { name = "Rake", level = 44, spell = 1824, rank = "Rank 3", cost = 13000 },
    { name = "Rip", level = 44, spell = 9752, rank = "Rank 4", cost = 13000 },
    { name = "Swipe", level = 44, spell = 9754, rank = "Rank 4", cost = 13000 },
    { name = "Thorns", level = 44, spell = 9756, rank = "Rank 5", cost = 13000 },
    { name = "Bash", level = 46, spell = 8983, rank = "Rank 3", cost = 16000 },
    { name = "Dash", level = 46, spell = 9821, rank = "Rank 2", cost = 16000 },
    { name = "Moonfire", level = 46, spell = 9833, rank = "Rank 8", cost = 16000 },
    { name = "Pounce", level = 46, spell = 9823, rank = "Rank 2", cost = 16000 },
    { name = "Rejuvenation", level = 46, spell = 9839, rank = "Rank 8", cost = 16000 },
    { name = "Shred", level = 46, spell = 9829, rank = "Rank 4", cost = 16000 },
    { name = "Wrath", level = 46, spell = 8905, rank = "Rank 7", cost = 16000 },
    { name = "Claw", level = 48, spell = 9849, rank = "Rank 4", cost = 17000 },
    { name = "Entangling Roots", level = 48, spell = 9852, rank = "Rank 5", cost = 17000 },
    { name = "Ferocious Bite", level = 48, spell = 22828, rank = "Rank 3", cost = 17000 },
    { name = "Nature's Grasp", level = 48, spell = 16813, rank = "Rank 5", cost = 17000 },
    { name = "Regrowth", level = 48, spell = 9856, rank = "Rank 7", cost = 17000 },
    { name = "Revive", level = 48, spell = 1237950, rank = "Rank 4", cost = 17000 },
    { name = "Healing Touch", level = 50, spell = 9888, rank = "Rank 9", cost = 18000 },
    { name = "Hurricane", level = 50, spell = 17401, rank = "Rank 2", cost = 18000 },
    { name = "Insect Swarm", level = 50, spell = 24976, rank = "Rank 4", cost = 18000 },
    { name = "Lacerate", level = 50, spell = 1235826, rank = "Rank 2", cost = 18000 },
    { name = "Mark of the Wild", level = 50, spell = 9884, rank = "Rank 6", cost = 18000 },
    { name = "Maul", level = 50, spell = 9880, rank = "Rank 6", cost = 18000 },
    { name = "Ravage", level = 50, spell = 9866, rank = "Rank 3", cost = 18000 },
    { name = "Rebirth", level = 50, spell = 20747, rank = "Rank 4", cost = 18000 },
    { name = "Starfire", level = 50, spell = 9875, rank = "Rank 5", cost = 18000 },
    { name = "Tranquility", level = 50, spell = 9862, rank = "Rank 3", cost = 18000 },
    { name = "Wild Growth", level = 50, spell = 1238214, rank = "Rank 2", cost = 18000 },
    { name = "Cower", level = 52, spell = 9892, rank = "Rank 3", cost = 19000 },
    { name = "Demoralizing Roar", level = 52, spell = 9898, rank = "Rank 5", cost = 19000 },
    { name = "Moonfire", level = 52, spell = 9834, rank = "Rank 9", cost = 19000 },
    { name = "Rejuvenation", level = 52, spell = 9840, rank = "Rank 9", cost = 19000 },
    { name = "Rip", level = 52, spell = 9894, rank = "Rank 5", cost = 19000 },
    { name = "Faerie Fire", level = 54, spell = 9907, rank = "Rank 4", cost = 20000 },
    { name = "Rake", level = 54, spell = 9904, rank = "Rank 4", cost = 20000 },
    { name = "Regrowth", level = 54, spell = 9857, rank = "Rank 8", cost = 20000 },
    { name = "Shred", level = 54, spell = 9830, rank = "Rank 5", cost = 20000 },
    { name = "Soothe Animal", level = 54, spell = 9901, rank = "Rank 3", cost = 20000 },
    { name = "Swipe", level = 54, spell = 9908, rank = "Rank 5", cost = 20000 },
    { name = "Thorns", level = 54, spell = 9910, rank = "Rank 6", cost = 20000 },
    { name = "Wrath", level = 54, spell = 9912, rank = "Rank 8", cost = 20000 },
    { name = "Ferocious Bite", level = 56, spell = 22829, rank = "Rank 4", cost = 21000 },
    { name = "Healing Touch", level = 56, spell = 9889, rank = "Rank 10", cost = 21000 },
    { name = "Pounce", level = 56, spell = 9827, rank = "Rank 3", cost = 21000 },
    { name = "Claw", level = 58, spell = 9850, rank = "Rank 5", cost = 22000 },
    { name = "Entangling Roots", level = 58, spell = 9853, rank = "Rank 6", cost = 22000 },
    { name = "Hibernate", level = 58, spell = 18658, rank = "Rank 3", cost = 22000 },
    { name = "Lacerate", level = 58, spell = 1235827, rank = "Rank 3", cost = 22000 },
    { name = "Maul", level = 58, spell = 9881, rank = "Rank 7", cost = 22000 },
    { name = "Moonfire", level = 58, spell = 9835, rank = "Rank 10", cost = 22000 },
    { name = "Nature's Grasp", level = 58, spell = 17329, rank = "Rank 6", cost = 22000 },
    { name = "Ravage", level = 58, spell = 9867, rank = "Rank 4", cost = 22000 },
    { name = "Rejuvenation", level = 58, spell = 9841, rank = "Rank 10", cost = 22000 },
    { name = "Starfire", level = 58, spell = 9876, rank = "Rank 6", cost = 22000 },
    { name = "Hurricane", level = 60, spell = 17402, rank = "Rank 3", cost = 24000 },
    { name = "Insect Swarm", level = 60, spell = 24977, rank = "Rank 5", cost = 24000 },
    { name = "Mark of the Wild", level = 60, spell = 9885, rank = "Rank 7", cost = 24000 },
    { name = "Prowl", level = 60, spell = 9913, rank = "Rank 3", cost = 24000 },
    { name = "Rebirth", level = 60, spell = 20748, rank = "Rank 5", cost = 24000 },
    { name = "Regrowth", level = 60, spell = 9858, rank = "Rank 9", cost = 24000 },
    { name = "Revive", level = 60, spell = 1237951, rank = "Rank 5", cost = 24000 },
    { name = "Rip", level = 60, spell = 9896, rank = "Rank 6", cost = 24000 },
    { name = "Tranquility", level = 60, spell = 9863, rank = "Rank 4", cost = 24000 },
    { name = "Wild Growth", level = 60, spell = 1238215, rank = "Rank 3", cost = 24000 },
}

local CROSS = ns.CROSS

--------------------------------------------------------------------------------
-- The skill list for a class
--------------------------------------------------------------------------------

-- { { name, level, spell, rank, cost }, ... } sorted by level, then name:
-- copies of the class's list, so filling in a rank leaves the list alone.
local function Skills(class)
    local list = {}
    for _, entry in ipairs(ns.classTraining[class] or {}) do
        local skill = {}
        for k, v in pairs(entry) do
            skill[k] = v
        end
        -- The rank text, from the spell when the trainer showed none.
        if not skill.rank and skill.spell and C_Spell and C_Spell.GetSpellSubtext then
            local text = C_Spell.GetSpellSubtext(skill.spell)
            if text and text ~= "" then
                skill.rank = text
            end
        end
        list[#list + 1] = skill
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.name < b.name
    end)
    return list
end

local function Known(skill)
    if not skill.spell then
        return false
    end
    return (IsPlayerSpell and IsPlayerSpell(skill.spell)) or (IsSpellKnown and IsSpellKnown(skill.spell)) or false
end

-- "Holy Light (Rank 2)"; other text under a skill, such as "Passive", is not shown.
local function SkillText(skill)
    local rank = skill.rank and skill.rank:match("^Rank %d+$")
    if skill.name:match("%s[IVX]+$") then
        rank = nil -- "Instant Poison III" says its rank already
    end
    return skill.name .. (rank and (" (" .. rank .. ")") or "")
end

-- The name shared by all ranks of a skill. Most keep one name, but poisons
-- add a numeral per rank, "Instant Poison II", "Instant Poison III"; those
-- count as ranks of "Instant Poison", for listing only the highest and for
-- ignoring them all.
local function BaseName(skill)
    return (skill.name:gsub("%s+[IVX]+$", ""))
end

-- The skills you can learn now, in list order, and the next level that has
-- any you cannot yet. Of each skill, only the highest rank you could learn;
-- the list is by level, so a later one replaces an earlier one of the same name.
local function Learnable(skills)
    local level = UnitLevel("player") or 0
    local byName, order, nextLevel = {}, {}, nil
    for _, skill in ipairs(skills) do
        if not Known(skill) then
            if skill.level <= level then
                local base = BaseName(skill)
                if not byName[base] then
                    order[#order + 1] = base
                end
                byName[base] = skill
            elseif not nextLevel or skill.level < nextLevel then
                nextLevel = skill.level
            end
        end
    end
    local list = {}
    for _, name in ipairs(order) do
        list[#list + 1] = byName[name]
    end
    return list, nextLevel
end

--------------------------------------------------------------------------------
-- Ignored skills: kept out of the tracker's Class Training, every rank
--------------------------------------------------------------------------------

-- The names ignored for your class: SinkDB.ignoredTraining[class][name] = true.
-- By name, so ignoring Holy Light ignores all its ranks.
local function IgnoredNames()
    local _, class = UnitClass("player")
    local all = ns.db and ns.db.ignoredTraining
    return all and class and all[class] or {}
end

-- Ignore a skill by name, or stop ignoring it; the tracker and the Ignored
-- tab follow.
function ns.SetTrainingIgnored(name, ignored)
    local _, class = UnitClass("player")
    if not (ns.db and class and name) then
        return
    end
    ns.db.ignoredTraining = ns.db.ignoredTraining or {}
    ns.db.ignoredTraining[class] = ns.db.ignoredTraining[class] or {}
    ns.db.ignoredTraining[class][name] = ignored or nil
    if ns.RefreshTracker then
        ns.RefreshTracker()
    end
    if ns.RefreshIgnoredList then
        ns.RefreshIgnoredList()
    end
end

-- The names ignored for your class, alphabetical.
function ns.IgnoredTraining()
    local names = {}
    for name in pairs(IgnoredNames()) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

-- The skills you can learn now that are not ignored.
local function ToLearn()
    local _, class = UnitClass("player")
    local ignored = IgnoredNames()
    local list = {}
    for _, skill in ipairs(Learnable(Skills(class))) do
        if not ignored[BaseName(skill)] then
            list[#list + 1] = skill
        end
    end
    return list
end

-- Your class's skills you can learn now, leaving out ignored ones, for the
-- Sink tracker: { name, text, spell }, text as the trainer tooltip lists it,
-- "Holy Light (Rank 2)". Empty while the class has no list here.
function ns.ClassTrainingToLearn()
    local list = {}
    for _, skill in ipairs(ToLearn()) do
        list[#list + 1] = { name = BaseName(skill), text = SkillText(skill), spell = skill.spell }
    end
    return list
end

-- What those skills cost together, in copper. A skill with no price adds
-- nothing. The Sink tracker shows it.
function ns.ClassTrainingCost()
    local total = 0
    for _, skill in ipairs(ToLearn()) do
        total = total + (skill.cost or 0)
    end
    return total
end

--------------------------------------------------------------------------------
-- Tooltip lines
--------------------------------------------------------------------------------

-- Lines for a trainer of class: the skills you can learn now, then the next
-- level's. Only for your own class. Returns true when lines were added.
local function AddClassTrainingLines(tooltip, class)
    local _, playerClass = UnitClass("player")
    if not class or class ~= playerClass then
        return false
    end
    local skills = Skills(class)
    if #skills == 0 then
        return false -- no list for this class in ns.classTraining yet
    end
    local learnable, nextLevel = Learnable(skills)
    for _, skill in ipairs(learnable) do
        tooltip:AddLine(CROSS .. " " .. SkillText(skill), ns.missing.r, ns.missing.g, ns.missing.b)
    end
    if nextLevel then
        tooltip:AddLine(" ")
        tooltip:AddLine(("Next Skills (Level %d)"):format(nextLevel), ns.accent.r, ns.accent.g, ns.accent.b)
        for _, skill in ipairs(skills) do
            if skill.level == nextLevel and not Known(skill) then
                tooltip:AddLine(SkillText(skill), 1, 1, 1)
            end
        end
    end
    return true
end
ns.AddClassTrainingLines = AddClassTrainingLines

-- Hovering a class trainer who has a map pin.
local function AddUnitTooltipLines(tooltip, data)
    if not tooltip or not tooltip.AddLine or (tooltip.IsForbidden and tooltip:IsForbidden()) then
        return
    end
    local guid = data and data.guid
    if not guid and tooltip.GetUnit then
        local _, unit = tooltip:GetUnit()
        guid = unit and UnitGUID(unit)
    end
    local npcID = ns.NPCIDFromGUID and ns.NPCIDFromGUID(guid)
    local class = npcID and ns.ClassTrainerClass and ns.ClassTrainerClass(npcID)
    if class then
        AddClassTrainingLines(tooltip, class)
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddUnitTooltipLines)
end

--------------------------------------------------------------------------------
-- The trainer window, for "/sink dump trainer"
--------------------------------------------------------------------------------

-- The spell a trainer service teaches, from its tooltip data, or nil.
-- Dump.lua puts it in the lines it prints for ns.classTraining.
local function ServiceSpell(index)
    if not (C_TooltipInfo and C_TooltipInfo.GetTrainerService) then
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetTrainerService, index)
    local id = ok and data and data.id
    if id and not ns.Secret(id) and type(id) == "number" and id > 0 then
        return id
    end
    return nil
end
ns.TrainerServiceSpell = ServiceSpell

--------------------------------------------------------------------------------
-- The list on the options window's Ignored tab
--------------------------------------------------------------------------------

local ignoredList -- { child, rows, empty }
local ROW_HEIGHT = 24

-- Builds the list at y on the page and returns the height it takes: a
-- scrolling frame filling the rest of the page, one row per ignored skill
-- with a button that brings it back.
function ns.BuildIgnoredList(page, y)
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -y)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(_, width)
        child:SetWidth(width)
    end)
    local empty = child:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 4, 0)
    empty:SetPoint("RIGHT", -4, 0)
    empty:SetJustifyH("LEFT")
    empty:SetText("Nothing ignored. Right-click a skill in the tracker's Class Training to ignore it.")
    ignoredList = { child = child, rows = {}, empty = empty }
    ns.RefreshIgnoredList()
    return 0 -- it fills the rest of the page
end

-- The nth row, made the first time it is needed.
local function IgnoredRow(n)
    local row = ignoredList.rows[n]
    if not row then
        row = CreateFrame("Frame", nil, ignoredList.child)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(n - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT")
        row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.button:SetSize(90, 22)
        row.button:SetPoint("RIGHT", -4, 0)
        row.button:SetText("Unignore")
        row.button:SetScript("OnClick", function(self)
            ns.SetTrainingIgnored(self:GetParent().name, false)
        end)
        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetPoint("RIGHT", row.button, "LEFT", -8, 0)
        row.text:SetJustifyH("LEFT")
        ignoredList.rows[n] = row
    end
    return row
end

function ns.RefreshIgnoredList()
    if not ignoredList or not ignoredList.child:IsVisible() then
        return
    end
    local names = ns.IgnoredTraining()
    for n, name in ipairs(names) do
        local row = IgnoredRow(n)
        row.name = name
        row.text:SetText(name)
        row:Show()
    end
    for n = #names + 1, #ignoredList.rows do
        ignoredList.rows[n]:Hide()
    end
    ignoredList.empty:SetShown(#names == 0)
    ignoredList.child:SetHeight(math.max(#names * ROW_HEIGHT, ignoredList.empty:GetStringHeight()) + 4)
end
