--------------------------------------------------------------------------------
-- Sink / Recipes.lua
--
-- Shows, on a vendor's tooltip, which recipes that vendor sells and whether you
-- already know each one (green check) or not (red cross). The recipe item's own
-- tooltip gets a "sold by" line in return.
--
-- "Known" comes from the recipe item's tooltip data: a recipe you have learned
-- carries the red "Already known" line. That works for every profession and
-- needs no profession window open. When the item is not in the client's cache
-- yet, the line shows as loading, the data is requested, and the next hover
-- has the answer.
--
-- Opening any merchant window does two more things: recipes sold there that
-- you do not know are pointed out once per vendor per session, and the vendor's
-- recipes are remembered so "/sink recipes missing" can list every purchasable
-- recipe you still lack, in a small window.
--------------------------------------------------------------------------------

local ADDON_NAME, ns = ...

-- Built-in vendors: npcID -> { name, location, recipes = { itemID, ... } }.
-- Vendors added with "/sink recipes add" live in SinkDB.recipeVendors and are
-- merged with these.
ns.recipeVendors = {
    [2118] = { name = "Abigail Shiel", location = "Brill, Tirisfal Glades", recipes = { 12226 } },
    [3550] = { name = "Martine Tramblay", location = "Brill, Tirisfal Glades", recipes = { 6325 } },
}

local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t"
local CROSS = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14|t"
local WAIT = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14:14|t"
local KNOWN_TEXT = ITEM_SPELL_KNOWN or "Already known"

local function Enabled()
    return ns.db ~= nil and ns.db.recipeTooltips ~= false
end

local function CustomVendors()
    return ns.db and ns.db.recipeVendors or nil
end

