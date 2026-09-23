--------------------------------------------------------------------------------
-- Sink / Quests.lua
--
-- Quest series: chains of quests that share a name, such as the five parts of
-- Unending Torment. The objective tracker shows where each one sits in its
-- chain by adding "(2/5)" to the end of the title.
--
-- The tracker is Blizzard's Retail one (Blizzard_ObjectiveTracker). Each
-- quest is a block whose header QuestObjectiveTrackerMixin:UpdateSingle sets
-- on every update, so a hook after it finds the block and appends the step to
-- the header text. The block's height was measured on Blizzard's text; if the
-- longer title would wrap onto another line, Blizzard's title is put back so
-- the layout never breaks. Only the text is touched, nothing protected.
--------------------------------------------------------------------------------

local _, ns = ...

-- Each series in the order its quests are done.
ns.questSeries = {
    { name = "Unending Torment", ids = { 97288, 97289, 97290, 97291, 97292 } },
}

-- questID -> { step, count }
local stepByQuest = {}
for _, series in ipairs(ns.questSeries) do
    for step, questID in ipairs(series.ids) do
        stepByQuest[questID] = { step = step, count = #series.ids }
    end
end

-- "(2/5)" for a quest in a series, else nil.
function ns.QuestSeriesSuffix(questID)
    local entry = questID and stepByQuest[questID]
    return entry and ("(%d/%d)"):format(entry.step, entry.count) or nil
end

--------------------------------------------------------------------------------
-- The objective tracker
--------------------------------------------------------------------------------

local function AddSuffix(module, quest)
    local questID = quest and quest.GetID and quest:GetID()
    local suffix = ns.QuestSeriesSuffix(questID)
    if not suffix then
        return
    end
    local block = module.GetExistingBlock and module:GetExistingBlock(questID)
    local header = block and block.HeaderText
    local text = header and header:GetText()
    if not text or text:sub(-#suffix) == suffix then
        return
    end
    local height = header:GetHeight()
    header:SetText(text .. " " .. suffix)
    if header:GetHeight() > height + 0.5 then
        header:SetText(text) -- would wrap; keep Blizzard's layout
    end
end

-- The quest and campaign trackers both build their blocks through UpdateSingle.
local hooked = {}
local function Install()
    for _, module in ipairs({ QuestObjectiveTracker, CampaignQuestObjectiveTracker }) do
        if module and module.UpdateSingle and not hooked[module] then
            hooked[module] = true
            hooksecurefunc(module, "UpdateSingle", AddSuffix)
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and name == "Blizzard_ObjectiveTracker") then
        Install()
    end
end)
