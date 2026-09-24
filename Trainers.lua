--------------------------------------------------------------------------------
-- Sink / Trainers.lua
--
-- Class skills: what your class trainer teaches, which of it you can learn
-- now, and what comes next. Hover your class's trainer, or their map icon,
-- and the tooltip lists each skill you have not learned and can learn now
-- (red cross), then a blank line and "Next Skills (Level N)" with the skills
-- at the next level that has any, in white.
--
-- What a trainer teaches has no API outside the trainer window, so opening
-- one records it: each service's name, level and spell ID. The spell ID comes
-- from the service's tooltip data (C_TooltipInfo.GetTrainerService), and with
-- it IsPlayerSpell says whether you know the skill at any time; without one,
-- the state the window showed ("used" is known) is kept. A skill's rank,
-- "Holy Light (Rank 2)", is the text the trainer shows under it, built into
-- the list below; only a recorded skill without one asks the spell for its
-- subtext. Of several ranks you could learn, only the highest is listed.
-- The window also gives each service's cost in copper, recorded as cost, so
-- the tracker can total what the skills you can learn now will cost.
-- Built-in lists live in ns.classSkills below, "/sink dump trainer" prints
-- the lines for them; recorded ones are in SinkDB.classSkills.
--------------------------------------------------------------------------------

local _, ns = ...

-- Built-in class skill lists, by class token: { { name, level, spell, rank, cost }, ... },
-- from "/sink dump trainer"; cost is in copper and may be missing. Level 0 is what the class starts with. rank is
-- the trainer's text for it, "" for none; only "Rank N" is shown. A recorded
-- skill without a rank gets the spell's subtext.
ns.classSkills = {}

