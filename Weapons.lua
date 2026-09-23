--------------------------------------------------------------------------------
-- Sink / Weapons.lua
--
-- Weapon skills: which ones your class can learn, which you have and how far
-- along they are, and which weapon master teaches the rest.
--
-- Three sources. Learned skills and ranks come from C_SkillInfo, the API
-- behind Forever's own Skills panel; a skill you know is a skill line with a
-- rank and a max rank, keyed by the same skill line IDs as vanilla. What a
-- weapon master teaches comes from the built-in table below and from the
-- trainer window itself: opening a weapon master records what it lists, the
-- way merchants record recipes. Which skills your class can learn has no API,
-- so it is a table of the vanilla proficiencies; the trainer window only lists
-- what your class can take, which confirms the table as you visit.
--
-- Shown on a weapon master's tooltip and map icon (green check for a skill you
-- know, red cross for one you can learn, plain grey for one your class cannot)
-- and by "/sink weapons", which lists what you can still learn and the city of
-- a master on your side who teaches it. Nothing is printed on its own.
--------------------------------------------------------------------------------

local _, ns = ...

-- Weapon skills. id is the skill line Forever's Skills panel tracks; spell is
-- the proficiency the trainer grants, a second sign that the skill is known.
-- The names are what the trainer window and the skill list call them; some go
-- by both the vanilla name and the later one, so both are matched. level is
-- the character level the trainer asks for, where known; the trainer window
-- records the others as you visit.
--
-- Fist weapons are the odd one. Weapon masters offer them, but on Forever
-- the rank is kept under the Unarmed skill every character has, so the
-- Skills page never lists them and the proficiency spell is the only sign a
-- character has trained them. Line 473 is vanilla's; here it only serves as
-- the table key.
ns.weaponSkills = {
    { id = 43,  spell = 201,   names = { "One-Handed Swords", "Swords" } },
    { id = 55,  spell = 202,   names = { "Two-Handed Swords" } },
    { id = 44,  spell = 196,   names = { "One-Handed Axes", "Axes" } },
    { id = 172, spell = 197,   names = { "Two-Handed Axes" } },
    { id = 54,  spell = 198,   names = { "One-Handed Maces", "Maces" } },
    { id = 160, spell = 199,   names = { "Two-Handed Maces" } },
    { id = 173, spell = 1180,  names = { "Daggers" } },
    { id = 473, spell = 15590, names = { "Fist Weapons" } },
    { id = 136, spell = 227,   names = { "Staves" } },
    { id = 229, spell = 200,   names = { "Polearms" }, level = 20 },
    { id = 45,  spell = 264,   names = { "Bows" } },
    { id = 46,  spell = 266,   names = { "Guns" } },
    { id = 226, spell = 5011,  names = { "Crossbows" } },
    { id = 176, spell = 2567,  names = { "Thrown", "Thrown Weapons" } },
    { id = 228, spell = 5009,  names = { "Wands" }, classTrainer = true }, -- class trainers teach wands, no weapon master does
}

-- Which weapon skills each class can learn, by skill line ID: the vanilla
-- proficiencies. A skill you turn out to know is shown whether or not it is
-- listed here, so a mistake shows up rather than hiding anything.
ns.classWeaponSkills = {
    WARRIOR = { 43, 55, 44, 172, 54, 160, 173, 473, 136, 229, 45, 46, 226, 176 },
    PALADIN = { 43, 55, 44, 172, 54, 160, 229 },
    HUNTER  = { 43, 55, 44, 172, 173, 473, 136, 229, 45, 46, 226, 176 },
    ROGUE   = { 43, 54, 173, 473, 45, 46, 226, 176 },
    PRIEST  = { 54, 173, 136, 228 },
    SHAMAN  = { 44, 172, 54, 160, 173, 473, 136 },
    MAGE    = { 43, 173, 136, 228 },
    WARLOCK = { 43, 173, 136, 228 },
    DRUID   = { 54, 160, 173, 473, 136, 229 },
}

