--------------------------------------------------------------------------------
-- Sink / Gathering.lua
--
-- Mining and herb nodes on the minimap: hovering one found with Find
-- Minerals or Find Herbs shows the game's tooltip, its node names one to a
-- line. Sink adds a red line under it for each node your skill is too low
-- to gather, with the skill it needs and yours: "Iron Deposit: needs Mining
-- 125 (you have 98)". Nodes you can gather add nothing.
--
-- What each node needs has no API, so it is the table below, the vanilla
-- values; a node not in it adds nothing.
--------------------------------------------------------------------------------

local _, ns = ...

-- Node name -> { profession, skill }.
local NODES = {}
local function Add(profession, list)
    for name, skill in pairs(list) do
        NODES[name] = { profession = profession, skill = skill }
    end
end

Add("Mining", {
    ["Copper Vein"] = 1, ["Tin Vein"] = 65, ["Incendicite Mineral Vein"] = 65, ["Silver Vein"] = 75,
    ["Lesser Bloodstone Deposit"] = 75, ["Iron Deposit"] = 125, ["Indurium Mineral Vein"] = 150,
    ["Gold Vein"] = 155, ["Mithril Deposit"] = 175, ["Ooze Covered Mithril Deposit"] = 175,
    ["Truesilver Deposit"] = 230, ["Ooze Covered Truesilver Deposit"] = 230, ["Dark Iron Deposit"] = 230,
    ["Small Thorium Vein"] = 245, ["Ooze Covered Thorium Vein"] = 245, ["Rich Thorium Vein"] = 275,
    ["Ooze Covered Rich Thorium Vein"] = 275,
})

Add("Herbalism", {
    ["Peacebloom"] = 1, ["Silverleaf"] = 1, ["Earthroot"] = 15, ["Mageroyal"] = 50, ["Briarthorn"] = 70,
    ["Stranglekelp"] = 85, ["Bruiseweed"] = 100, ["Wild Steelbloom"] = 115, ["Grave Moss"] = 120,
    ["Kingsblood"] = 125, ["Liferoot"] = 150, ["Fadeleaf"] = 160, ["Goldthorn"] = 170,
    ["Khadgar's Whisker"] = 185, ["Wintersbite"] = 195, ["Firebloom"] = 205, ["Purple Lotus"] = 210,
    ["Arthas' Tears"] = 220, ["Sungrass"] = 230, ["Blindweed"] = 235, ["Ghost Mushroom"] = 245,
    ["Gromsblood"] = 250, ["Golden Sansam"] = 260, ["Dreamfoil"] = 270, ["Mountain Silversage"] = 280,
    ["Plaguebloom"] = 285, ["Icecap"] = 290, ["Black Lotus"] = 300,
})

local function Enabled()
    return ns.db ~= nil and ns.db.gatherTooltips ~= false
end

-- A tooltip line as plain text: no colour or texture codes.
local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local adding = false -- true while Sink's own Show re-runs the hook

-- The minimap sets the tooltip's text when you hover and again as you move
-- onto other nodes, so this runs after both Show and SetText. added marks a
-- tooltip that already has the lines; clearing it, as SetText does, unmarks it.
local added = false

-- Whether the tooltip is the minimap's. Forever gives it UIParent as its
-- owner, not the minimap, so the mouse being over the minimap is what says so.
local function OnMinimap(tooltip)
    return tooltip:GetOwner() == Minimap or (Minimap.IsMouseOver ~= nil and Minimap:IsMouseOver())
end

local function AddNodeLines(tooltip)
    if adding or added or not Enabled() or not OnMinimap(tooltip) then
        return
    end
    local lines, seen = {}, {}
    for i = 1, tooltip:NumLines() do
        local region = _G[tooltip:GetName() .. "TextLeft" .. i]
        local text = region and region:GetText()
        if text and not ns.Secret(text) then
            -- Several nodes under the mouse come in one line, split by newlines.
            for part in text:gmatch("[^\n]+") do
                local name = Plain(part)
                local node = NODES[name]
                if node and not seen[name] then
                    seen[name] = true
                    local have = ns.ProfessionSkill and ns.ProfessionSkill(node.profession)
                    if not have or have < node.skill then
                        lines[#lines + 1] = ("%s: needs %s %d%s"):format(name, node.profession, node.skill,
                            have and (" (you have " .. have .. ")") or "")
                    end
                end
            end
        end
    end
    if #lines == 0 then
        return
    end
    for _, line in ipairs(lines) do
        tooltip:AddLine(ns.CROSS .. " " .. line, ns.missing.r, ns.missing.g, ns.missing.b)
    end
    added = true
    adding = true
    tooltip:Show() -- resize to the new lines
    adding = false
end

-- What "/sink dump tooltip" prints about the node lines: whether this file
-- sees the tooltip as the minimap's, your skills, and each line's node.
function ns.GatheringReport(tooltip)
    local report = {
        ("gathering: loaded, on %s, owner is minimap %s, mouse over minimap %s, lines added %s"):format(
            Enabled() and "yes" or "no (switched off)", tostring(tooltip:GetOwner() == Minimap),
            tostring(Minimap.IsMouseOver ~= nil and Minimap:IsMouseOver()), tostring(added)),
        ("gathering: Mining %s, Herbalism %s"):format(tostring(ns.ProfessionSkill and ns.ProfessionSkill("Mining")),
            tostring(ns.ProfessionSkill and ns.ProfessionSkill("Herbalism"))),
    }
    for i = 1, tooltip:NumLines() do
        local region = _G[tooltip:GetName() .. "TextLeft" .. i]
        local text = region and region:GetText()
        if text and not ns.Secret(text) then
            for part in text:gmatch("[^\n]+") do
                local node = NODES[Plain(part)]
                report[#report + 1] = ("gathering: %q is %s"):format(Plain(part),
                    node and (node.profession .. " " .. node.skill) or "not a node in the table")
            end
        end
    end
    return report
end

GameTooltip:HookScript("OnShow", AddNodeLines)
-- The game may fill the minimap's tooltip from its own code, which runs no
-- hook, and after it is shown: so look again while it is up, a few times a second.
local elapsedSince = 0
GameTooltip:HookScript("OnUpdate", function(tooltip, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince >= 0.2 then
        elapsedSince = 0
        AddNodeLines(tooltip)
    end
end)
GameTooltip:HookScript("OnTooltipCleared", function()
    added = false
end)
hooksecurefunc(GameTooltip, "SetText", AddNodeLines)
