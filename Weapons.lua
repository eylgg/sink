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
-- Shown on a weapon master's tooltip and map icon (a check with your rank, a
-- cross for a skill you can learn, grey for one your class cannot), in chat
-- when you open a weapon master who has something for you, and by
-- "/sink weapons".
--------------------------------------------------------------------------------

local _, ns = ...

-- Weapon skill lines, by the skill line IDs Forever's Skills panel tracks. The
-- names are what the trainer window and the skill list call them; some go by
-- both the vanilla name and the later one, so both are matched.
ns.weaponSkills = {
    { id = 43,  names = { "One-Handed Swords", "Swords" } },
    { id = 55,  names = { "Two-Handed Swords" } },
    { id = 44,  names = { "One-Handed Axes", "Axes" } },
    { id = 172, names = { "Two-Handed Axes" } },
    { id = 54,  names = { "One-Handed Maces", "Maces" } },
    { id = 160, names = { "Two-Handed Maces" } },
    { id = 173, names = { "Daggers" } },
    { id = 162, names = { "Fist Weapons", "Unarmed" } }, -- Forever folds fist weapons into the unarmed line
    { id = 136, names = { "Staves" } },
    { id = 229, names = { "Polearms" } },
    { id = 45,  names = { "Bows" } },
    { id = 46,  names = { "Guns" } },
    { id = 226, names = { "Crossbows" } },
    { id = 176, names = { "Thrown", "Thrown Weapons" } },
    { id = 228, names = { "Wands" }, classTrainer = true }, -- class trainers teach wands, no weapon master does
}

-- Which weapon skills each class can learn, by skill line ID: the vanilla
-- proficiencies. A skill you turn out to know is shown whether or not it is
-- listed here, so a mistake shows up rather than hiding anything.
ns.classWeaponSkills = {
    WARRIOR = { 43, 55, 44, 172, 54, 160, 173, 162, 136, 229, 45, 46, 226, 176 },
    PALADIN = { 43, 55, 44, 172, 54, 160, 229 },
    HUNTER  = { 43, 55, 44, 172, 173, 162, 136, 229, 45, 46, 226, 176 },
    ROGUE   = { 43, 54, 173, 162, 45, 46, 226, 176 },
    PRIEST  = { 54, 173, 136, 228 },
    SHAMAN  = { 44, 172, 54, 160, 173, 162, 136 },
    MAGE    = { 43, 173, 136, 228 },
    WARLOCK = { 43, 173, 136, 228 },
    DRUID   = { 54, 160, 173, 162, 136, 229 },
}

-- Built-in weapon masters: npcID -> { name, location, skills = { skill line ID, ... } },
-- from Wowhead's Forever database and Warcraft Wiki. Masters recorded from the
-- trainer window live in SinkDB.weaponMasters and are merged with these;
-- "/sink dump trainer" prints a line for this table.
ns.weaponMasters = {
    [11867] = { name = "Woo Ping", location = "Stormwind City", skills = { 226, 173, 43, 55, 229, 136 } },
    [11865] = { name = "Buliwyf Stonehand", location = "Ironforge", skills = { 46, 44, 172, 54, 160, 162 } },
    [13084] = { name = "Bixi Wobblebonk", location = "Ironforge", skills = { 173, 226, 176 } },
    [11866] = { name = "Ilyenia Moonfire", location = "Darnassus", skills = { 45, 173, 162, 136, 176 } },
    [2704]  = { name = "Hanashi", location = "Orgrimmar", skills = { 45, 44, 172, 136, 176 } },
    [11868] = { name = "Sayoc", location = "Orgrimmar", skills = { 45, 173, 162, 44, 172, 136, 176 } },
    [11869] = { name = "Ansekhwa", location = "Thunder Bluff", skills = { 46, 54, 160, 136 } },
    [11870] = { name = "Archibald", location = "Undercity", skills = { 226, 173, 43, 55, 229 } },
}

local CHECK, CROSS = ns.CHECK, ns.CROSS
local reminded = {} -- npcID (or name) -> true once reminded this session

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

-- The skill line attributes (name, rank, maxRank) when the character knows
-- this skill, else nil.
local function Known(skill)
    if not (C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID) then
        return nil
    end
    local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, skill.id)
    if ok and info and not info.isHeader and (info.maxRank or 0) > 0 then
        return info
    end
    return nil
end

-- The client's name for the skill when known, else the first listed one.
local function SkillName(skill)
    local info = Known(skill)
    return (info and info.name) or skill.names[1]
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

