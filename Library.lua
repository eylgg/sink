--------------------------------------------------------------------------------
-- Sink / Library.lua
--
-- The library books: books lying in the world that the librarians in
-- Stormwind and Undercity take, one quest each. Ten different ones handed in
-- give a necklace (Friend of the Library), twenty a ring.
--
-- A book counts as collected once its quest is turned in or the book is in
-- your bags. Each book not yet collected gets a map pin (the Books kind),
-- and the librarians have one too, with how many you have handed in. The
-- options window's Library tab lists every book with its mark: green check
-- handed in, yellow in your bags, red cross still to find. The tracker's
-- Library Books section, off by default, lists the ones still to find.
--
-- Books, quests and containers from Wowhead's Forever database; positions
-- from ForeverChanges' library guide, except the two marked verified,
-- taken in game. Two books are left out: Ataeric: On Arcane Curiosities,
-- which no one has found yet, and A Luddite's Guide to Caring for Your
-- Demonic Pet, which Wowhead gives no quest.
--------------------------------------------------------------------------------

local _, ns = ...

-- { item, quest, name, map, x, y, where, faction, level, also }. faction for a
-- book only one side can hand in; level for the ones whose quest is level 35.
-- also is a second place the same book lies.
ns.libraryBooks = {
    { item = 203755, quest = 79092, name = "Archmage Theocritus' Research Journal", map = 1429, x = 0.654, y = 0.701,
      where = "Library Book, Tower of Azora" },
    { item = 203754, quest = 79091, name = "Archmage Antonidas: The Unabridged Autobiography", map = 1455,
      x = 0.757, y = 0.105, where = "Library Book", faction = "Alliance" },
    { item = 209845, quest = 78142, name = "Bewitchments and Glamours", map = 1436, x = 0.454, y = 0.704,
      where = "Spellbook, Moonbrook" },
    { item = 208860, quest = 79093, name = "Rumi of Gnomeregan: The Collected Works", map = 1436, x = 0.527, y = 0.538,
      where = "Gnomish Tome, Sentinel Hill", faction = "Alliance",
      also = { map = 1432, x = 0.356, y = 0.489, where = "Gnomish Tome, Thelsamar" } },
    { item = 209849, quest = 78147, name = "Crimes Against Anatomy", map = 1431, x = 0.166, y = 0.285,
      where = "Spellbook, The Darkened Bank" },
    { item = 209850, quest = 78148, name = "Runes of the Sorcerer-Kings", map = 1432, x = 0.774, y = 0.140,
      where = "Scrolls, Mo'grosh Stronghold" },
    { item = 209848, quest = 78146, name = "Goaz Scrolls", map = 1437, x = 0.336, y = 0.479,
      where = "Scrolls, Whelgar's Excavation Site" },
    { item = 209844, quest = 78127, name = "The Dalaran Digest, Vol. 23", map = 1421, x = 0.635, y = 0.631,
      where = "Dalaran Digest, Ambermill" },
    { item = 208185, quest = 79095, name = "The Apothecary's Metaphysical Primer", map = 1420, x = 0.594, y = 0.523,
      where = "Apothecary Society Primer, Brill", faction = "Horde" },
    { item = 209843, quest = 78124, name = "Nar'thalas Almanac, Vol. 74", map = 1439, x = 0.596, y = 0.222,
      where = "Scrolls, Ruins of Mathystra" },
    { item = 209847, quest = 78145, name = "Arcanic Systems Manual", map = 1413, x = 0.563, y = 0.088,
      where = "Manual, The Sludge Fen" },
    { item = 208800, quest = 79097, name = "Baxtan: On Destructive Magics", map = 1413, x = 0.6266, y = 0.3622,
      where = "Goblin Tome, Ratchet", verified = true },
    -- In a cave the client puts on no zone, so on the Kalimdor map; drawn on The Barrens.
    { item = 209846, quest = 78143, name = "Secrets of the Dreamers", map = 1414, x = 0.5283, y = 0.5470,
      where = "Scrolls, Cavern of Mists by the Wailing Caverns entrance", verified = true },
    { item = 209851, quest = 78149, name = "Fury of the Land", map = 1442, x = 0.744, y = 0.857,
      where = "Scrolls, Grimtotem Post" },
    { item = 207972, quest = 79094, name = "The Lessons of Ta'zo", map = 1454, x = 0.387, y = 0.784,
      where = "Ta'zo Mural", faction = "Horde" },
    { item = 213165, quest = 79535, name = "Basilisks: Should Petrification be Feared?", map = 1434, x = 0.414,
      y = 0.509, where = "Research Notes, on the platform right of Crystalvein Mine", level = 35 },
    { item = 215683, quest = 79947, name = "Geomancy: The Stone-Cold Truth", map = 1441, x = 0.344, y = 0.401,
      where = "Scrolls, the largest hut on Darkcloud Pinnacle", level = 35 },
    { item = 215815, quest = 79948, name = "Defensive Magics 101", map = 1416, x = 0.484, y = 0.576,
      where = "Manual, the first tower of Gallows' Corner", level = 35 },
    { item = 215822, quest = 79952, name = "RwlRwlRwlRwl!", map = 1445, x = 0.572, y = 0.208,
      where = "Waterlogged Book, east edge of Witch Hill", level = 35 },
    { item = 215816, quest = 79949, name = "A Web of Lies: Debunking Myths and Legends", map = 1417, x = 0.736,
      y = 0.652, where = "Scrolls, Witherbark Village", level = 35 },
    { item = 215817, quest = 79950, name = "Demons and You", map = 1443, x = 0.551, y = 0.262,
      where = "Mysterious Book, Thunder Axe Fortress", level = 35 },
    { item = 215820, quest = 79951, name = "Mummies: A Guide to the Unsavory Undead", map = 1418, x = 0.567, y = 0.399,
      where = "Scrolls", level = 35 },
}