ns.classSkills.PALADIN = { -- Garen Largo, Undercity
    { name = "Blessing of Might", level = 0, spell = 19740, rank = "Rank 1" },
    { name = "Devotion Aura", level = 0, spell = 465, rank = "Rank 1" },
    { name = "Divine Protection", level = 0, spell = 498, rank = "Rank 1" },
    { name = "Holy Strike", level = 0, spell = 679, rank = "Rank 1" },
    { name = "Seal of the Crusader", level = 0, spell = 21082, rank = "Rank 1" },
    { name = "Judgement", level = 4, spell = 20271, rank = "" },
    { name = "Holy Light", level = 6, spell = 639, rank = "Rank 2" },
    { name = "Hammer of Justice", level = 8, spell = 853, rank = "Rank 1" },
    { name = "Parry", level = 8, spell = 3127, rank = "Passive" },
    { name = "Purify", level = 8, spell = 1152, rank = "" },
    { name = "Blessing of Protection", level = 10, spell = 1022, rank = "Rank 1" },
    { name = "Devotion Aura", level = 10, spell = 10290, rank = "Rank 2" },
    { name = "Lay on Hands", level = 10, spell = 633, rank = "Rank 1" },
    { name = "Seal of Fury", level = 10, spell = 1311649, rank = "Rank 1" },
    { name = "Seal of Righteousness", level = 10, spell = 20287, rank = "Rank 2" },
    { name = "Blessing of Might", level = 12, spell = 19834, rank = "Rank 2" },
    { name = "Holy Strike", level = 12, spell = 678, rank = "Rank 2" },
    { name = "Seal of the Crusader", level = 12, spell = 20162, rank = "Rank 2" },
    { name = "Blessing of Wisdom", level = 14, spell = 19742, rank = "Rank 1" },
    { name = "Holy Light", level = 14, spell = 647, rank = "Rank 3" },
    { name = "Retribution Aura", level = 16, spell = 7294, rank = "Rank 1" },
    { name = "Righteous Fury", level = 16, spell = 25780, rank = "" },
    { name = "Blessing of Freedom", level = 18, spell = 1044, rank = "" },
    { name = "Divine Protection", level = 18, spell = 5573, rank = "Rank 2" },
    { name = "Seal of Fury", level = 18, spell = 1311656, rank = "Rank 2" },
    { name = "Seal of Righteousness", level = 18, spell = 20288, rank = "Rank 3" },
    { name = "Blessing of Kings", level = 20, spell = 20217, rank = "" },
    { name = "Consecration", level = 20, spell = 26573, rank = "Rank 1" },
    { name = "Devotion Aura", level = 20, spell = 643, rank = "Rank 3" },
    { name = "Exorcism", level = 20, spell = 879, rank = "Rank 1" },
    { name = "Flash of Light", level = 20, spell = 19750, rank = "Rank 1" },
    { name = "Holy Strike", level = 20, spell = 1866, rank = "Rank 3" },
    { name = "Blessing of Might", level = 22, spell = 19835, rank = "Rank 3" },
    { name = "Concentration Aura", level = 22, spell = 19746, rank = "" },
    { name = "Holy Light", level = 22, spell = 1026, rank = "Rank 4" },
    { name = "Seal of Justice", level = 22, spell = 20164, rank = "" },
    { name = "Seal of the Crusader", level = 22, spell = 20305, rank = "Rank 3" },
    { name = "Blessing of Protection", level = 24, spell = 5599, rank = "Rank 2" },
    { name = "Blessing of Wisdom", level = 24, spell = 19850, rank = "Rank 2" },
    { name = "Hammer of Justice", level = 24, spell = 5588, rank = "Rank 2" },
    { name = "Redemption", level = 24, spell = 10322, rank = "Rank 2" },
    { name = "Turn Undead", level = 24, spell = 2878, rank = "Rank 1" },
    { name = "Seal of Fury", level = 25, spell = 20163, rank = "Rank 3" },
    { name = "Blessing of Salvation", level = 26, spell = 1038, rank = "" },
    { name = "Flash of Light", level = 26, spell = 19939, rank = "Rank 2" },
    { name = "Retribution Aura", level = 26, spell = 10298, rank = "Rank 2" },
    { name = "Seal of Righteousness", level = 26, spell = 20289, rank = "Rank 4" },
    { name = "Exorcism", level = 28, spell = 5614, rank = "Rank 2" },
    { name = "Holy Strike", level = 28, spell = 680, rank = "Rank 4" },
    { name = "Shadow Resistance Aura", level = 28, spell = 19876, rank = "Rank 1" },
    { name = "Consecration", level = 30, spell = 20116, rank = "Rank 2" },
    { name = "Devotion Aura", level = 30, spell = 10291, rank = "Rank 4" },
    { name = "Divine Intervention", level = 30, spell = 19752, rank = "" },
    { name = "Holy Light", level = 30, spell = 1042, rank = "Rank 5" },
    { name = "Lay on Hands", level = 30, spell = 2800, rank = "Rank 2" },
    { name = "Seal of Command", level = 30, spell = 20915, rank = "Rank 2" },
    { name = "Seal of Light", level = 30, spell = 20165, rank = "Rank 1" },
    { name = "Blessing of Might", level = 32, spell = 19836, rank = "Rank 4" },
    { name = "Frost Resistance Aura", level = 32, spell = 19888, rank = "Rank 1" },
    { name = "Seal of the Crusader", level = 32, spell = 20306, rank = "Rank 4" },
    { name = "Blessing of Wisdom", level = 34, spell = 19852, rank = "Rank 3" },
    { name = "Divine Shield", level = 34, spell = 642, rank = "Rank 1" },
    { name = "Flash of Light", level = 34, spell = 19940, rank = "Rank 3" },
    { name = "Seal of Fury", level = 34, spell = 20419, rank = "Rank 4" },
    { name = "Seal of Righteousness", level = 34, spell = 20290, rank = "Rank 5" },
    { name = "Exorcism", level = 36, spell = 5615, rank = "Rank 3" },
    { name = "Fire Resistance Aura", level = 36, spell = 19891, rank = "Rank 1" },
    { name = "Holy Strike", level = 36, spell = 2495, rank = "Rank 5" },
    { name = "Redemption", level = 36, spell = 10324, rank = "Rank 3" },
    { name = "Retribution Aura", level = 36, spell = 10299, rank = "Rank 3" },
    { name = "Blessing of Protection", level = 38, spell = 10278, rank = "Rank 3" },
    { name = "Holy Light", level = 38, spell = 3472, rank = "Rank 6" },
    { name = "Seal of Wisdom", level = 38, spell = 20166, rank = "Rank 1" },
    { name = "Turn Undead", level = 38, spell = 5627, rank = "Rank 2" },
    { name = "Blessing of Light", level = 40, spell = 19977, rank = "Rank 1" },
    { name = "Consecration", level = 40, spell = 20922, rank = "Rank 3" },
    { name = "Devotion Aura", level = 40, spell = 1032, rank = "Rank 5" },
    { name = "Hammer of Justice", level = 40, spell = 5589, rank = "Rank 3" },
    { name = "Holy Shock", level = 40, spell = 20473, rank = "Rank 2" },
    { name = "Plate Mail", level = 40, spell = 750, rank = "" },
    { name = "Seal of Command", level = 40, spell = 20918, rank = "Rank 3" },
    { name = "Seal of Light", level = 40, spell = 20347, rank = "Rank 2" },
    { name = "Shadow Resistance Aura", level = 40, spell = 19895, rank = "Rank 2" },
    { name = "Blessing of Might", level = 42, spell = 19837, rank = "Rank 5" },
    { name = "Cleanse", level = 42, spell = 4987, rank = "" },
    { name = "Flash of Light", level = 42, spell = 19941, rank = "Rank 4" },
    { name = "Seal of Fury", level = 42, spell = 20421, rank = "Rank 5" },
    { name = "Seal of Righteousness", level = 42, spell = 20291, rank = "Rank 6" },
    { name = "Seal of the Crusader", level = 42, spell = 20307, rank = "Rank 5" },
    { name = "Blessing of Wisdom", level = 44, spell = 19853, rank = "Rank 4" },
    { name = "Exorcism", level = 44, spell = 10312, rank = "Rank 4" },
    { name = "Frost Resistance Aura", level = 44, spell = 19897, rank = "Rank 2" },
    { name = "Hammer of Wrath", level = 44, spell = 24275, rank = "Rank 1" },
    { name = "Holy Strike", level = 44, spell = 5569, rank = "Rank 6" },
    { name = "Blessing of Sacrifice", level = 46, spell = 6940, rank = "Rank 1" },
    { name = "Holy Light", level = 46, spell = 10328, rank = "Rank 7" },
    { name = "Retribution Aura", level = 46, spell = 10300, rank = "Rank 4" },
    { name = "Fire Resistance Aura", level = 48, spell = 19899, rank = "Rank 2" },
    { name = "Holy Shock", level = 48, spell = 20929, rank = "Rank 3" },
    { name = "Redemption", level = 48, spell = 20772, rank = "Rank 4" },
    { name = "Seal of Wisdom", level = 48, spell = 20356, rank = "Rank 2" },
    { name = "Blessing of Light", level = 50, spell = 19978, rank = "Rank 2" },
    { name = "Consecration", level = 50, spell = 20923, rank = "Rank 4" },
    { name = "Devotion Aura", level = 50, spell = 10292, rank = "Rank 6" },
    { name = "Divine Shield", level = 50, spell = 1020, rank = "Rank 2" },
    { name = "Flash of Light", level = 50, spell = 19942, rank = "Rank 5" },
    { name = "Holy Shield", level = 50, spell = 20927, rank = "Rank 2" },
    { name = "Holy Wrath", level = 50, spell = 2812, rank = "Rank 1" },
    { name = "Lay on Hands", level = 50, spell = 10310, rank = "Rank 3" },
    { name = "Light's Vigil", level = 50, spell = 1311590, rank = "Rank 2" },
    { name = "Seal of Command", level = 50, spell = 20919, rank = "Rank 4" },
    { name = "Seal of Fury", level = 50, spell = 20422, rank = "Rank 6" },
    { name = "Seal of Light", level = 50, spell = 20348, rank = "Rank 3" },
    { name = "Seal of Righteousness", level = 50, spell = 20292, rank = "Rank 7" },
    { name = "Blessing of Might", level = 52, spell = 19838, rank = "Rank 6" },
    { name = "Exorcism", level = 52, spell = 10313, rank = "Rank 5" },
    { name = "Greater Blessing of Might", level = 52, spell = 25782, rank = "Rank 1" },
    { name = "Hammer of Wrath", level = 52, spell = 24274, rank = "Rank 2" },
    { name = "Holy Strike", level = 52, spell = 10332, rank = "Rank 7" },
    { name = "Seal of the Crusader", level = 52, spell = 20308, rank = "Rank 6" },
    { name = "Shadow Resistance Aura", level = 52, spell = 19896, rank = "Rank 3" },
    { name = "Turn Undead", level = 52, spell = 10326, rank = "Rank 3" },
    { name = "Blessing of Sacrifice", level = 54, spell = 20729, rank = "Rank 2" },
    { name = "Blessing of Wisdom", level = 54, spell = 19854, rank = "Rank 5" },
    { name = "Greater Blessing of Wisdom", level = 54, spell = 25894, rank = "Rank 1" },
    { name = "Hammer of Justice", level = 54, spell = 10308, rank = "Rank 4" },
    { name = "Holy Light", level = 54, spell = 10329, rank = "Rank 8" },
    { name = "Frost Resistance Aura", level = 56, spell = 19898, rank = "Rank 3" },
    { name = "Holy Shock", level = 56, spell = 20930, rank = "Rank 4" },
    { name = "Retribution Aura", level = 56, spell = 10301, rank = "Rank 5" },
    { name = "Flash of Light", level = 58, spell = 19943, rank = "Rank 6" },
    { name = "Seal of Fury", level = 58, spell = 20423, rank = "Rank 7" },
    { name = "Seal of Righteousness", level = 58, spell = 20293, rank = "Rank 8" },
    { name = "Seal of Wisdom", level = 58, spell = 20357, rank = "Rank 3" },
    { name = "Blessing of Light", level = 60, spell = 19979, rank = "Rank 3" },
    { name = "Consecration", level = 60, spell = 20924, rank = "Rank 5" },
    { name = "Devotion Aura", level = 60, spell = 10293, rank = "Rank 7" },
    { name = "Exorcism", level = 60, spell = 10314, rank = "Rank 6" },
    { name = "Fire Resistance Aura", level = 60, spell = 19900, rank = "Rank 3" },
    { name = "Greater Blessing of Kings", level = 60, spell = 25898, rank = "" },
    { name = "Greater Blessing of Light", level = 60, spell = 25890, rank = "Rank 1" },
    { name = "Greater Blessing of Might", level = 60, spell = 25916, rank = "Rank 2" },
    { name = "Greater Blessing of Salvation", level = 60, spell = 25895, rank = "" },
    { name = "Greater Blessing of Wisdom", level = 60, spell = 25918, rank = "Rank 2" },
    { name = "Hammer of Wrath", level = 60, spell = 24239, rank = "Rank 3" },
    { name = "Holy Shield", level = 60, spell = 20928, rank = "Rank 3" },
    { name = "Holy Strike", level = 60, spell = 10333, rank = "Rank 8" },
    { name = "Holy Wrath", level = 60, spell = 10318, rank = "Rank 2" },
    { name = "Light's Vigil", level = 60, spell = 1311595, rank = "Rank 3" },
    { name = "Redemption", level = 60, spell = 20773, rank = "Rank 5" },
    { name = "Seal of Command", level = 60, spell = 20920, rank = "Rank 5" },
    { name = "Seal of Light", level = 60, spell = 20349, rank = "Rank 4" },
}