-- Merged view of one vendor: the built-in entry plus anything added in game.
local function VendorInfo(npcID)
    local builtin = ns.recipeVendors[npcID]
    local custom = CustomVendors()
    custom = custom and custom[npcID]
    if not builtin and not custom then
        return nil
    end

    local info = {
        name = (builtin and builtin.name) or (custom and custom.name) or ("NPC #" .. npcID),
        location = (builtin and builtin.location) or (custom and custom.location),
        recipes = {},
    }
    local seen = {}
    local function add(list)
        for _, itemID in ipairs(list or {}) do
            if not seen[itemID] then
                seen[itemID] = true
                info.recipes[#info.recipes + 1] = itemID
            end
        end
    end
    add(builtin and builtin.recipes)
    add(custom and custom.recipes)
    return info
end

-- Calls fn(npcID, info) for every vendor, lowest NPC ID first.
local function EachVendor(fn)
    local ids, seen = {}, {}
    for npcID in pairs(ns.recipeVendors) do
        seen[npcID] = true
        ids[#ids + 1] = npcID
    end
    for npcID in pairs(CustomVendors() or {}) do
        if not seen[npcID] then
            ids[#ids + 1] = npcID
        end
    end
    table.sort(ids)
    for _, npcID in ipairs(ids) do
        fn(npcID, VendorInfo(npcID))
    end
end

local function ItemName(itemID)
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    return name or ("item #" .. itemID)
end

local function LineText(line)
    if line.leftText then
        return line.leftText
    end
    -- 10.0.2-style tooltip data keeps the fields in an args list.
    for _, arg in ipairs(line.args or {}) do
        if arg.field == "leftText" then
            return arg.stringVal
        end
    end
    return nil
end
ns.TooltipLineText = LineText

-- true = known, false = not known, nil = item data not cached yet.
local function RecipeKnown(itemID)
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
        if ok and data and data.lines then
            for _, line in ipairs(data.lines) do
                if LineText(line) == KNOWN_TEXT then
                    return true
                end
            end
            return false
        end
    end

    -- Fallback: the spell the recipe teaches.
    if C_Item.GetItemSpell then
        local _, spellID = C_Item.GetItemSpell(itemID)
        if spellID then
            return (IsPlayerSpell and IsPlayerSpell(spellID)) or (IsSpellKnown and IsSpellKnown(spellID)) or false
        end
    end

    if C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return nil
end
ns.RecipeKnown = RecipeKnown

local function NPCIDFromGUID(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end
ns.NPCIDFromGUID = NPCIDFromGUID

local function TooltipUsable(tooltip)
    if not Enabled() or not tooltip or not tooltip.AddLine then
        return false
    end
    if tooltip.IsForbidden and tooltip:IsForbidden() then
        return false
    end
    return true
end

--------------------------------------------------------------------------------
-- Tooltip lines
--------------------------------------------------------------------------------

-- "Recipes sold here" plus one line per recipe, on any tooltip. The map icons
-- in MapPins.lua use it too. Returns true when lines were added.
local function AddVendorLines(tooltip, npcID)
    if not Enabled() then
        return false
    end
    local vendor = npcID and VendorInfo(npcID)
    if not vendor or #vendor.recipes == 0 then
        return false
    end

    tooltip:AddLine("Sink: recipes sold here", ns.accent.r, ns.accent.g, ns.accent.b)
    for _, itemID in ipairs(vendor.recipes) do
        local known = RecipeKnown(itemID)
        if known == true then
            tooltip:AddLine(CHECK .. " " .. ItemName(itemID), 0.6, 0.6, 0.6)
        elseif known == false then
            tooltip:AddLine(CROSS .. " " .. ItemName(itemID), 1.0, 0.4, 0.4)
        else
            tooltip:AddLine(WAIT .. " " .. ItemName(itemID) .. " (loading)", 0.8, 0.8, 0.8)
        end
    end
    return true
end
ns.AddRecipeVendorLines = AddVendorLines

-- Vendor tooltip: one line per recipe.
local function AddUnitTooltipLines(tooltip, data)
    if not TooltipUsable(tooltip) then
        return
    end
    local guid = data and data.guid
    if not guid and tooltip.GetUnit then
        local _, unit = tooltip:GetUnit()
        guid = unit and UnitGUID(unit)
    end
    AddVendorLines(tooltip, NPCIDFromGUID(guid))
end

-- Recipe item tooltip: who sells it.
local function AddItemTooltipLines(tooltip, data)
    if not TooltipUsable(tooltip) then
        return
    end
    local itemID = data and data.id
    if not itemID then
        return
    end
    local sellers = {}
    EachVendor(function(_, info)
        for _, id in ipairs(info.recipes) do
            if id == itemID then
                sellers[#sellers + 1] = info.location and (info.name .. " (" .. info.location .. ")") or info.name
            end
        end
    end)
    if #sellers > 0 then
        tooltip:AddLine("Sink: sold by " .. table.concat(sellers, ", "), ns.accent.r, ns.accent.g, ns.accent.b, true)
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    if Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddUnitTooltipLines)
    end
    if Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddItemTooltipLines)
    end
end

--------------------------------------------------------------------------------
-- Merchant windows: remember what a vendor sells, point out what you lack
--------------------------------------------------------------------------------

local RECIPE_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or 9
local remindedVendors = {}   -- npcID (or vendor name) -> true once reminded this session

local function IsRecipeItem(itemID)
    if not C_Item.GetItemInfoInstant then
        return false
    end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    return classID == RECIPE_CLASS
end

-- Recipes the open merchant sells, as a list of { itemID = ..., link = ... }.
local function MerchantRecipes()
    local recipes = {}
    local count = GetMerchantNumItems and GetMerchantNumItems() or 0
    for index = 1, count do
        local itemID = GetMerchantItemID and GetMerchantItemID(index)
        local link = GetMerchantItemLink and GetMerchantItemLink(index)
        if not itemID and link and C_Item.GetItemInfoInstant then
            itemID = C_Item.GetItemInfoInstant(link)
        end
        if itemID and IsRecipeItem(itemID) then
            recipes[#recipes + 1] = { itemID = itemID, link = link }
        end
    end
    return recipes
end

-- Save the vendor's recipes so they show in /sink recipes and the missing list.
local function RememberVendor(npcID, name, recipes)
    ns.db.recipeVendors = ns.db.recipeVendors or {}
    local entry = ns.db.recipeVendors[npcID] or {}
    entry.name = entry.name or name
    entry.recipes = entry.recipes or {}

    local seen = {}
    for _, id in ipairs(entry.recipes) do
        seen[id] = true
    end
    local builtin = ns.recipeVendors[npcID]
    for _, id in ipairs(builtin and builtin.recipes or {}) do
        seen[id] = true -- the built-in entry already lists it
    end

    for _, recipe in ipairs(recipes) do
        if not seen[recipe.itemID] then
            seen[recipe.itemID] = true
            entry.recipes[#entry.recipes + 1] = recipe.itemID
        end
    end
    if #entry.recipes > 0 then
        ns.db.recipeVendors[npcID] = entry
    end
end

local function OnMerchantShow()
    if not Enabled() or not ns.db then
        return
    end
    local recipes = MerchantRecipes()
    if #recipes == 0 then
        return
    end

    local npcID = NPCIDFromGUID(UnitGUID and UnitGUID("npc"))
    local name = UnitName and UnitName("npc") or nil
    if npcID then
        RememberVendor(npcID, name, recipes)
    end

    local key = npcID or name
    if not key or remindedVendors[key] then
        return
    end
    local missing = {}
    for _, recipe in ipairs(recipes) do
        if RecipeKnown(recipe.itemID) == false then
            missing[#missing + 1] = recipe.link or ItemName(recipe.itemID)
        end
    end
    if #missing > 0 then
        remindedVendors[key] = true
        ns.Print("recipes sold here that you do not know: " .. table.concat(missing, ", ")
            .. ". /sink recipes missing lists every one.")
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(#missing .. (#missing == 1 and " recipe" or " recipes") .. " to buy here", 1.0, 0.82, 0.0)
        end
    end
end

--------------------------------------------------------------------------------
-- Missing recipes list
--------------------------------------------------------------------------------

-- Every listed recipe you do not know (or that is not cached yet), by vendor.
local function MissingRecipes()
    local rows = {}
    EachVendor(function(_, info)
        for _, itemID in ipairs(info.recipes) do
            local known = RecipeKnown(itemID)
            if known ~= true then
                rows[#rows + 1] = {
                    itemID = itemID, name = ItemName(itemID), known = known,
                    vendor = info.name, location = info.location,
                }
            end
        end
    end)
    table.sort(rows, function(a, b)
        if a.vendor ~= b.vendor then
            return a.vendor < b.vendor
        end
        return a.name < b.name
    end)
    return rows
end

local function MissingLines()
    local rows = MissingRecipes()
    if #rows == 0 then
        return { "Nothing to buy: you know every listed recipe." }
    end
    local lines, lastVendor = {}, nil
    for _, row in ipairs(rows) do
        if row.vendor ~= lastVendor then
            lastVendor = row.vendor
            lines[#lines + 1] = ns.Accent(row.vendor) .. (row.location and ("  |cff999999" .. row.location .. "|r") or "")
        end
        lines[#lines + 1] = "    " .. (row.known == false and CROSS or WAIT) .. " " .. row.name
    end
    return lines
end
ns.MissingRecipeLines = MissingLines

local listFrame

local function CreateListFrame()
    local frame = CreateFrame("Frame", "SinkRecipeListFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(380, 120)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local title = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText
    if title then
        title:SetText(ns.Accent("Sink") .. ": recipes to buy")
    end

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 16, -32)
    text:SetPoint("RIGHT", -16, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    frame.Text = text

    if UISpecialFrames then
        table.insert(UISpecialFrames, "SinkRecipeListFrame") -- Escape closes it
    end
    return frame
end

local function ShowMissingList()
    if not listFrame then
        local ok, result = pcall(CreateListFrame)
        if not ok then
            ns.Print("could not create the list window (" .. tostring(result) .. "); listing in chat instead.")
            for _, line in ipairs(MissingLines()) do
                print("  " .. line)
            end
            return
        end
        listFrame = result
    end
    local lines = MissingLines()
    listFrame.Text:SetText(table.concat(lines, "\n"))
    local textHeight = listFrame.Text.GetStringHeight and listFrame.Text:GetStringHeight() or (#lines * 14)
    listFrame:SetHeight(math.max(100, textHeight + 50))
    listFrame:Show()
end
ns.ShowMissingRecipes = ShowMissingList

local function RefreshListIfShown()
    if listFrame and listFrame:IsShown() then
        ShowMissingList()
    end
end

--------------------------------------------------------------------------------
-- /sink recipes ...
--------------------------------------------------------------------------------

local function RecipesHelp()
    ns.Print("recipe vendor commands")
    print("  /sink recipes                         list vendors and which recipes you know")
    print("  /sink recipes add <itemID> [npcID]    add a recipe to a vendor (default: your target)")
    print("  /sink recipes remove <itemID> [npcID] remove a recipe you added")
    print("  /sink recipes missing                 window listing recipes you can buy but do not know")
    print("  /sink recipes on | off                turn the tooltip lines on or off")
end

local function TargetNPC()
    if not (UnitExists and UnitExists("target")) then
        return nil, nil
    end
    local npcID = NPCIDFromGUID(UnitGUID("target"))
    if not npcID then
        return nil, nil
    end
    return npcID, UnitName("target")
end

local function ListVendors()
    local any = false
    EachVendor(function(npcID, info)
        any = true
        print(("  %s (%d)%s"):format(info.name, npcID, info.location and (", " .. info.location) or ""))
        for _, itemID in ipairs(info.recipes) do
            local known = RecipeKnown(itemID)
            local mark = (known == true and CHECK) or (known == false and CROSS) or WAIT
            print(("    %s %s (%d)"):format(mark, ItemName(itemID), itemID))
        end
    end)
    if not any then
        ns.Print("no recipe vendors. Target a vendor and use /sink recipes add <itemID>.")
    end
end

function ns.RecipesCommand(arg)
    if not ns.db then
        return
    end
    ns.db.recipeVendors = ns.db.recipeVendors or {}
    local vendors = ns.db.recipeVendors
    local sub, a, b = (arg or ""):match("^(%S*)%s*(%S*)%s*(%S*)")
    sub = sub:lower()

    if sub == "" or sub == "list" then
        ListVendors()
    elseif sub == "add" or sub == "remove" then
        local itemID = tonumber(a)
        local npcID, npcName = tonumber(b), nil
        if not npcID then
            npcID, npcName = TargetNPC()
        end
        if not itemID or not npcID then
            ns.Print("usage: /sink recipes " .. sub .. " <itemID> [npcID], or target the vendor and leave the NPC ID out")
            return
        end

        if sub == "add" then
            local entry = vendors[npcID] or {}
            entry.recipes = entry.recipes or {}
            entry.name = entry.name or npcName
            for _, id in ipairs(entry.recipes) do
                if id == itemID then
                    ns.Print(ItemName(itemID) .. " is already listed for that vendor.")
                    return
                end
            end
            entry.recipes[#entry.recipes + 1] = itemID
            vendors[npcID] = entry
            ns.Print(("%s now lists %s."):format(VendorInfo(npcID).name, ItemName(itemID)))
        else
            local name = (VendorInfo(npcID) or {}).name or ("NPC #" .. npcID)
            local entry = vendors[npcID]
            local removed = false
            if entry and entry.recipes then
                for i = #entry.recipes, 1, -1 do
                    if entry.recipes[i] == itemID then
                        table.remove(entry.recipes, i)
                        removed = true
                    end
                end
                if #entry.recipes == 0 then
                    vendors[npcID] = nil
                end
            end
            if removed then
                ns.Print("removed " .. ItemName(itemID) .. " from " .. name .. ".")
            else
                ns.Print("only recipes added in game can be removed; built-in ones live in Recipes.lua.")
            end
        end
    elseif sub == "missing" then
        ShowMissingList()
    elseif sub == "on" or sub == "off" then
        ns.db.recipeTooltips = (sub == "on")
        ns.Print("recipe tooltips " .. (sub == "on" and "|cff00ff00on|r" or "|cffff0000off|r") .. ".")
    else
        RecipesHelp()
    end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
-- The Forever beta throws on unknown event names; see Core.lua.
pcall(frame.RegisterEvent, frame, "MERCHANT_SHOW")
pcall(frame.RegisterEvent, frame, "MERCHANT_UPDATE")
pcall(frame.RegisterEvent, frame, "NEW_RECIPE_LEARNED")

frame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        OnMerchantShow()
        RefreshListIfShown()
    elseif event == "NEW_RECIPE_LEARNED" then
        RefreshListIfShown()
    end
end)
