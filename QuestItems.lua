--------------------------------------------------------------------------------
-- Sink / QuestItems.lua
--
-- Marks quest items that are still in your bags after the quest that needed
-- them is complete. Nothing pops up or prints on its own:
--   * a grey "Keep until ..." line on the item's tooltip while its quest is
--     not done yet;
--   * a red tint on the item's bag slot while it is safe to delete;
--   * the Items to Delete section of the Sink tracker lists them, and clicking
--     one asks Delete / Keep before destroying it.
--
-- The bags are checked after a quest turn-in, on login, and whenever they
-- change, so an item looted late is caught too.
--------------------------------------------------------------------------------

local ADDON_NAME, ns = ...

-- Built-in rules: itemID -> questID, or itemID -> { questID, questID, ... } when
-- every listed quest must be complete. Rules added with "/sink items add" live
-- in SinkDB.questItems and take priority over these.
ns.questItemRules = {
    [286176] = 99134,
    [279023] = 97891, -- Inert Potion, Prompt Potion Runner (Undercity)
}

local POPUP = "SINK_QUEST_ITEM_SAFE_TO_DELETE"
local scanQueued = false

local function Enabled()
    return ns.db ~= nil and ns.db.questItemWarnings ~= false
end

local function CustomRules()
    return ns.db and ns.db.questItems or nil
end

local function RuleFor(itemID)
    local custom = CustomRules()
    if custom and custom[itemID] ~= nil then
        return custom[itemID]
    end
    return ns.questItemRules[itemID]
end

-- Calls fn(itemID, rule) for every rule: custom ones first, then built-in ones
-- that are not overridden.
local function EachRule(fn)
    local seen = {}
    local custom = CustomRules()
    if custom then
        for itemID, rule in pairs(custom) do
            seen[itemID] = true
            fn(itemID, rule)
        end
    end
    for itemID, rule in pairs(ns.questItemRules) do
        if not seen[itemID] then
            fn(itemID, rule)
        end
    end
end

local function QuestIDs(rule)
    if type(rule) == "table" then
        return rule
    end
    return { rule }
end

local function QuestsComplete(rule)
    for _, questID in ipairs(QuestIDs(rule)) do
        if not C_QuestLog.IsQuestFlaggedCompleted(questID) then
            return false
        end
    end
    return true
end

local function QuestName(questID)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    if title and title ~= "" then
        return title
    end
    -- Not cached yet; ask the server so the next call has it.
    if C_QuestLog.RequestLoadQuestByID then
        C_QuestLog.RequestLoadQuestByID(questID)
    end
    return "quest #" .. questID
end