-- Handed in this many for each reward.
local NECKLACE, RING = 10, 20

local LIBRARIANS = {
    { npc = 211033, name = "Garion Wendell", map = 1453, x = 0.376, y = 0.808, faction = "Alliance",
      where = "Mage Quarter, Stormwind City" },
    { npc = 211022, name = "Owen Thadd", map = 1458, x = 0.734, y = 0.330, faction = "Horde",
      where = "Magic Quarter, Undercity" },
}

local HANDED_IN, IN_BAGS, MISSING = 1, 2, 3

local function ForMyFaction(book)
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    return not book.faction or not mine or book.faction == mine
end

local function State(book)
    if C_QuestLog.IsQuestFlaggedCompleted(book.quest) then
        return HANDED_IN
    end
    if C_Item.GetItemCount and C_Item.GetItemCount(book.item) > 0 then
        return IN_BAGS
    end
    return MISSING
end

function ns.LibraryBookCollected(book)
    return State(book) ~= MISSING
end

local function MapName(mapID)
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or ("map " .. mapID)
end

-- Your librarian: the one of your faction.
local function Librarian()
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    for _, librarian in ipairs(LIBRARIANS) do
        if librarian.faction == mine then
            return librarian
        end
    end
    return LIBRARIANS[1]
end

-- The books for your faction, each with its state, in the table's order, and
-- how many are handed in and in your bags.
local function Books()
    local list, handed, bags = {}, 0, 0
    for _, book in ipairs(ns.libraryBooks) do
        if ForMyFaction(book) then
            local state = State(book)
            list[#list + 1] = { book = book, state = state }
            if state == HANDED_IN then
                handed = handed + 1
            elseif state == IN_BAGS then
                bags = bags + 1
            end
        end
    end
    return list, handed, bags
end

-- "4/10 for the necklace, 4/20 for the ring": green once reached.
local function Progress(handed)
    local function part(need, reward)
        local color = handed >= need and ns.known.hex or "|cffffffff"
        return ("%s%d/%d|r for the %s"):format(color, math.min(handed, need), need, reward)
    end
    return part(NECKLACE, "necklace") .. ", " .. part(RING, "ring")
end

--------------------------------------------------------------------------------
-- Map pins: the books not collected yet, and the librarians
--------------------------------------------------------------------------------

local function AddPin(map, pin)
    ns.mapPins[map] = ns.mapPins[map] or {}
    table.insert(ns.mapPins[map], pin)
end

for _, book in ipairs(ns.libraryBooks) do
    local pin = { name = book.name, note = "Book", item = book.item, x = book.x, y = book.y, book = book,
        faction = book.faction or "Both", icon = "Interface\\Icons\\INV_Misc_Book_09", verified = book.verified }
    AddPin(book.map, pin)
    if book.also then
        local copy = {}
        for key, value in pairs(pin) do
            copy[key] = value
        end
        copy.x, copy.y, copy.verified = book.also.x, book.also.y, nil
        AddPin(book.also.map, copy)
    end
end
for _, librarian in ipairs(LIBRARIANS) do
    AddPin(librarian.map, { npc = librarian.npc, name = librarian.name, note = "Librarian", x = librarian.x,
        y = librarian.y, faction = librarian.faction, librarian = true, icon = "Interface\\Icons\\INV_Misc_Book_05" })
end

-- A book pin's tooltip, under its "Book" title: the book, where it lies, and
-- whose it is to hand in.
function ns.AddLibraryBookLines(tooltip, book)
    tooltip:AddLine(book.name, 1, 1, 1)
    tooltip:AddLine(book.where, ns.grey.r, ns.grey.g, ns.grey.b, true)
    local librarian = Librarian()
    tooltip:AddLine(("%s Not collected: hand it in to %s"):format(ns.CROSS, librarian.name),
        ns.missing.r, ns.missing.g, ns.missing.b, true)
    if book.level then
        tooltip:AddLine(("Its quest is level %d"):format(book.level), ns.grey.r, ns.grey.g, ns.grey.b)
    end
end

-- A librarian pin's tooltip: how far along you are, and the books in your
-- bags waiting to be handed in.
function ns.AddLibrarianLines(tooltip)
    local list, handed = Books()
    tooltip:AddLine("Handed in " .. Progress(handed), 1, 1, 1, true)
    for _, entry in ipairs(list) do
        if entry.state == IN_BAGS then
            tooltip:AddLine(ns.WAIT .. " " .. entry.book.name, ns.active.r, ns.active.g, ns.active.b)
        end
    end
end

--------------------------------------------------------------------------------
-- The tracker's Library Books section, off by default
--------------------------------------------------------------------------------

-- A count line, the books in your bags to hand in, then the ones still to
-- find, with their zone; clicking one shows it on the map.
function ns.LibraryLines()
    local list, handed, bags = Books()
    if handed >= RING then
        return {}
    end
    local lines = { { block = true, color = { r = 1, g = 1, b = 1 },
        text = ("Handed in %d, %d in your bags"):format(handed, bags) } }
    for _, entry in ipairs(list) do
        local book = entry.book
        if entry.state == IN_BAGS then
            lines[#lines + 1] = { color = ns.active, text = ns.WAIT .. " " .. book.name,
                tooltip = function(tooltip)
                    tooltip:SetText(book.name, 1, 1, 1)
                    tooltip:AddLine("In your bags: hand it in to " .. Librarian().name, ns.grey.r, ns.grey.g, ns.grey.b)
                end }
        end
    end
    for _, entry in ipairs(list) do
        local book = entry.book
        if entry.state == MISSING then
            lines[#lines + 1] = { color = ns.missing,
                text = ("%s %s %s(%s)|r"):format(ns.CROSS, book.name, ns.grey.hex, MapName(book.map)),
                onClick = function()
                    if ns.ShowOnMap then
                        ns.ShowOnMap({ map = book.map, x = book.x, y = book.y, name = book.name, itemID = book.item })
                    end
                end,
                tooltip = function(tooltip)
                    tooltip:SetText(book.name, 1, 1, 1)
                    tooltip:AddLine(book.where, ns.grey.r, ns.grey.g, ns.grey.b, true)
                    tooltip:AddLine("Click to show on the map", ns.grey.r, ns.grey.g, ns.grey.b)
                end }
        end
    end
    return lines
end

--------------------------------------------------------------------------------
-- The list on the options window's Library tab
--------------------------------------------------------------------------------

local page -- { child, text }

function ns.BuildLibraryList(parent, y)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -y)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    local text = child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 4, 0)
    text:SetPoint("RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)
    scroll:SetScript("OnSizeChanged", function(_, width)
        child:SetWidth(width)
        ns.RefreshLibraryList()
    end)
    page = { child = child, text = text }
    ns.RefreshLibraryList()
    return 0 -- it fills the rest of the page
end

function ns.RefreshLibraryList()
    if not page or not page.child:IsVisible() then
        return
    end
    local list, handed, bags = Books()
    local librarian = Librarian()
    local lines = {
        "Handed in " .. Progress(handed),
        ("%sHand them in to %s, %s.|r"):format(ns.grey.hex, librarian.name, librarian.where),
    }
    if bags > 0 then
        lines[#lines + 1] = ("%s%d in your bags to hand in.|r"):format(ns.active.hex, bags)
    end
    for _, entry in ipairs(list) do
        local book = entry.book
        local zone = ns.grey.hex .. MapName(book.map) .. (book.level and (", level " .. book.level) or "") .. "|r"
        local line
        if entry.state == HANDED_IN then
            line = ("%s %s%s|r"):format(ns.CHECK, ns.known.hex, book.name)
        elseif entry.state == IN_BAGS then
            line = ("%s %s%s|r  %sin your bags|r"):format(ns.WAIT, ns.active.hex, book.name, ns.grey.hex)
        else
            line = ("%s %s%s|r  %s"):format(ns.CROSS, ns.missing.hex, book.name, zone)
        end
        lines[#lines + 1] = (#lines == (bags > 0 and 3 or 2) and " \n" or "") .. line
    end
    page.text:SetText(table.concat(lines, "\n"))
    page.child:SetHeight(page.text:GetStringHeight() + 4)
end

-- A book looted or handed in: the pins, the tracker and the list follow.
local frame = CreateFrame("Frame")
pcall(frame.RegisterEvent, frame, "BAG_UPDATE_DELAYED") -- see Core.lua
pcall(frame.RegisterEvent, frame, "QUEST_TURNED_IN")
frame:SetScript("OnEvent", function()
    if ns.RefreshMapPins then
        ns.RefreshMapPins()
    end
    if ns.RefreshTracker then
        ns.RefreshTracker()
    end
    ns.RefreshLibraryList()
end)
