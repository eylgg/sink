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
-- Clicking an icon that marks an NPC targets it. Targeting is a protected
-- action an addon cannot perform itself, so each pin carries a secure action
-- button as an overlay that runs "/targetexact <name>" on a real click. That
-- finds the NPC when it is loaded around you, so it is for "which one is the
-- blacksmith" in town, not for locating someone across the zone.
--------------------------------------------------------------------------------

local _, ns = ...

local TEMPLATE = "SinkMapPinTemplate"
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_Map_01"

-- Built-in icons: uiMapID -> list of { x, y, name, icon, note, npc }. The
-- tooltip shows note ("Fishing Supplies") in Sink's colour, or name when there
-- is no note; npc ties the icon to a vendor in Recipes.lua so the tooltip also
-- lists the recipes sold there and whether you know them.
-- On the Forever build Tirisfal Glades is map 1420, Undercity 1458 and Orgrimmar 1454.
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
    },
    [1454] = { -- Orgrimmar
        { npc = 2704, name = "Hanashi", note = "Weapon Master", x = 0.8153, y = 0.1963,
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
        button:SetAttribute("macrotext", "/targetexact " .. name)
        button:Show()
    else
        button:SetAttribute("type", nil)
        button:Hide()
    end
end

function SinkMapPinMixin:OnAcquired(pin) -- pin is the table from ns.mapPins or ns.db.mapPins
    self.pin = pin
    self.Icon:SetTexture(pin.icon or DEFAULT_ICON)
    self.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the icon's dark edge before the circle clips it
    TintRing(self, false)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI") -- same layer as Blizzard's points of interest
    self:SetPosition(pin.x, pin.y)
    self:SetClickTarget(pin.npc and pin.name or nil) -- only icons that mark an NPC target on click
end

function SinkMapPinMixin:OnMouseEnter()
    TintRing(self, true)
    local pin = self.pin
    if not pin then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(pin.note or pin.name, ns.accent.r, ns.accent.g, ns.accent.b)
    if pin.npc and ns.AddRecipeVendorLines then
        ns.AddRecipeVendorLines(GameTooltip, pin.npc)
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
    EachPin(map:GetMapID(), function(pin)
        map:AcquirePin(TEMPLATE, pin)
    end)
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
    print("  /sink map                list the icons by zone")
    print("  /sink map add <name>     put an icon where you stand (saved per character)")
    print("  /sink map remove <name>  remove an icon you added")
    print("  /sink map on | off       show or hide the icons")
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
            print(("    %s at %s%s"):format(pin.name, Coords(pin.x, pin.y), pin.note and (", " .. pin.note) or ""))
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
        ns.db.mapIcons = (sub == "on")
        ns.Print("map icons " .. (sub == "on" and "|cff00ff00on|r" or "|cffff0000off|r") .. ".")
        Refresh()
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
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Install()
    elseif event == "PLAYER_REGEN_ENABLED" and refreshAfterCombat then
        refreshAfterCombat = false
        Refresh()
    end
end)
