--------------------------------------------------------------------------------
-- Sink / QuestItems.lua
--
-- Warns when a quest item is still in your bags after the quest that needed it
-- is complete, and offers to delete it.
--
-- Three layers, quiet to loud:
--   1. A tooltip line on the item: yellow "Safe to delete, quest complete"
--      once the quest is done, grey "Keep until ..." before that.
--   2. A chat line plus a short on-screen notice when the item is spotted in
--      the bags after the quest is complete.
--   3. A popup with Delete / Keep, once per item per session.
--   Plus a red tint on the item's bag slot for as long as it is safe to delete.
--
-- The bag check runs after a quest turn-in, on login, and whenever the bags
-- change, so an item looted late is caught too. Nothing is shown in combat;
-- the check waits for PLAYER_REGEN_ENABLED instead.
--------------------------------------------------------------------------------

local ADDON_NAME, ns = ...

-- Built-in rules: itemID -> questID, or itemID -> { questID, questID, ... } when
-- every listed quest must be complete. Rules added with "/sink items add" live
-- in SinkDB.questItems and take priority over these.
ns.questItemRules = {
    [286176] = 99134,
}

local POPUP = "SINK_QUEST_ITEM_SAFE_TO_DELETE"
local warned = {}          -- itemID -> true once warned this session
local scanQueued = false
local scanAfterCombat = false
local scanForceAfterCombat = false

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

local function QuestNames(rule)
    local names = {}
    for _, questID in ipairs(QuestIDs(rule)) do
        names[#names + 1] = QuestName(questID)
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

    if ok and not CursorHasItem() then
        ns.Print("deleted " .. ItemName(itemID, link) .. ".")
    else
        ClearCursor()
        ns.Print("could not delete " .. ItemName(itemID, link) .. (err and (" (" .. tostring(err) .. ")") or "")
            .. ". Drag it out of your bags to destroy it.")
    end
end

StaticPopupDialogs[POPUP] = {
    text = "%s is no longer needed.\n%s is complete.\n\nDelete it?",
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

local function Warn(itemID, rule, link)
    warned[itemID] = true
    local item = ItemName(itemID, link)
    local quests = QuestNames(rule)

    ns.Print(item .. " is safe to delete: " .. quests .. " is complete. Type /sink items to review.")
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(item .. " is safe to delete (" .. quests .. " complete)", 1.0, 0.82, 0.0)
    end
    StaticPopup_Show(POPUP, item, quests, { itemID = itemID })
end

-- Check every rule against the bags. With force, warn again even if this
-- session already did.
local function Scan(force)
    if not Enabled() then
        return
    end
    if InCombatLockdown() then
        scanAfterCombat = true
        if force then
            scanForceAfterCombat = true
        end
        return
    end
    EachRule(function(itemID, rule)
        if (force or not warned[itemID]) and QuestsComplete(rule) then
            local bag, _, link = FindInBags(itemID)
            if bag then
                Warn(itemID, rule, link)
            end
        end
    end)
    RefreshBagOverlays()
end
ns.ScanQuestItems = Scan

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
    if QuestsComplete(rule) then
        tooltip:AddLine("Safe to delete, quest complete", 1.0, 0.82, 0.0, true)
    else
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
    print("  /sink items scan                  re-check the bags and show the popup again")
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
        warned[itemID] = nil
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
        RefreshBagOverlays()
    elseif sub == "scan" then
        Scan(true)
        ListRules()
    elseif sub == "on" or sub == "off" then
        ns.db.questItemWarnings = (sub == "on")
        ns.Print("quest item warnings " .. (sub == "on" and "|cff00ff00on|r" or "|cffff0000off|r") .. ".")
        RefreshBagOverlays()
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
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
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
    elseif event == "PLAYER_REGEN_ENABLED" then
        if scanAfterCombat then
            local force = scanForceAfterCombat
            scanAfterCombat, scanForceAfterCombat = false, false
            Scan(force)
        end
    end
end)
