--------------------------------------------------------------------------------
-- Sink / Trainers.lua
--
-- Class skills: what your class trainer teaches, which of it you can learn
-- now, and what comes next. Hover your class's trainer, or their map icon,
-- and the tooltip lists each skill you have not learned and can learn now
-- (red cross), then a blank line and "Next Skills (Level N)" with the skills
-- at the next level that has any, in white.
--
-- What a trainer teaches has no API outside the trainer window, so it is
-- built into the addon: ns.classSkills below, one list per class, pasted from
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
ns.classSkills = {}

ns.classSkills.PALADIN = {
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

ns.classSkills.WARLOCK = {
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

local CROSS = ns.CROSS

--------------------------------------------------------------------------------
-- The skill list for a class
--------------------------------------------------------------------------------

-- { { name, level, spell, rank, cost }, ... } sorted by level, then name:
-- copies of the class's list, so filling in a rank leaves the list alone.
local function Skills(class)
    local list = {}
    for _, entry in ipairs(ns.classSkills[class] or {}) do
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
    return skill.name .. (rank and (" (" .. rank .. ")") or "")
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
                if not byName[skill.name] then
                    order[#order + 1] = skill.name
                end
                byName[skill.name] = skill
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

-- Your class's skills you can learn now, as the trainer tooltip lists them:
-- "Holy Light (Rank 2)". The Sink tracker shows them. Empty until the class
-- has a built-in list or its trainer's window has been opened once.
function ns.ClassSkillsToLearn()
    local _, class = UnitClass("player")
    local list = {}
    for _, skill in ipairs(Learnable(Skills(class))) do
        list[#list + 1] = SkillText(skill)
    end
    return list
end

-- What the skills you can learn now cost together, in copper. A skill with
-- no price, in neither the built-in list nor a trainer window, adds nothing.
-- The Sink tracker shows it.
function ns.ClassTrainingCost()
    local _, class = UnitClass("player")
    local total = 0
    for _, skill in ipairs(Learnable(Skills(class))) do
        total = total + (skill.cost or 0)
    end
    return total
end

--------------------------------------------------------------------------------
-- Tooltip lines
--------------------------------------------------------------------------------

-- Lines for a trainer of class: the skills you can learn now, then the next
-- level's. Only for your own class. Returns true when lines were added.
local function AddClassSkillLines(tooltip, class)
    local _, playerClass = UnitClass("player")
    if not class or class ~= playerClass then
        return false
    end
    local skills = Skills(class)
    if #skills == 0 then
        return false -- no list for this class in ns.classSkills yet
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
ns.AddClassSkillLines = AddClassSkillLines

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
        AddClassSkillLines(tooltip, class)
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddUnitTooltipLines)
end

--------------------------------------------------------------------------------
-- The trainer window, for "/sink dump trainer"
--------------------------------------------------------------------------------

-- The spell a trainer service teaches, from its tooltip data, or nil.
-- Dump.lua puts it in the lines it prints for ns.classSkills.
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
