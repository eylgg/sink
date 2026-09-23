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
--------------------------------------------------------------------------------

local _, ns = ...

local TEMPLATE = "SinkMapPinTemplate"
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_Map_01"

-- Built-in icons: uiMapID -> list of { x, y, name, icon, note, npc, class }.
-- The tooltip shows note ("Fishing Supplies") in Sink's colour, or name when
-- there is no note; npc ties the icon to a vendor in Recipes.lua or a weapon
-- master in Weapons.lua so the tooltip also lists what they sell or teach. A
-- "<Class> Trainer" note makes a class trainer; class = "PRIEST" does the same
-- for one whose note is a title such as "High Priest". A dungeon has
-- dungeon = true, minLevel and maxLevel (shown after the name as "11 - 24")
-- and quests, a list of { id, name } whose names stand in until the client
-- has the quest cached; atlas draws a map atlas instead of an icon texture.
-- On the Forever build Tirisfal Glades is map 1420, Undercity 1458, Orgrimmar 1454 and Thunder Bluff 1456.
ns.mapPins = {
    [1420] = { -- Tirisfal Glades
        { npc = 3550, name = "Martine Tramblay", note = "Fishing Supplies", x = 0.658, y = 0.595,
          icon = "Interface\\Icons\\Trade_Fishing" },
    },
    [1458] = { -- Undercity
        { npc = 11870, name = "Archibald", note = "Weapon Master", x = 0.5731, y = 0.3277,
          icon = "Interface\\Icons\\Ability_DualWield" },
        { npc = 4596, name = "James Van Brunt", note = "Expert Blacksmith", x = 0.6126, y = 0.3062,
          icon = "Interface\\Icons\\Trade_BlackSmithing" },
        { npc = 4598, name = "Brom Killian", note = "Mining Trainer", x = 0.5603, y = 0.3746,
          icon = "Interface\\Icons\\Trade_Mining" },
        { npc = 15683, name = "Auctioneer Naxxremis", note = "Auction House", x = 0.6440, y = 0.3580,
          icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { name = "Ruins of Lordaeron", dungeon = true, minLevel = 11, maxLevel = 24, x = 0.7261, y = 0.1148,
          atlas = "Dungeon", quests = {
              { id = 92401, name = "A Frightened Request" },
          } },
    },
    [1454] = { -- Orgrimmar
        { npc = 2704, name = "Hanashi", note = "Weapon Master", x = 0.8153, y = 0.1963,
          icon = "Interface\\Icons\\Ability_DualWield" },
        { npc = 11868, name = "Sayoc", note = "Weapon Master", x = 0.8170, y = 0.1954,
          icon = "Interface\\Icons\\Ability_DualWield" },
        { npc = 1383, name = "Snarl", note = "Expert Blacksmith", x = 0.7960, y = 0.2330,
          icon = "Interface\\Icons\\Trade_BlackSmithing" },
        { npc = 3357, name = "Makaru", note = "Mining Trainer", x = 0.7312, y = 0.2609,
          icon = "Interface\\Icons\\Trade_Mining" },
        { npc = 3399, name = "Zamja", note = "Cooking Trainer", x = 0.5740, y = 0.5396,
          icon = "Interface\\Icons\\INV_Misc_Food_15" },
        { npc = 3373, name = "Arnok", note = "First Aid Trainer", x = 0.3418, y = 0.8458,
          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
        { npc = 3404, name = "Jandi", note = "Herbalism Trainer", x = 0.5562, y = 0.3946,
          icon = "Interface\\Icons\\Trade_Herbalism" },
        { npc = 3332, name = "Lumak", note = "Fishing Trainer", x = 0.6980, y = 0.2921,
          icon = "Interface\\Icons\\Trade_Fishing" },
        { npc = 3347, name = "Yelmak", note = "Expert Alchemist", x = 0.5684, y = 0.3303,
          icon = "Interface\\Icons\\Trade_Alchemy" },
        { npc = 7088, name = "Thuwd", note = "Skinning Trainer", x = 0.6335, y = 0.4541,
          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
        { npc = 3365, name = "Karolek", note = "Expert Leatherworker", x = 0.6281, y = 0.4415,
          icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { npc = 11017, name = "Roxxik", note = "Artisan Engineer", x = 0.7617, y = 0.2518,
          icon = "Interface\\Icons\\Trade_Engineering" },
        { npc = 3412, name = "Nogg", note = "Expert Engineer", x = 0.7599, y = 0.2540,
          icon = "Interface\\Icons\\Trade_Engineering" },
        { npc = 2857, name = "Thund", note = "Journeyman Engineer", x = 0.7596, y = 0.2415,
          icon = "Interface\\Icons\\Trade_Engineering" },
        { npc = 3345, name = "Godan", note = "Expert Enchanter", x = 0.5390, y = 0.3866,
          icon = "Interface\\Icons\\Trade_Engraving" },
        { npc = 11066, name = "Jhag", note = "Journeyman Enchanter", x = 0.5347, y = 0.3855,
          icon = "Interface\\Icons\\Trade_Engraving" },
        { npc = 11046, name = "Whuut", note = "Journeyman Alchemist", x = 0.5579, y = 0.3290,
          icon = "Interface\\Icons\\Trade_Alchemy" },
        { npc = 5811, name = "Kamari", note = "Journeyman Leatherworker", x = 0.6328, y = 0.4475,
          icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { npc = 10266, name = "Ug'thok", note = "Journeyman Blacksmith", x = 0.8077, y = 0.2370,
          icon = "Interface\\Icons\\Trade_BlackSmithing" },
        { npc = 3328, name = "Ormok", note = "Rogue Trainer", x = 0.4390, y = 0.5463,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 3401, name = "Shenthul", note = "Rogue Trainer", x = 0.4305, y = 0.5374,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 3327, name = "Gest", note = "Rogue Trainer", x = 0.4269, y = 0.5148,
          icon = "Interface\\Icons\\ClassIcon_Rogue" },
        { npc = 3325, name = "Mirket", note = "Warlock Trainer", x = 0.4862, y = 0.4696,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 3326, name = "Zevrost", note = "Warlock Trainer", x = 0.4847, y = 0.4542,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 3324, name = "Grol'dar", note = "Warlock Trainer", x = 0.4798, y = 0.4593,
          icon = "Interface\\Icons\\ClassIcon_Warlock" },
        { npc = 3354, name = "Sorek", note = "Warrior Trainer", x = 0.8039, y = 0.3237,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 3353, name = "Grezz Ragefist", note = "Warrior Trainer", x = 0.7979, y = 0.3142,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 3408, name = "Zel'mak", note = "Warrior Trainer", x = 0.8037, y = 0.2952,
          icon = "Interface\\Icons\\ClassIcon_Warrior" },
        { npc = 3403, name = "Sian'tsu", note = "Shaman Trainer", x = 0.3784, y = 0.3646,
          icon = "Interface\\Icons\\ClassIcon_Shaman" },
        { npc = 13417, name = "Sagorne Creststrider", note = "Shaman Trainer", x = 0.3867, y = 0.3593,
          icon = "Interface\\Icons\\ClassIcon_Shaman" },
        { npc = 3344, name = "Kardris Dreamseeker", note = "Shaman Trainer", x = 0.3881, y = 0.3636,
          icon = "Interface\\Icons\\ClassIcon_Shaman" },
        { npc = 6018, name = "Ur'kyo", note = "Priest Trainer", x = 0.3559, y = 0.8782,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 6014, name = "X'yera", note = "Priest Trainer", x = 0.3600, y = 0.8773,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 5994, name = "Zayus", note = "High Priest", class = "PRIEST", x = 0.3572, y = 0.8690,
          icon = "Interface\\Icons\\ClassIcon_Priest" },
        { npc = 5883, name = "Enyo", note = "Mage Trainer", x = 0.3879, y = 0.8567,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 5882, name = "Pephredo", note = "Mage Trainer", x = 0.3836, y = 0.8556,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 5885, name = "Deino", note = "Mage Trainer", x = 0.3845, y = 0.8613,
          icon = "Interface\\Icons\\ClassIcon_Mage" },
        { npc = 3407, name = "Sian'dur", note = "Hunter Trainer", x = 0.6796, y = 0.1779,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 3406, name = "Xor'juul", note = "Hunter Trainer", x = 0.6725, y = 0.2019,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
        { npc = 3352, name = "Ormak Grimshot", note = "Hunter Trainer", x = 0.6605, y = 0.1853,
          icon = "Interface\\Icons\\ClassIcon_Hunter" },
    },
    [1456] = { -- Thunder Bluff
        { npc = 11869, name = "Ansekhwa", note = "Weapon Master", x = 0.4095, y = 0.6273,
          icon = "Interface\\Icons\\Ability_DualWield" },
    },
}

local provider -- our data provider, once added to WorldMapFrame
local refreshAfterCombat = false -- a pin was acquired in combat; redo them all when it ends

local function Enabled()
    return ns.db ~= nil and ns.db.mapIcons ~= false
end

local function CustomPins()
    return ns.db and ns.db.mapPins or nil
end

-- Calls fn(pin) for every icon on mapID: built-in first, then those added in game.
local function EachPin(mapID, fn)
    for _, pin in ipairs(ns.mapPins[mapID] or {}) do
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
local RANK_CAPS = { Apprentice = 75, Journeyman = 150, Expert = 225, Artisan = 300 }

local function NoteText(pin)
    local note = pin.note or pin.name
    if pin.minLevel and pin.maxLevel then
        return ("%s (%d - %d)"):format(note, pin.minLevel, pin.maxLevel)
    end
    local cap = RANK_CAPS[note:match("^(%a+)") or ""]
    return cap and (note .. " (" .. cap .. ")") or note
end

-- Professions, by the words a trainer's note uses for them: "Expert
-- Blacksmith", "Mining Trainer". line is the skill line that says how far you
-- are. Primary professions are the ones you can have two of; the rest are
-- secondary and open to everyone.
local PROFESSIONS = {
    { line = 171, primary = true,  words = { "alchemist", "alchemy" } },
    { line = 164, primary = true,  words = { "blacksmith", "blacksmithing" } },
    { line = 333, primary = true,  words = { "enchanter", "enchanting" } },
    { line = 202, primary = true,  words = { "engineer", "engineering" } },
    { line = 182, primary = true,  words = { "herbalist", "herbalism" } },
    { line = 165, primary = true,  words = { "leatherworker", "leatherworking" } },
    { line = 186, primary = true,  words = { "miner", "mining" } },
    { line = 393, primary = true,  words = { "skinner", "skinning" } },
    { line = 197, primary = true,  words = { "tailor", "tailoring" } },
    { line = 185, primary = false, words = { "cook", "cooking" } },
    { line = 129, primary = false, words = { "first aid" } },
    { line = 356, primary = false, words = { "fisherman", "fishing" } },
}
local professionByWord = {}
for _, profession in ipairs(PROFESSIONS) do
    for _, word in ipairs(profession.words) do
        professionByWord[word] = profession
    end
end

-- A "<Class> Trainer" pin is for that class only.
local CLASS_WORDS = {
    warrior = "WARRIOR", paladin = "PALADIN", hunter = "HUNTER", rogue = "ROGUE", priest = "PRIEST",
    shaman = "SHAMAN", mage = "MAGE", warlock = "WARLOCK", druid = "DRUID",
}

-- For a trainer pin: its profession (a class trainer gives { class = ... },
-- an unknown word gives false), the rank cap (nil for a plain "... Trainer"),
-- and the word. Any other pin returns nil.
local function TrainerInfo(pin)
    if pin.class then
        return { class = pin.class }, nil, pin.class:lower()
    end
    local note = pin.note or ""
    local rank, rest = note:match("^(%a+)%s+(.+)$")
    local cap = rank and RANK_CAPS[rank]
    if cap then
        local word = rest:lower()
        return professionByWord[word] or false, cap, word
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

-- The pins to draw on a map. Dungeons only while "show dungeons" is on.
-- Trainers are filtered first: a class trainer
-- only for your class unless "show all class trainers" is on; with "show all
-- profession trainers" off, secondary professions and your own primary ones
-- always, other primary ones only while you still have a free slot. Then of a
-- profession's ranked trainers only one is drawn. Everything else is drawn as
-- it is.
local function PinsToShow(mapID)
    local shown, groups = {}, {}
    local showAll = ns.db and ns.db.showAllTrainers
    local showAllClasses = ns.db and ns.db.showAllClassTrainers
    local showDungeons = not (ns.db and ns.db.showDungeons == false)
    local freeSlot = PrimaryCount() < 2
    local _, playerClass = UnitClass("player")
    EachPin(mapID, function(pin)
        local profession, cap, word = TrainerInfo(pin)
        if pin.dungeon then
            if showDungeons then
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

    local button = CreateFrame("Button", nil, self, "SecureActionButtonTemplate")
    button:SetAllPoints(self)
    -- The secure handler runs the action once, on down or up per ActionButtonUseKeyDown.
    button:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    if button.SetPassThroughButtons then
        pcall(button.SetPassThroughButtons, button, "RightButton")
    end
    button:SetScript("OnEnter", function(b)
        b:GetParent():OnMouseEnter()
    end)
    button:SetScript("OnLeave", function(b)
        b:GetParent():OnMouseLeave()
    end)
    button:Hide()
    self.ClickButton = button
end

-- A secure button's attributes can only be changed out of combat. A pin
-- acquired during a fight is left as it was, and every pin is redone when the
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
        button:Hide()
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
    TintRing(self, false)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI") -- same layer as Blizzard's points of interest
    self:SetPosition(pin.x, pin.y)
    self:SetClickTarget(pin.npc and pin.name or nil) -- only icons that mark an NPC target on click
end

-- A dungeon's quests: the title the client has, else the name in the table,
-- and ask the server so the next hover has the real one.
local function QuestTitle(quest)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(quest.id)
    if title and title ~= "" then
        return title
    end
    if C_QuestLog.RequestLoadQuestByID then
        C_QuestLog.RequestLoadQuestByID(quest.id)
    end
    return quest.name or ("quest #" .. quest.id)
end

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

-- One line per quest: red cross for one not in your log, yellow waiting mark
-- for one in it, green check for one done; in that order, each group
-- alphabetical.
local function AddQuestLines(tooltip, quests)
    local rows = {}
    for _, quest in ipairs(quests) do
        rows[#rows + 1] = { state = QuestState(quest.id), title = QuestTitle(quest) }
    end
    table.sort(rows, function(a, b)
        if a.state ~= b.state then
            return a.state < b.state
        end
        return a.title < b.title
    end)
    for _, row in ipairs(rows) do
        if row.state == NOT_TAKEN then
            tooltip:AddLine(ns.CROSS .. " " .. row.title, ns.missing.r, ns.missing.g, ns.missing.b)
        elseif row.state == IN_LOG then
            tooltip:AddLine(ns.WAIT .. " " .. row.title, ns.active.r, ns.active.g, ns.active.b)
        else
            tooltip:AddLine(ns.CHECK .. " " .. row.title, ns.known.r, ns.known.g, ns.known.b)
        end
    end
end

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
    if pin.quests then
        AddQuestLines(GameTooltip, pin.quests)
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

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Which trainer to draw depends on your skills; redraw when they change.
pcall(frame.RegisterEvent, frame, "SKILL_LINES_CHANGED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Install()
    elseif event == "PLAYER_REGEN_ENABLED" and refreshAfterCombat then
        refreshAfterCombat = false
        Refresh()
    elseif event == "SKILL_LINES_CHANGED" then
        Refresh()
    end
end)