-- Built-in weapon masters: npcID -> { name, location, skills = { skill line ID, ... } },
-- from Wowhead's Forever database and Warcraft Wiki; the Horde ones were
-- checked against what the masters say in game. Masters recorded from the
-- trainer window live in SinkDB.weaponMasters and are merged with these;
-- "/sink dump trainer" prints a line for this table.
ns.weaponMasters = {
    [11867] = { name = "Woo Ping", location = "Stormwind City", faction = "Alliance", skills = { 226, 173, 43, 55, 229, 136 } },
    [11865] = { name = "Buliwyf Stonehand", location = "Ironforge", faction = "Alliance", skills = { 46, 44, 172, 54, 160, 473 } },
    [13084] = { name = "Bixi Wobblebonk", location = "Ironforge", faction = "Alliance", skills = { 173, 226, 176 } },
    [11866] = { name = "Ilyenia Moonfire", location = "Darnassus", faction = "Alliance", skills = { 45, 173, 473, 136, 176 } },
    [2704]  = { name = "Hanashi", location = "Orgrimmar", faction = "Horde", skills = { 45, 44, 172, 136, 176 } },
    [11868] = { name = "Sayoc", location = "Orgrimmar", faction = "Horde", skills = { 45, 173, 473, 44, 172, 176 } },
    [11869] = { name = "Ansekhwa", location = "Thunder Bluff", faction = "Horde", skills = { 46, 54, 160, 136 } },
    [11870] = { name = "Archibald", location = "Undercity", faction = "Horde", skills = { 226, 173, 43, 55, 229 } },
}

local CHECK, CROSS = ns.CHECK, ns.CROSS

local skillByID, skillByName = {}, {}
for _, skill in ipairs(ns.weaponSkills) do
    skillByID[skill.id] = skill
    for _, name in ipairs(skill.names) do
        skillByName[name:lower()] = skill
    end
end

local function Enabled()
    return ns.db ~= nil and ns.db.weaponTooltips ~= false
end

-- Whether the character has the proficiency spell for a skill.
local function HasProficiency(skill)
    if not skill.spell then
        return false
    end
    return (IsPlayerSpell and IsPlayerSpell(skill.spell)) or (IsSpellKnown and IsSpellKnown(skill.spell)) or false
end

-- A table with at least the skill's name when the character knows it, else
-- nil. Three signals: the skill line by ID, the proficiency spell, and the
-- skill line by name among the lines the client lists.
local function Known(skill)
    if not C_SkillInfo then
        return HasProficiency(skill) and { name = skill.names[1] } or nil
    end
    if C_SkillInfo.GetSkillLineInfoByID then
        local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, skill.id)
        if ok and info and not info.isHeader and (info.maxRank or 0) > 0 then
            return info
        end
    end
    if HasProficiency(skill) then
        return { name = skill.names[1] }
    end
    if C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
        for index = 1, C_SkillInfo.GetNumSkillLines() do
            local info = C_SkillInfo.GetSkillLineInfo(index)
            if info and not info.isHeader and (info.maxRank or 0) > 0
                and info.name and skillByName[info.name:lower()] == skill then
                return info
            end
        end
    end
    return nil
end

-- The name shown everywhere: the one the trainer window uses, "One-Handed
-- Axes". The Skills page calls some of them differently, "Axes"; both are
-- matched, one is displayed.
local function SkillName(skill)
    return skill.names[1]
end

-- The level the skill needs: what a trainer window showed, else the table.
local function SkillLevel(skill)
    local seen = ns.db and ns.db.weaponLevels
    return (seen and seen[skill.id]) or skill.level or 0
end

-- "Polearms (20)" when the skill needs a level, else just the name.
local function NameWithLevel(skill)
    local level = SkillLevel(skill)
    return SkillName(skill) .. (level > 0 and (" (" .. level .. ")") or "")
end

-- Skill IDs the player's class can learn, as a set; nil when the class is not
-- in the table.
local function ClassSkillSet()
    local _, class = UnitClass("player")
    local list = class and ns.classWeaponSkills[class]
    if not list then
        return nil
    end
    local set = {}
    for _, id in ipairs(list) do
        set[id] = true
    end
    return set
end

local function ClassCanLearn(skill)
    local set = ClassSkillSet()
    return set == nil or set[skill.id] == true
end

-- Whether a master is on the player's side. Built-in masters carry a faction;
-- a recorded one was visited, so it counts.
local function Reachable(master)
    if not master.faction then
        return true
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return faction == nil or faction == master.faction
end

function ns.WeaponSkillID(name)
    local skill = name and skillByName[name:lower()]
    return skill and skill.id
end

--------------------------------------------------------------------------------
-- Weapon masters: built-in plus recorded
--------------------------------------------------------------------------------

local function CustomMasters()
    return ns.db and ns.db.weaponMasters or nil
end

