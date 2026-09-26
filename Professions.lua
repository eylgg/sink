--------------------------------------------------------------------------------
-- Sink / Professions.lua
--
-- What profession trainers teach, and which of it you are missing. The
-- Professions tab of the options window lists, for each profession you have,
-- the trainer recipes you do not know yet: a red cross for one your skill
-- allows now, plain grey with the skill it needs for one it does not. It is
-- not in the tracker.
--
-- Like the class training in Trainers.lua, what a trainer teaches has no API
-- outside the trainer window, so it is built in: ns.professionRecipes below,
-- one list per profession, pasted from "/sink dump trainer" at that
-- profession's trainer. Nothing is saved from the window in game. Whether you
-- know a recipe is asked of its spell, the same as for class training.
--------------------------------------------------------------------------------

local _, ns = ...

-- Recipe lists, by profession name as the trainer window gives it:
-- { { name, spell, skill, cost, category }, ... }. skill is the profession
-- skill the recipe needs, cost is in copper, category the trainer's grouping
-- ("Agility Food"); any of the three may be missing, and a recipe without a
-- skill counts as one you can learn now. The profession's own ranks
-- ("Journeyman Cook") are listed too.
ns.professionRecipes = {}

ns.professionRecipes.Cooking = {
    { name = "Apprentice Cook", spell = 2550, cost = 100 },
    { name = "Journeyman Cook", spell = 3102, skill = 50, cost = 500 },
    { name = "Spiced Wolf Meat", spell = 2539, skill = 10, cost = 50, category = "Agility Food" },
    { name = "Basic Campfire Kit", spell = 1229737, skill = 20, cost = 100, category = "Camping" },
    { name = "Boiled Clams", spell = 6499, skill = 50, cost = 100, category = "Everyday Meals" },
    { name = "Coyote Steak", spell = 2541, skill = 50, cost = 100, category = "Agility Food" },
    { name = "Crab Cake", spell = 2544, skill = 75, cost = 200, category = "Intellect Food" },
    { name = "Dry Pork Ribs", spell = 2546, skill = 80, cost = 150, category = "Strength Food" },
    { name = "Goblin Deviled Clams", spell = 6500, skill = 125, cost = 300, category = "Everyday Meals" },
    { name = "Spider Sausage", spell = 21175, skill = 200, cost = 4000, category = "Everyday Meals" },
}

-- Skill line IDs, for your current skill in each; the same IDs as the
-- profession table in MapPins.lua.
local SKILL_LINES = {
    Alchemy = 171, Blacksmithing = 164, Enchanting = 333, Engineering = 202, Herbalism = 182,
    Leatherworking = 165, Mining = 186, Skinning = 393, Tailoring = 197, Cooking = 185,
    ["First Aid"] = 129, Fishing = 356,
}

-- Your skill in a profession, or nil if you do not have it.
local function Skill(profession)
    local line = SKILL_LINES[profession]
    if not (line and C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID) then
        return nil
    end
    local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, line)
    if ok and info and not info.isHeader and (info.maxRank or 0) > 0 then
        return info.skillRank or 0
    end
    return nil
end

local function Known(recipe)
    local spell = recipe.spell
    if not spell then
        return false
    end
    return (IsPlayerSpell and IsPlayerSpell(spell)) or (IsSpellKnown and IsSpellKnown(spell)) or false
end

-- The professions you have that have a list, alphabetical, each with your
-- skill and the recipes you do not know: learnable now first, then by the
-- skill they need, then by name.
local function Missing()
    local list = {}
    for profession, recipes in pairs(ns.professionRecipes) do
        local skill = Skill(profession)
        if skill then
            local missing = {}
            for _, recipe in ipairs(recipes) do
                if not Known(recipe) then
                    missing[#missing + 1] = recipe
                end
            end
            table.sort(missing, function(a, b)
                local aNeed, bNeed = a.skill or 0, b.skill or 0
                local aNow, bNow = aNeed <= skill, bNeed <= skill
                if aNow ~= bNow then
                    return aNow
                end
                if aNeed ~= bNeed then
                    return aNeed < bNeed
                end
                return a.name < b.name
            end)
            list[#list + 1] = { name = profession, skill = skill, missing = missing }
        end
    end
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    return list
end

--------------------------------------------------------------------------------
-- The list on the options window's Professions tab
--------------------------------------------------------------------------------

local list -- the page's list: { child, text }

-- Builds the list at y on the page and returns the height it takes: a
-- scrolling frame filling the rest of the page.
function ns.BuildProfessionList(page, y)
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
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
    end)
    list = { child = child, text = text }
    ns.RefreshProfessionList()
    return 0 -- it fills the rest of the page
end

-- "Crab Cake (1s)" for one you can learn now, grey "Crab Cake (skill 75)" for
-- one your skill is too low for.
local function RecipeLine(recipe, skill)
    local cost = recipe.cost and recipe.cost > 0 and GetMoneyString and GetMoneyString(recipe.cost, true)
    if (recipe.skill or 0) > skill then
        return ("%s%s (skill %d)|r"):format(ns.grey.hex, recipe.name, recipe.skill)
    end
    return ("%s %s%s|r%s"):format(ns.CROSS, ns.missing.hex, recipe.name, cost and (" " .. cost) or "")
end

function ns.RefreshProfessionList()
    if not list or not list.child:IsVisible() then
        return
    end
    local lines = {}
    for _, profession in ipairs(Missing()) do
        if #lines > 0 then
            lines[#lines + 1] = " "
        end
        lines[#lines + 1] = ("%s%s|r (skill %d)"):format(NORMAL_FONT_COLOR_CODE, profession.name, profession.skill)
        if #profession.missing == 0 then
            lines[#lines + 1] = ns.known.hex .. "You know every recipe the trainer teaches.|r"
        end
        for _, recipe in ipairs(profession.missing) do
            lines[#lines + 1] = RecipeLine(recipe, profession.skill)
        end
    end
    if #lines == 0 then
        lines[1] = ns.grey.hex .. "None of your professions has a trainer list in Sink yet.|r"
    end
    list.text:SetText(table.concat(lines, "\n"))
    list.child:SetHeight(list.text:GetStringHeight() + 4)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("SKILL_LINES_CHANGED")
pcall(frame.RegisterEvent, frame, "SPELLS_CHANGED") -- see Core.lua
frame:SetScript("OnEvent", function()
    ns.RefreshProfessionList()
end)
