--------------------------------------------------------------------------------
-- Sink / Dump.lua
--
-- Developer commands. "/sink dump ..." prints the IDs and coordinates the
-- built-in tables in the other files are made of, in a form you can paste.
-- Nothing here changes any state; the player-facing commands live with their
-- modules.
--------------------------------------------------------------------------------

local _, ns = ...

-- Chat text cannot be selected, so a line meant for pasting is also put in a
-- box with the text already selected: Cmd+C on a Mac, Ctrl+C on Windows.
local POPUP = "SINK_COPY_LINE"

StaticPopupDialogs[POPUP] = {
    text = "%s",
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 420,
    OnShow = function(self, data)
        local box = self.EditBox or self.editBox
        if box then
            box:SetText(data.text)
            box:HighlightText()
            box:SetFocus()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Prints the line and opens the copy box with it selected.
local function PasteLine(caption, line)
    print(line)
    StaticPopup_Show(POPUP, caption, nil, { text = (line:gsub("^%s+", "")) })
end

-- A dump of many lines goes in a window instead: a scrolling box with all of
-- it selected, built from Blizzard's InputScrollFrameTemplate. Escape or the
-- close button hides it.
local COPY_WINDOW = "SinkCopyFrame"
local copyWindow

local function CopyWindow(title, lines)
    if not copyWindow then
        local frame = CreateFrame("Frame", COPY_WINDOW, UIParent, "ButtonFrameTemplate")
        frame:SetSize(560, 380)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetClampedToScreen(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        if ButtonFrameTemplate_HidePortrait then
            ButtonFrameTemplate_HidePortrait(frame)
        end
        if ButtonFrameTemplate_HideButtonBar then
            ButtonFrameTemplate_HideButtonBar(frame)
        end
        if ButtonFrameTemplate_HideAttic then
            ButtonFrameTemplate_HideAttic(frame)
        end
        if UISpecialFrames then
            table.insert(UISpecialFrames, COPY_WINDOW) -- Escape closes it
        end
        local scroll = CreateFrame("ScrollFrame", nil, frame.Inset, "InputScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 10, -10)
        scroll:SetPoint("BOTTOMRIGHT", -28, 10)
        if scroll.CharCount then
            scroll.CharCount:Hide()
        end
        local box = scroll.EditBox
        box:SetFontObject("ChatFontNormal")
        box:SetWidth(500)
        box:SetScript("OnEscapePressed", function()
            frame:Hide()
        end)
        frame.Box = box
        copyWindow = frame
    end
    local titleText = (copyWindow.TitleContainer and copyWindow.TitleContainer.TitleText) or copyWindow.TitleText
    if titleText then
        titleText:SetText(title .. ": Cmd+C or Ctrl+C to copy")
    end
    copyWindow:Show()
    copyWindow.Box:SetText(table.concat(lines, "\n"))
    copyWindow.Box:SetCursorPosition(0)
    copyWindow.Box:HighlightText()
    copyWindow.Box:SetFocus()
end

local function DumpHelp()
    ns.Print("dump commands, for filling in the tables in the Lua files")
    print("  /sink dump loc      zone, map ID and your position, with a map icon line to paste")
    print("  /sink dump target   your target's name, NPC ID, GUID and tooltip lines, with a map icon line")
    print("  /sink dump trainer  the open trainer window's services, with a weapon master line to paste")
    print("  /sink dump skills   every skill line the client lists, then each weapon skill's two signals")
    print("  /sink dump npc [unverified]  every NPC and place position in the tables, or only those not taken in game")
end

-- Every position in the built-in tables: the map pins in MapPins.lua, NPCs
-- and places such as zeppelins, and the quest NPCs and dungeon entrances in
-- Quests.lua. A position is verified once it was taken in game ("/sink dump
-- target" next to an NPC, "/sink dump loc" at a place); the rest came from
-- elsewhere, such as Wowhead, and may be a little off. With onlyUnverified,
-- only those.
local function DumpNPCs(onlyUnverified)
    local rows = {}
    local function add(npcID, name, mapID, x, y, verified, source)
        if not (onlyUnverified and verified) then
            rows[#rows + 1] = { npcID = npcID, name = name or "?", zone = ns.MapName(mapID), x = x, y = y,
                verified = verified, source = source }
        end
    end
    for mapID, pins in pairs(ns.mapPins or {}) do
        for _, pin in ipairs(pins) do
            add(pin.npc, pin.name, mapID, pin.x, pin.y, pin.verified == true, "MapPins.lua")
        end
    end
    for npcID, npc in pairs(ns.npcs or {}) do
        if npc.map then
            add(npcID, npc.name, npc.map, npc.x, npc.y, npc.verified == true, "Quests.lua")
        elseif npc.instance and not (onlyUnverified and npc.verified) then
            local dungeon = ns.dungeons and ns.dungeons[npc.instance]
            rows[#rows + 1] = { npcID = npcID, name = npc.name, zone = dungeon and dungeon.name or "a dungeon",
                inside = true, verified = npc.verified == true, source = "Quests.lua" }
        end
    end
    for _, dungeon in pairs(ns.dungeons or {}) do
        add(nil, dungeon.name, dungeon.map, dungeon.x, dungeon.y, dungeon.verified == true, "Quests.lua")
    end
    table.sort(rows, function(a, b)
        if a.zone ~= b.zone then
            return a.zone < b.zone
        end
        return a.name < b.name
    end)
    if #rows == 0 then
        ns.Print(onlyUnverified and "every position has been verified in game." or "no positions in the tables.")
        return
    end
    ns.Print(("%d position%s%s"):format(#rows, #rows == 1 and "" or "s", onlyUnverified and " not verified in game" or ""))
    for _, row in ipairs(rows) do
        local where = row.inside and ("inside " .. row.zone) or ("%s %.1f, %.1f"):format(row.zone, row.x * 100, row.y * 100)
        print(("  %s%s, %s, %s%s"):format(row.name, row.npcID and (" (" .. row.npcID .. ")") or "", where,
            row.source, row.verified and "" or (" " .. ns.missing.hex .. "unverified|r")))
    end
    if onlyUnverified then
        print("  To fix one, target the NPC and use /sink dump target, or stand at the place and use /sink dump loc.")
    end
end

-- What the client says this character knows: every skill line it lists, then
-- each weapon skill with the two signs Sink reads, its skill line and its
-- proficiency spell.
local function DumpSkills()
    if not (C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo) then
        ns.Print("C_SkillInfo is not available on this client.")
        return
    end
    ns.Print("skill lines the client lists (a collapsed header hides its lines)")
    for index = 1, C_SkillInfo.GetNumSkillLines() do
        local info = C_SkillInfo.GetSkillLineInfo(index)
        if info and info.isHeader then
            print(("  %s%s"):format(tostring(info.name), info.isCollapsed and " (collapsed)" or ""))
        elseif info then
            print(("    %s (line %d) %d/%d"):format(tostring(info.name), info.skillID or 0, info.rank or 0, info.maxRank or 0))
        end
    end
    ns.Print("weapon skills as Sink reads them")
    for _, skill in ipairs(ns.weaponSkills or {}) do
        local line = "no line lookup"
        if C_SkillInfo.GetSkillLineInfoByID then
            local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, skill.id)
            if ok and info and (info.maxRank or 0) > 0 then
                line = ("line %d %d/%d"):format(skill.id, info.rank or 0, info.maxRank or 0)
            else
                line = ("line %d not listed"):format(skill.id)
            end
        end
        local spell = "no spell"
        if skill.spell then
            local known = (IsPlayerSpell and IsPlayerSpell(skill.spell)) or (IsSpellKnown and IsSpellKnown(skill.spell))
            spell = ("spell %d %s"):format(skill.spell, known and "known" or "not known")
        end
        print(("  %s: %s, %s"):format(skill.names[1], line, spell))
    end
end

-- Zone name, map ID and its parent, subzone, and the position in both forms.
local function PrintLocation(mapID, x, y)
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local parent = info and info.parentMapID
    local subzone = GetSubZoneText and GetSubZoneText() or ""
    ns.Print(("%s (map %d%s)%s at %.1f, %.1f"):format(ns.MapName(mapID), mapID,
        parent and (", parent " .. parent) or "", subzone ~= "" and (", " .. subzone) or "", x * 100, y * 100))
    print(("  x = %.4f, y = %.4f"):format(x, y))
end

local function DumpLocation()
    local mapID, x, y = ns.UnitMapPosition("player")
    if not mapID then
        ns.Print("the client does not report a map position here.")
        return
    end
    PrintLocation(mapID, x, y)
    PasteLine("Map icon line for MapPins.lua", ns.MapPinLine(mapID, { name = "?", x = x, y = y }))
end

local function LineText(line)
    if ns.TooltipLineText then
        return ns.TooltipLineText(line)
    end
    return line.leftText
end

-- Every left-hand line of the unit's tooltip: name, title, level and type, faction.
local function TooltipLines(unit)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and data and data.lines then
            for _, line in ipairs(data.lines) do
                local text = LineText(line)
                if text and not ns.Secret(text) and text ~= "" then
                    lines[#lines + 1] = text
                end
            end
        end
    end
    return lines
end

-- The tooltip's second line is the NPC's title ("Fishing Supplies") when it has
-- one, otherwise the level line, which starts with the localized word "Level".
local function TitleFrom(lines)
    local title = lines[2]
    if not title then
        return nil
    end
    local levelPrefix = (UNIT_LEVEL_TEMPLATE or "Level %d"):gsub("%%d.*$", "")
    if levelPrefix ~= "" and title:find(levelPrefix, 1, true) == 1 then
        return nil
    end
    return title
end

local function DumpTarget()
    if not (UnitExists and UnitExists("target")) then
        ns.Print("no target.")
        return
    end
    local name = UnitName("target")
    local guid = UnitGUID("target")
    -- Secret in combat and in instances; show a placeholder rather than an error.
    if ns.Secret(name) then
        name = "(hidden by the game)"
    end
    if ns.Secret(guid) then
        guid = "(hidden by the game)"
    end
    local npcID = ns.NPCIDFromGUID and ns.NPCIDFromGUID(guid)
    ns.Print(("target %s%s"):format(name or "?", npcID and (", NPC " .. npcID) or ", not a creature"))
    print("  guid " .. tostring(guid))
    local lines = TooltipLines("target")
    if #lines > 0 then
        print("  tooltip: " .. table.concat(lines, " | "))
    end

    local mapID, x, y = ns.UnitMapPosition("target")
    if mapID then
        print("  the target's position:")
    else
        mapID, x, y = ns.UnitMapPosition("player")
        print("  your position (the client gives none for NPCs, so stand next to it):")
    end
    if not mapID then
        ns.Print("the client does not report a map position here.")
        return
    end
    PrintLocation(mapID, x, y)
    PasteLine("Map icon line for MapPins.lua", ns.MapPinLine(mapID, { npc = npcID, name = name, note = TitleFrom(lines), x = x, y = y }))
end

-- Every service the open trainer window lists, as its filter boxes show them,
-- and for a weapon master the line for the table in Weapons.lua.
local function DumpTrainer()
    local count = GetNumTrainerServices and GetNumTrainerServices() or 0
    if count == 0 then
        ns.Print("no trainer window is open, or its filters hide everything.")
        return
    end
    local name = UnitName and ns.Readable(UnitName("npc")) or "?"
    local npcID = ns.NPCIDFromGUID and ns.NPCIDFromGUID(UnitGUID and UnitGUID("npc"))
    -- Printed to chat and, all of it, into the copy window.
    local lines = {}
    lines[#lines + 1] = ("trainer %s%s, %d services offered to this character (the window lists only what your class can take)")
        :format(name, npcID and (", NPC " .. npcID) or "", count)
    ns.Print(lines[1])
    local ids, skillLines = {}, {}
    for index = 1, count do
        local service, serviceType, _, reqLevel, subText, category = GetTrainerServiceInfo(index)
        local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(index)
        local spell = ns.TrainerServiceSpell and ns.TrainerServiceSpell(index)
        lines[#lines + 1] = ("  %d. %s | %s | %s | level %s | %s | %s | spell %s"):format(index, tostring(service),
            tostring(subText), tostring(serviceType), tostring(reqLevel), tostring(category), tostring(skillLine), tostring(spell))
        print(lines[#lines])
        if serviceType ~= "header" and not (ns.WeaponSkillID and ns.WeaponSkillID(service)) then
            local cost = GetTrainerServiceCost and tonumber(GetTrainerServiceCost(index))
            skillLines[#skillLines + 1] = ("    { name = %q, level = %d, spell = %s, rank = %q, cost = %s },"):format(
                tostring(service), tonumber(reqLevel) or 0, spell and tostring(spell) or "nil", tostring(subText or ""),
                cost and tostring(cost) or "nil")
        end
        local id = ns.WeaponSkillID and ns.WeaponSkillID(service)
        if id then
            ids[#ids + 1] = tostring(id)
        end
    end
    if npcID and #ids > 0 then
        lines[#lines + 1] = ("  [%d] = { name = %q, location = %q, skills = { %s } }, -- ns.weaponMasters, Weapons.lua; this class's view")
            :format(npcID, name, GetZoneText and GetZoneText() or "?", table.concat(ids, ", "))
        print(lines[#lines])
    end
    -- A class trainer's list, as a block for ns.classSkills in Trainers.lua.
    if #skillLines > 0 and #ids == 0 and not (IsTradeskillTrainer and IsTradeskillTrainer()) then
        local _, class = UnitClass("player")
        lines[#lines + 1] = ""
        lines[#lines + 1] = ("ns.classSkills.%s = {"):format(class or "?")
        for _, line in ipairs(skillLines) do
            lines[#lines + 1] = line
        end
        lines[#lines + 1] = "}"
    end
    CopyWindow("Trainer dump", lines)
end

function ns.DumpCommand(arg)
    if not ns.UnitMapPosition or not ns.MapPinLine then
        ns.Print("MapPins.lua is not loaded.")
        return
    end
    local sub = (arg or ""):match("^(%S*)"):lower()

    if sub == "loc" or sub == "location" or sub == "pos" then
        DumpLocation()
    elseif sub == "target" then
        DumpTarget()
    elseif sub == "trainer" then
        DumpTrainer()
    elseif sub == "skills" or sub == "skill" then
        DumpSkills()
    elseif sub == "npc" or sub == "npcs" then
        local filter = ((arg or ""):match("^%S+%s+(%S+)") or ""):lower()
        DumpNPCs(filter == "unverified")
    else
        DumpHelp()
    end
end
