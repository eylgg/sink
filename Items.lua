--------------------------------------------------------------------------------
-- Sink / Items.lua
--
-- The Items tab of the options window: every item Sink knows about, gathered
-- from the tables in the other files, with a search box. A row is the item's
-- icon and name in its quality colour, with a check or cross for a recipe
-- you know or not, and under it in grey what Sink knows: what it is used
-- for, what it teaches, who sells it, which quest wants it or it starts, or
-- a note on why to keep it.
-- Hovering a row shows the item's own tooltip, Sink's lines included;
-- shift-click links it in chat, as from the bags. The search matches the
-- name, those grey lines or an item ID.
--
-- Only what is for your faction is listed: a quest of the other faction adds
-- nothing, like the lists elsewhere.
--------------------------------------------------------------------------------

local _, ns = ...

local QUEST = "|cffffff00" -- the yellow of quest links
local RECIPE_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or 9

local function ForMyFaction(faction)
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    return not faction or faction == "Both" or not mine or faction == mine
end

local function SpellName(spellID)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    return name or ("spell #" .. spellID)
end

-- A quest's title in quest yellow, with its step in a series: "Hidden Enemies (2/5)".
local function QuestText(questID)
    local title = ns.QuestTitle and ns.QuestTitle(questID) or ("quest #" .. questID)
    local step = ns.QuestSeriesSuffix and ns.QuestSeriesSuffix(questID)
    return QUEST .. title .. (step and (" " .. step) or "") .. "|r"
end

-- itemID -> { fact, ... }: what each table says about the items in it.
-- Built fresh each time; the tables are small.
local function Collect()
    local items = {}
    local function add(itemID, fact)
        items[itemID] = items[itemID] or {}
        table.insert(items[itemID], fact)
    end

    -- Reagents, and the recipe items that teach what they make (Professions.lua).
    for itemID, uses in pairs(ns.reagents or {}) do
        local made = {}
        for _, use in ipairs(uses) do
            if ForMyFaction(use.faction) then
                made[#made + 1] = ("%s (%s)"):format(SpellName(use.spell), use.profession)
                if use.recipe then
                    add(use.recipe, ("Teaches %s (%s)%s"):format(SpellName(use.spell), use.profession,
                        use.quest and (", a reward from " .. QuestText(use.quest)) or ""))
                end
            end
        end
        if #made > 0 then
            add(itemID, "Used for " .. table.concat(made, ", "))
        end
    end

    -- Recipes vendors sell (Recipes.lua), built-in and recorded in game.
    if ns.EachRecipeVendor then
        local sellers = {}
        ns.EachRecipeVendor(function(_, info)
            for _, itemID in ipairs(info.recipes) do
                sellers[itemID] = sellers[itemID] or {}
                table.insert(sellers[itemID], info.location and (info.name .. " (" .. info.location .. ")") or info.name)
            end
        end)
        for itemID, list in pairs(sellers) do
            add(itemID, "Sold by " .. table.concat(list, ", "))
        end
    end

    -- Quest items to keep and then delete (QuestItems.lua).
    if ns.EachQuestItemRule then
        ns.EachQuestItemRule(function(itemID, rule)
            local verb = ns.QuestItemRuleComplete(rule) and "Done with " or "Needed for "
            add(itemID, verb .. ns.QuestItemQuestNames(rule, QUEST))
        end)
    end

    -- Library books (Library.lua).
    for _, book in ipairs(ns.libraryBooks or {}) do
        if ForMyFaction(book.faction) then
            add(book.item, "Library book: " .. book.where)
        end
    end

    -- Items to keep, with their note (QuestItems.lua).
    for itemID, note in pairs(ns.itemNotes or {}) do
        add(itemID, note)
    end

    -- Items that start a quest, and items a quest sends you to an NPC for (Quests.lua).
    for questID, quest in pairs(ns.quests or {}) do
        if ForMyFaction(quest.faction) then
            local start = quest.start or {}
            if start.item then
                local dungeon = quest.dungeon and ns.dungeons[quest.dungeon]
                add(start.item, "Starts " .. QuestText(questID)
                    .. (dungeon and (", in " .. ns.dungeonColor.hex .. dungeon.name .. "|r") or ""))
            end
            for _, objective in ipairs(ns.QuestObjectiveNPCs and ns.QuestObjectiveNPCs(quest) or {}) do
                if objective.item then
                    local npc = ns.npcs[objective.npc]
                    add(objective.item, ("For %s, from %s"):format(QuestText(questID), npc and npc.name or "an NPC"))
                end
            end
        end
    end
    return items
end

local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- The items matching the search, by name: { { itemID, name, facts } }. An
-- item whose name is not cached yet is asked for, and listed by its ID until
-- it comes.
local function Rows(query)
    query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local rows = {}
    for itemID, facts in pairs(Collect()) do
        local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
        if not name and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
        local match = query == "" or tostring(itemID) == query
            or (name and name:lower():find(query, 1, true))
            or Plain(table.concat(facts, "\n")):lower():find(query, 1, true)
        if match then
            rows[#rows + 1] = { itemID = itemID, name = name or ("item #" .. itemID), facts = facts }
        end
    end
    table.sort(rows, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.itemID < b.itemID
    end)
    return rows
end

--------------------------------------------------------------------------------
-- The list on the options window's Items tab
--------------------------------------------------------------------------------

local list -- { search, child, rows, empty }

-- Builds the search box and the list at y on the page and returns the
-- height it takes: the list scrolls and fills the rest of the page.
function ns.BuildItemList(page, y)
    local ok, search = pcall(CreateFrame, "EditBox", nil, page, "SearchBoxTemplate")
    if not ok then
        search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    end
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", 10, -y)
    search:SetPoint("RIGHT", -24, 0)
    search:SetAutoFocus(false)
    if search.Instructions then
        search.Instructions:SetText("Name, item ID or what it is for")
    end
    search:HookScript("OnTextChanged", function()
        ns.RefreshItemList()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -(y + 30))
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(_, width)
        child:SetWidth(width)
        ns.RefreshItemList() -- the rows' heights follow the width their text wraps at
    end)
    local empty = child:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 4, 0)
    empty:SetPoint("RIGHT", -4, 0)
    empty:SetJustifyH("LEFT")
    list = { search = search, child = child, rows = {}, empty = empty }
    ns.RefreshItemList()
    return 0 -- it fills the rest of the page