-- Merged view of one master: { name, location, skills = { skill, ... } }.
local function MasterInfo(npcID)
    local builtin = ns.weaponMasters[npcID]
    local custom = CustomMasters()
    custom = custom and custom[npcID]
    if not builtin and not custom then
        return nil
    end
    local info = {
        name = (builtin and builtin.name) or (custom and custom.name) or ("NPC #" .. npcID),
        location = builtin and builtin.location,
        faction = builtin and builtin.faction,
        skills = {},
    }
    local seen = {}
    local function add(ids)
        for _, id in ipairs(ids or {}) do
            local skill = skillByID[id]
            if skill and not seen[id] then
                seen[id] = true
                info.skills[#info.skills + 1] = skill
            end
        end
    end
    add(builtin and builtin.skills)
    add(custom and custom.skills)
    return info
end

-- Calls fn(npcID, info) for every master, lowest NPC ID first.
local function EachMaster(fn)
    local ids, seen = {}, {}
    for npcID in pairs(ns.weaponMasters) do
        seen[npcID] = true
        ids[#ids + 1] = npcID
    end
    for npcID in pairs(CustomMasters() or {}) do
        if not seen[npcID] then
            ids[#ids + 1] = npcID
        end
    end
    table.sort(ids)
    for _, npcID in ipairs(ids) do
        fn(npcID, MasterInfo(npcID))
    end
end

-- Cities with a master on your side who teaches the skill, each once.
local function CitiesTeaching(skill)
    local cities, seen = {}, {}
    EachMaster(function(_, master)
        if Reachable(master) then
            local city = master.location or master.name
            for _, taught in ipairs(master.skills) do
                if taught == skill and not seen[city] then
                    seen[city] = true
                    cities[#cities + 1] = city
                end
            end
        end
    end)
    return cities
end

--------------------------------------------------------------------------------
-- Display order and tooltip lines
--------------------------------------------------------------------------------

local MISSING, KNOWN, OTHER = 1, 2, 3

-- Rows for a set of skills in display order: the ones you can still learn
-- first, by level and then name; then the ones you know; then the ones your
-- class cannot take. Each group is alphabetical.
local function SortedRows(skills)
    local rows = {}
    for _, skill in ipairs(skills) do
        local info = Known(skill)
        local group = (info and KNOWN) or (ClassCanLearn(skill) and MISSING) or OTHER
        rows[#rows + 1] = {
            skill = skill,
            group = group,
            level = group == MISSING and SkillLevel(skill) or 0,
            name = SkillName(skill),
        }
    end
    table.sort(rows, function(a, b)
        if a.group ~= b.group then
            return a.group < b.group
        end
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.name < b.name
    end)
    return rows
end

-- One line per skill the master teaches, on any tooltip, in display order:
-- red cross for one your class can learn, green check for one you know, plain
-- grey for one it cannot. The map icons in MapPins.lua use it too. Returns
-- true when lines were added.
local function AddMasterLines(tooltip, npcID)
    if not Enabled() then
        return false
    end
    local master = npcID and MasterInfo(npcID)
    if not master or #master.skills == 0 then
        return false
    end
    for _, row in ipairs(SortedRows(master.skills)) do
        if row.group == MISSING then
            tooltip:AddLine(CROSS .. " " .. NameWithLevel(row.skill), ns.missing.r, ns.missing.g, ns.missing.b)
        elseif row.group == KNOWN then
            tooltip:AddLine(CHECK .. " " .. row.name, ns.known.r, ns.known.g, ns.known.b)
        else
            tooltip:AddLine(row.name, ns.grey.r, ns.grey.g, ns.grey.b)
        end
    end
    return true
end
ns.AddWeaponMasterLines = AddMasterLines

-- Hovering a weapon master.
local function AddUnitTooltipLines(tooltip, data)
    if not tooltip or not tooltip.AddLine or (tooltip.IsForbidden and tooltip:IsForbidden()) then
        return
    end
    local guid = data and data.guid
    if not guid and tooltip.GetUnit then
        local _, unit = tooltip:GetUnit()
        guid = unit and UnitGUID(unit)
    end
    AddMasterLines(tooltip, ns.NPCIDFromGUID and ns.NPCIDFromGUID(guid))
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddUnitTooltipLines)
end

--------------------------------------------------------------------------------
-- The trainer window: remember what a master teaches
--------------------------------------------------------------------------------

-- Weapon skills the open trainer window lists: { skill, name, type, level },
-- the type being "available", "unavailable" or "used" as the window shows it.
-- The window only lists what your class can take, and its own filter boxes
-- narrow that further.
local function TrainerWeaponSkills()
    local rows = {}
    local count = GetNumTrainerServices and GetNumTrainerServices() or 0
    for index = 1, count do
        local name, serviceType, _, reqLevel = GetTrainerServiceInfo(index)
        local skill = name and skillByName[name:lower()]
        if skill and serviceType ~= "header" then
            rows[#rows + 1] = { skill = skill, name = name, type = serviceType, level = tonumber(reqLevel) or 0 }
        end
    end
    return rows
end

-- Save the level each listed skill needs.
local function RememberLevels(rows)
    ns.db.weaponLevels = ns.db.weaponLevels or {}
    for _, row in ipairs(rows) do
        if row.level > 0 then
            ns.db.weaponLevels[row.skill.id] = row.level
        end
    end
end

-- Save what this master teaches so it shows in tooltips and lists.
local function RememberMaster(npcID, name, rows)
    ns.db.weaponMasters = ns.db.weaponMasters or {}
    local entry = ns.db.weaponMasters[npcID] or {}
    entry.name = entry.name or name
    entry.skills = entry.skills or {}

    local seen = {}
    for _, id in ipairs(entry.skills) do
        seen[id] = true
    end
    local builtin = ns.weaponMasters[npcID]
    for _, id in ipairs(builtin and builtin.skills or {}) do
        seen[id] = true -- the built-in entry already lists it
    end

    for _, row in ipairs(rows) do
        if not seen[row.skill.id] then
            seen[row.skill.id] = true
            entry.skills[#entry.skills + 1] = row.skill.id
        end
    end
    if #entry.skills > 0 then
        ns.db.weaponMasters[npcID] = entry
    end
end

local function OnTrainerShow()
    if not ns.db then
        return
    end
    local rows = TrainerWeaponSkills()
    if #rows == 0 then
        return -- a class or profession trainer
    end

    RememberLevels(rows)
    local npcID = ns.NPCIDFromGUID and ns.NPCIDFromGUID(UnitGUID and UnitGUID("npc"))
    if npcID then
        RememberMaster(npcID, UnitName and UnitName("npc") or nil, rows)
    end
end

--------------------------------------------------------------------------------
-- /sink weapons ...
--------------------------------------------------------------------------------

local function WeaponsHelp()
    ns.Print("weapon skill commands")
    print("  /sink weapons           weapon skills you can still learn, and the city that teaches each")
    print("  /sink weapons masters   the weapon masters on your side and what they teach")
    print("  /sink weapons on | off  turn the tooltip lines on or off")
end

-- The skills your class can still learn, by level then name, each with where
-- to get it.
local function ListSkills()
    local set = ClassSkillSet()
    local lines = {}
    for _, row in ipairs(SortedRows(ns.weaponSkills)) do
        local skill = row.skill
        if row.group == MISSING then
            local where
            if skill.classTrainer then
                where = "class trainer"
            else
                local cities = CitiesTeaching(skill)
                where = #cities > 0 and table.concat(cities, ", ") or "no weapon master on your side listed"
            end
            local level = SkillLevel(skill)
            if level > 0 then
                where = level .. ", " .. where
            end
            lines[#lines + 1] = ("  %s %s%s|r (%s)"):format(CROSS, ns.missing.hex, SkillName(skill), where)
        end
    end
    if #lines == 0 then
        ns.Print("nothing to learn: you know every weapon skill your class can.")
        return
    end
    ns.Print("weapon skills to learn" .. (set == nil and " (class not in the table, showing every skill)" or ""))
    for _, line in ipairs(lines) do
        print(line)
    end
end

local function ListMasters()
    local any = false
    EachMaster(function(npcID, master)
        if not Reachable(master) then
            return
        end
        any = true
        print(("  %s (%d)%s"):format(master.name, npcID, master.location and (", " .. master.location) or ""))
        for _, row in ipairs(SortedRows(master.skills)) do
            if row.group == MISSING then
                print(("    %s %s%s|r"):format(CROSS, ns.missing.hex, NameWithLevel(row.skill)))
            elseif row.group == KNOWN then
                print(("    %s %s%s|r"):format(CHECK, ns.known.hex, row.name))
            else
                print("    " .. ns.grey.hex .. row.name .. "|r")
            end
        end
    end)
    if not any then
        ns.Print("no weapon masters on your side listed. Open one's window and it is recorded.")
    end
end

function ns.WeaponsCommand(arg)
    if not ns.db then
        return
    end
    local sub = (arg or ""):match("^(%S*)"):lower()

    if sub == "" or sub == "list" or sub == "status" then
        ListSkills()
    elseif sub == "masters" or sub == "master" then
        ListMasters()
    elseif sub == "on" or sub == "off" then
        ns.db.weaponTooltips = (sub == "on")
        ns.Print("weapon skill tooltips " .. (sub == "on" and "|cff00ff00on|r" or "|cffff0000off|r") .. ".")
    else
        WeaponsHelp()
    end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("TRAINER_SHOW")
frame:RegisterEvent("TRAINER_UPDATE")
frame:SetScript("OnEvent", function(_, event)
    if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        OnTrainerShow()
    end
end)