-- The rule's quest names joined with commas; with color, each wrapped in it.
local function QuestNames(rule, color)
    local names = {}
    for _, questID in ipairs(QuestIDs(rule)) do
        local name = QuestName(questID)
        names[#names + 1] = color and (color .. name .. "|r") or name
    end
    return table.concat(names, ", ")
end

local function ItemName(itemID, link)
    if link then
        return link
    end
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    return name or ("item #" .. itemID)
end

-- Returns bag, slot, link, stackCount for the first stack of itemID in the bags.
local function FindInBags(itemID)
    local firstBag = BACKPACK_CONTAINER or 0
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = firstBag, lastBag do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            if C_Container.GetContainerItemID(bag, slot) == itemID then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                return bag, slot, info and info.hyperlink, info and info.stackCount
            end
        end
    end
    return nil
end

-- Destroys the item the same way dragging it out of the bags does.
local function DeleteItem(itemID)
    local bag, slot, link = FindInBags(itemID)
    if not bag then
        ns.Print(ItemName(itemID) .. " is not in your bags any more.")
        return
    end

    local ok, err = pcall(function()
        ClearCursor()
        C_Container.PickupContainerItem(bag, slot)
        if not CursorHasItem() then
            error("could not pick the item up", 0)
        end
        DeleteCursorItem()
    end)

    if not (ok and not CursorHasItem()) then
        ClearCursor()
        ns.Print("could not delete " .. ItemName(itemID, link) .. (err and (" (" .. tostring(err) .. ")") or "")
            .. ". Drag it out of your bags to destroy it.")
    end
end

StaticPopupDialogs[POPUP] = {
    text = "Delete %s?\n\nYou finished %s and no longer need it.",
    button1 = DELETE or "Delete",
    button2 = "Keep",
    OnAccept = function(_, data)
        DeleteItem(data.itemID)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3, -- avoid taint on the first popup frames used by Blizzard
}

--------------------------------------------------------------------------------
-- Red tint on bag slots
--------------------------------------------------------------------------------

local hookedBagFrames = {}

local function ShouldTint(itemID)
    if not Enabled() or not itemID then
        return false
    end
    local rule = RuleFor(itemID)
    return rule ~= nil and QuestsComplete(rule)
end

-- One overlay texture per bag button, created on first use and reused. Buttons
-- are pooled and reused for other slots, so every update sets the state.
local function UpdateButtonTint(itemButton)
    local itemID = C_Container.GetContainerItemID(itemButton:GetBagID(), itemButton:GetID())
    local overlay = itemButton.SinkOverlay
    if ShouldTint(itemID) then
        if not overlay then
            overlay = itemButton:CreateTexture(nil, "OVERLAY", nil, 1)
            overlay:SetAllPoints(itemButton.icon or itemButton)
            overlay:SetColorTexture(1, 0.1, 0.1, 0.45)
            itemButton.SinkOverlay = overlay
        end
        overlay:Show()
    elseif overlay then
        overlay:Hide()
    end
end

local function UpdateBagFrame(frame)
    if not frame.EnumerateValidItems then
        return
    end
    for _, itemButton in frame:EnumerateValidItems() do
        UpdateButtonTint(itemButton)
    end
end

-- Re-tint the open bags without going through Blizzard's own update.
local function RefreshBagOverlays()
    for frame in pairs(hookedBagFrames) do
        if frame:IsShown() then
            UpdateBagFrame(frame)
        end
    end
end
ns.RefreshBagOverlays = RefreshBagOverlays

-- The bag frames exist from the start, so hooking each one's UpdateItems is
-- enough. Only globals are read here: calling Blizzard's own frame enumerator
-- from addon code would taint the list it caches.
local function HookBagFrames()
    local frames = {}
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        frames[#frames + 1] = _G["ContainerFrame" .. i]
    end
    frames[#frames + 1] = ContainerFrameCombinedBags
    for _, frame in ipairs(frames) do
        if frame.UpdateItems and not hookedBagFrames[frame] then
            hookedBagFrames[frame] = true
            hooksecurefunc(frame, "UpdateItems", UpdateBagFrame)
        end
    end
end

-- The quest items in your bags whose quests are all complete, by name:
-- { { itemID, link, count, icon, quests }, ... }. The Sink tracker lists them.
function ns.DeletableQuestItems()
    local items = {}
    if not Enabled() then
        return items
    end
    EachRule(function(itemID, rule)
        if QuestsComplete(rule) then
            local bag, _, link, count = FindInBags(itemID)
            if bag then
                items[#items + 1] = { itemID = itemID, link = link, count = count or 1, quests = QuestNames(rule),
                    icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID) }
            end
        end
    end)
    table.sort(items, function(a, b)
        return ItemName(a.itemID) < ItemName(b.itemID)
    end)
    return items
end

-- Ask Delete / Keep for one item; the tracker calls it when the item is clicked.
function ns.ConfirmDeleteQuestItem(itemID)
    local rule = RuleFor(itemID)
    local _, _, link = FindInBags(itemID)
    if rule and link then
        -- Quest names in the yellow of quest links.
        StaticPopup_Show(POPUP, ItemName(itemID, link), QuestNames(rule, "|cffffff00"), { itemID = itemID })
    end
end

-- The bags or a quest changed: re-tint the slots and redraw the tracker.
local function Scan()
    RefreshBagOverlays()
    if ns.RefreshTracker then
        ns.RefreshTracker()
    end
end

-- Bag contents and quest flags settle a moment after the events fire.
local function QueueScan(delay)
    if scanQueued then
        return
    end
    scanQueued = true
    C_Timer.After(delay, function()
        scanQueued = false
        Scan()
    end)
end

local function IsTrackedQuest(questID)
    local found = false
    EachRule(function(_, rule)
        for _, id in ipairs(QuestIDs(rule)) do
            if id == questID then
                found = true
            end
        end
    end)
    return found
end

--------------------------------------------------------------------------------
-- Tooltip line
--------------------------------------------------------------------------------

local function AddTooltipLine(tooltip, data)
    if not Enabled() or not tooltip or not tooltip.AddLine then
        return
    end
    if tooltip.IsForbidden and tooltip:IsForbidden() then
        return
    end
    local itemID = data and data.id
    local rule = itemID and RuleFor(itemID)
    if not rule then
        return
    end
    -- Once the quest is done the slot's tint and the tracker say it; nothing is added here.
    if not QuestsComplete(rule) then
        tooltip:AddLine("Keep until " .. QuestNames(rule) .. " is complete", 0.7, 0.7, 0.7, true)
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddTooltipLine)
end

--------------------------------------------------------------------------------
-- /sink items ...
--------------------------------------------------------------------------------

local function ItemsHelp()
    ns.Print("quest item commands")
    print("  /sink items                       list rules with quest and bag status")
    print("  /sink items add <itemID> <questID> add a rule (saved per character)")
    print("  /sink items remove <itemID>       remove a rule you added")
    print("  /sink items on | off              turn the warnings on or off")
end

local function ListRules()
    local any = false
    EachRule(function(itemID, rule)
        any = true
        local bag, _, link, count = FindInBags(itemID)
        print(("  %s (%d): %s | %s"):format(
            ItemName(itemID, link), itemID,
            QuestsComplete(rule) and "|cff00ff00quest complete|r" or "|cffffcc00quest not complete|r",
            bag and ("in bags x" .. tostring(count or 1)) or "not in bags"))
    end)
    if not any then
        ns.Print("no quest item rules. Add one with /sink items add <itemID> <questID>.")
    end
end

function ns.QuestItemsCommand(arg)
    if not ns.db then
        return
    end
    ns.db.questItems = ns.db.questItems or {}
    local sub, a, b = (arg or ""):match("^(%S*)%s*(%S*)%s*(%S*)")
    sub = sub:lower()

    if sub == "" or sub == "list" or sub == "status" then
        ListRules()
    elseif sub == "add" then
        local itemID, questID = tonumber(a), tonumber(b)
        if not itemID or not questID then
            ns.Print("usage: /sink items add <itemID> <questID>")
            return
        end
        ns.db.questItems[itemID] = questID
        ns.Print(("rule added: %s is safe to delete once %s is complete."):format(ItemName(itemID), QuestName(questID)))
        Scan()
    elseif sub == "remove" then
        local itemID = tonumber(a)
        if not itemID or ns.db.questItems[itemID] == nil then
            ns.Print("usage: /sink items remove <itemID> (only rules added in game can be removed)")
            return
        end
        ns.db.questItems[itemID] = nil
        ns.Print("rule removed for " .. ItemName(itemID) .. ".")
        Scan()
    elseif sub == "on" or sub == "off" then
        if ns.SetOption then
            ns.SetOption("questItemWarnings", sub == "on")
        else
            ns.db.questItemWarnings = (sub == "on")
        end
        ns.Print("quest item warnings " .. (sub == "on" and "|cff00ff00on|r" or "|cffff0000off|r") .. ".")
        Scan()
    else
        ItemsHelp()
    end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- The Forever beta throws on unknown event names; see Core.lua.
pcall(frame.RegisterEvent, frame, "QUEST_TURNED_IN")
pcall(frame.RegisterEvent, frame, "BAG_UPDATE_DELAYED")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        HookBagFrames()
    elseif event == "PLAYER_ENTERING_WORLD" then
        QueueScan(2)
    elseif event == "QUEST_TURNED_IN" then
        if IsTrackedQuest(arg1) then
            QueueScan(1)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        QueueScan(0.5)
    end
end)