-- Masters teaching a skill, as "Name (City)".
local function TeachersOf(skill)
    local names = {}
    EachMaster(function(_, master)
        for _, taught in ipairs(master.skills) do
            if taught == skill then
                names[#names + 1] = master.location and (master.name .. " (" .. master.location .. ")") or master.name
            end
        end
    end)
    return names
end

--------------------------------------------------------------------------------
-- Tooltip lines
--------------------------------------------------------------------------------

-- "Weapon skills taught here" plus one line per skill: a check with your rank
-- when you know it, a cross when your class can learn it, grey when it cannot.
-- The map icons in MapPins.lua use it too. Returns true when lines were added.
local function AddMasterLines(tooltip, npcID)
    if not Enabled() then
        return false
    end
    local master = npcID and MasterInfo(npcID)
    if not master or #master.skills == 0 then
        return false
    end
    tooltip:AddLine("Sink: weapon skills taught here", ns.accent.r, ns.accent.g, ns.accent.b)
    for _, skill in ipairs(master.skills) do
        local info = Known(skill)
        if info then
            tooltip:AddLine(("%s %s %d/%d"):format(CHECK, info.name, info.rank or 0, info.maxRank or 0), 0.6, 0.6, 0.6)
        elseif ClassCanLearn(skill) then
            tooltip:AddLine(CROSS .. " " .. SkillName(skill), 1.0, 0.4, 0.4)
        else
            tooltip:AddLine(SkillName(skill) .. ", not for your class", 0.5, 0.5, 0.5)
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
-- The trainer window: remember what a master teaches, point out what you lack
--------------------------------------------------------------------------------

-- Weapon skills the open trainer window lists: { skill, name, type }, the type
-- being "available", "unavailable" or "used" as the window shows it. The
-- window's own filter boxes decide what is listed at all.
local function TrainerWeaponSkills()
    local rows = {}
    local count = GetNumTrainerServices and GetNumTrainerServices() or 0
    for index = 1, count do
        local name, serviceType = GetTrainerServiceInfo(index)
        local skill = name and skillByName[name:lower()]
        if skill and serviceType ~= "header" then
            rows[#rows + 1] = { skill = skill, name = name, type = serviceType }
        end
    end
    return rows
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

    local npcID = ns.NPCIDFromGUID and ns.NPCIDFromGUID(UnitGUID and UnitGUID("npc"))
    local name = UnitName and UnitName("npc") or nil
    if npcID then
        RememberMaster(npcID, name, rows)
    end

    local key = npcID or name
    if not Enabled() or not key or reminded[key] then
        return
    end
    local learnable = {}
    for _, row in ipairs(rows) do
        if row.type == "available" then
            learnable[#learnable + 1] = row.name
        end
    end
    if #learnable > 0 then
        reminded[key] = true
        ns.Print("weapon skills you can learn here: " .. table.concat(learnable, ", ") .. ".")
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(#learnable .. (#learnable == 1 and " weapon skill" or " weapon skills")
                .. " to learn here", 1.0, 0.82, 0.0)
        end
    end
end

--------------------------------------------------------------------------------
-- /sink weapons ...
--------------------------------------------------------------------------------

local function WeaponsHelp()
    ns.Print("weapon skill commands")
    print("  /sink weapons           your class's weapon skills: the rank, or who teaches the ones you lack")
    print("  /sink weapons masters   every weapon master and what they teach")
    print("  /sink weapons on | off  turn the tooltip lines and reminders on or off")
end

local function ListSkills()
    local className = UnitClass("player")
    local set = ClassSkillSet()
    ns.Print(("weapon skills for %s%s"):format(className or "your class",
        set == nil and " (class not in the table, showing every skill)" or ""))
    for _, skill in ipairs(ns.weaponSkills) do
        local info = Known(skill)
        if info then
            print(("  %s %s %d/%d"):format(CHECK, info.name, info.rank or 0, info.maxRank or 0))
        elseif set == nil or set[skill.id] then
            local from
            if skill.classTrainer then
                from = "from your class trainer"
            else
                local teachers = TeachersOf(skill)
                from = #teachers > 0 and table.concat(teachers, ", ") or "no weapon master listed yet"
            end
            print(("  %s %s, %s"):format(CROSS, SkillName(skill), from))
        end
    end
end

local function ListMasters()
    local any = false
    EachMaster(function(npcID, master)
        any = true
        print(("  %s (%d)%s"):format(master.name, npcID, master.location and (", " .. master.location) or ""))
        for _, skill in ipairs(master.skills) do
            local info = Known(skill)
            if info then
                print(("    %s %s %d/%d"):format(CHECK, info.name, info.rank or 0, info.maxRank or 0))
            elseif ClassCanLearn(skill) then
                print(("    %s %s"):format(CROSS, SkillName(skill)))
            else
                print("    |cff808080" .. SkillName(skill) .. ", not for your class|r")
            end
        end
    end)
    if not any then
        ns.Print("no weapon masters listed. Open one's window and it is recorded.")
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
