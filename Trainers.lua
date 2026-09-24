--------------------------------------------------------------------------------
-- Sink / Trainers.lua
--
-- Class skills: what your class trainer teaches, which of it you can learn
-- now, and what comes next. Hover your class's trainer, or their map icon,
-- and the tooltip lists each skill you have not learned and can learn now
-- (red cross), then a blank line and "Next Skills (level N)" with the skills
-- at the next level that has any, in grey.
--
-- What a trainer teaches has no API outside the trainer window, so opening
-- one records it: each service's name, level and spell ID. The spell ID comes
-- from the service's tooltip data (C_TooltipInfo.GetTrainerService), and with
-- it IsPlayerSpell says whether you know the skill at any time; without one,
-- the state the window showed ("used" is known) is kept. A skill's rank is
-- the game's own, "Holy Light (Rank 2)": the text the window shows under the
-- service, or the spell's subtext. Of several ranks you could learn, only
-- the highest is listed.
-- Built-in lists live in ns.classSkills below, "/sink dump trainer" prints
-- the lines for them; recorded ones are in SinkDB.classSkills.
--------------------------------------------------------------------------------

local _, ns = ...

-- Built-in class skill lists, by class token: { { name, level, spell, rank }, ... }.
ns.classSkills = {}

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
        if entry.rank and entry.rank ~= "" then
            skill.rank = entry.rank
        end
        if entry.known ~= nil then
            skill.known = entry.known
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

local function SkillText(skill)
    return skill.name .. (skill.rank and (" (" .. skill.rank .. ")") or "")
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
    local level = UnitLevel("player") or 0
    -- Of each skill you could learn now, the highest rank; the list is by
    -- level, so a later one replaces an earlier one of the same name.
    local learnable, order, nextLevel = {}, {}, nil
    for _, skill in ipairs(skills) do
        if not Known(skill) then
            if skill.level <= level then
                if not learnable[skill.name] then
                    order[#order + 1] = skill.name
                end
                learnable[skill.name] = skill
            elseif not nextLevel or skill.level < nextLevel then
                nextLevel = skill.level
            end
        end
    end
    for _, name in ipairs(order) do
        tooltip:AddLine(CROSS .. " " .. SkillText(learnable[name]), ns.missing.r, ns.missing.g, ns.missing.b)
    end
    if nextLevel then
        tooltip:AddLine(" ")
        tooltip:AddLine(("Next Skills (Level %d)"):format(nextLevel), ns.accent.r, ns.accent.g, ns.accent.b)
        for _, skill in ipairs(skills) do
            if skill.level == nextLevel and not Known(skill) then
                tooltip:AddLine(SkillText(skill), ns.grey.r, ns.grey.g, ns.grey.b)
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
            rows[#rows + 1] = { name = name, level = tonumber(reqLevel) or 0, spell = ServiceSpell(index),
                rank = subText, known = serviceType == "used" }
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
