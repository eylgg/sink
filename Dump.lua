--------------------------------------------------------------------------------
-- Sink / Dump.lua
--
-- Developer commands. "/sink dump ..." prints the IDs and coordinates the
-- built-in tables in the other files are made of, in a form you can paste.
-- Nothing here changes any state; the player-facing commands live with their
-- modules.
--------------------------------------------------------------------------------

local _, ns = ...

local function DumpHelp()
    ns.Print("dump commands, for filling in the tables in the Lua files")
    print("  /sink dump loc      zone, map ID and your position, with a map icon line to paste")
    print("  /sink dump target   your target's name, NPC ID, GUID and tooltip lines, with a map icon line")
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
    print(ns.MapPinLine(mapID, { name = "?", x = x, y = y }))
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
                if text and text ~= "" then
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
    print(ns.MapPinLine(mapID, { npc = npcID, name = name, note = TitleFrom(lines), x = x, y = y }))
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
    else
        DumpHelp()
    end
end