local CROSS = ns.CROSS

--------------------------------------------------------------------------------
-- The skill list for a class: built-in merged with what the window recorded
--------------------------------------------------------------------------------

local function Key(name, level)
    return name .. ":" .. level
end

-- { { name, level, spell, rank, known }, ... } sorted by level, then name.
local function Skills(class)
    local merged, list = {}, {}
    local function add(entry)
        local key = Key(entry.name, entry.level)
        local skill = merged[key]
        if not skill then
            skill = { name = entry.name, level = entry.level }
            merged[key] = skill
            list[#list + 1] = skill
        end
        skill.spell = skill.spell or entry.spell
        if entry.rank ~= nil then
            skill.rank = entry.rank
        end
        if entry.known ~= nil then
            skill.known = entry.known
        end
        if entry.cost then
            skill.cost = entry.cost -- recorded after built-in, so the window's price wins
        end
    end
    for _, entry in ipairs(ns.classSkills[class] or {}) do
        add(entry)
    end
    local recorded = ns.db and ns.db.classSkills and ns.db.classSkills[class]
    for _, entry in pairs(recorded or {}) do
        add(entry)
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.name < b.name
    end)
    -- The rank text, from the spell when the window gave none.
    for _, skill in ipairs(list) do
        if not skill.rank and skill.spell and C_Spell and C_Spell.GetSpellSubtext then
            local text = C_Spell.GetSpellSubtext(skill.spell)
            if text and text ~= "" then
                skill.rank = text
            end
        end
    end
    return list