end

-- The nth row, made the first time it is needed.
local function Row(n)
    local row = list.rows[n]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, list.child)
    row:SetPoint("RIGHT")
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("TOPLEFT", 4, -4)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("RIGHT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.facts = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.facts:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.facts:SetPoint("RIGHT", -4, 0)
    row.facts:SetJustifyH("LEFT")
    row.facts:SetWordWrap(true)
    row.facts:SetSpacing(2)
    row.facts:SetTextColor(ns.grey.r + 0.2, ns.grey.g + 0.2, ns.grey.b + 0.2)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    -- Shift-click links it in chat, control-click tries it on, as from the bags.
    row:SetScript("OnClick", function(self)
        local _, link = C_Item.GetItemInfo(self.itemID)
        if link and HandleModifiedItemClick then
            HandleModifiedItemClick(link)
        end
    end)
    list.rows[n] = row
    return row
end

-- The name in its quality colour, after a check or cross for a recipe you know or not.
local function NameText(row)
    local name = row.name
    local quality = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(row.itemID)
    if quality and C_Item.GetItemQualityColor then
        local _, _, _, hex = C_Item.GetItemQualityColor(quality)
        if hex then
            name = "|c" .. hex .. name .. "|r"
        end
    end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(row.itemID)
    if classID == RECIPE_CLASS and ns.RecipeKnown then
        local known = ns.RecipeKnown(row.itemID)
        if known ~= nil then
            name = (known and ns.CHECK or ns.CROSS) .. " " .. name
        end
    end
    return name
end

function ns.RefreshItemList()
    if not list or not list.child:IsVisible() then
        return
    end
    local rows = Rows(list.search:GetText())
    local y = 0
    for n, entry in ipairs(rows) do
        local row = Row(n)
        row.itemID = entry.itemID
        row:SetPoint("TOPLEFT", 0, -y)
        row.icon:SetTexture(C_Item.GetItemIconByID(entry.itemID))
        row.name:SetText(NameText(entry))
        row.facts:SetText(table.concat(entry.facts, "\n"))
        local height = math.max(36, 4 + row.name:GetStringHeight() + 3 + row.facts:GetStringHeight() + 6)
        row:SetHeight(height)
        row:Show()
        y = y + height
    end
    for n = #rows + 1, #list.rows do
        list.rows[n]:Hide()
    end
    list.empty:SetText(list.search:GetText() == "" and "Sink knows no items yet." or "No item matches.")
    list.empty:SetShown(#rows == 0)
    list.child:SetHeight(math.max(y, list.empty:GetStringHeight()) + 4)
end

-- An item's name arriving from the server: redraw, once for however many come in together.
local pending = false
local frame = CreateFrame("Frame")
pcall(frame.RegisterEvent, frame, "ITEM_DATA_LOAD_RESULT") -- see Core.lua
pcall(frame.RegisterEvent, frame, "GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function()
    if list and list.child:IsVisible() and not pending then
        pending = true
        C_Timer.After(0.2, function()
            pending = false
            ns.RefreshItemList()
        end)
    end
end)