end

local function Known(skill)
    if skill.spell then
        if (IsPlayerSpell and IsPlayerSpell(skill.spell)) or (IsSpellKnown and IsSpellKnown(skill.spell)) then
            return true
        end
        if IsPlayerSpell or IsSpellKnown then
            return false
        end
    end
    return skill.known == true
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

-- What the skills you can learn now cost together, in copper, and how many
-- of them have no price yet (not in the built-in list with one, and the
-- trainer's window not opened since). The Sink tracker shows it.
function ns.ClassTrainingCost()
    local _, class = UnitClass("player")
    local total, unpriced = 0, 0
    for _, skill in ipairs(Learnable(Skills(class))) do
        if skill.cost then
            total = total + skill.cost
        else
            unpriced = unpriced + 1
        end
    end
    return total, unpriced
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
        tooltip:AddLine("Open this trainer's window once to list the skills.", ns.grey.r, ns.grey.g, ns.grey.b, true)
        return true
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
-- The trainer window: record what a class trainer teaches
--------------------------------------------------------------------------------

-- The spell a trainer service teaches, from its tooltip data, or nil.
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

-- The class skills the open window lists: { name, level, spell, rank, known },
-- rank being the text the window shows under the name, "Rank 2".
-- Nothing for a profession trainer or a weapon master.
local function WindowSkills()
    if IsTradeskillTrainer and IsTradeskillTrainer() then
        return {}
    end
    local rows = {}
    local count = GetNumTrainerServices and GetNumTrainerServices() or 0
    for index = 1, count do
        local name, serviceType, _, reqLevel, subText = GetTrainerServiceInfo(index)
        if name and serviceType ~= "header" and not (ns.WeaponSkillID and ns.WeaponSkillID(name)) then
            local cost = GetTrainerServiceCost and GetTrainerServiceCost(index)
            rows[#rows + 1] = { name = name, level = tonumber(reqLevel) or 0, spell = ServiceSpell(index),
                rank = subText, known = serviceType == "used", cost = tonumber(cost) }
        end
    end
    return rows
end

local function OnTrainerShow()
    if not ns.db then
        return
    end
    local rows = WindowSkills()
    if #rows == 0 then
        return
    end
    local _, class = UnitClass("player")
    ns.db.classSkills = ns.db.classSkills or {}
    local store = ns.db.classSkills[class] or {}
    ns.db.classSkills[class] = store
    for _, row in ipairs(rows) do
        store[Key(row.name, row.level)] = row
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("TRAINER_SHOW")
frame:RegisterEvent("TRAINER_UPDATE")
frame:SetScript("OnEvent", function()
    OnTrainerShow()
end)
