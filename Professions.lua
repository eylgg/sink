--------------------------------------------------------------------------------
-- Sink / Professions.lua
--
-- What profession trainers teach, and which of it you are missing. The
-- Professions tab of the options window lists, for each profession you have,
-- the trainer recipes you do not know yet: a red cross for one your skill
-- allows now, plain grey with the skill or level it needs for one it does not. It is
-- not in the tracker.
--
-- Like the class training in Trainers.lua, what a trainer teaches has no API
-- outside the trainer window, so it is built in: ns.professionRecipes below,
-- one list per profession, pasted from "/sink dump trainer" at that
-- profession's trainer. Nothing is saved from the window in game. Whether you
-- know a recipe is asked of its spell, the same as for class training.
--
-- Reagents list the recipes they are used in on their tooltip, from
-- ns.reagents further down, under a profession header: "[50] Longjaw Mud
-- Snapper", green when you know it, yellow when your skill would let you
-- learn it, red when it would not.
--------------------------------------------------------------------------------

local _, ns = ...

-- Recipe lists, by profession name as the trainer window gives it:
-- { { name, spell, skill, level, cost, category }, ... }. skill is the
-- profession skill the recipe needs, level the character level (only where it
-- asks for one, as Journeyman Fishing's 10), cost is in copper, category the
-- trainer's grouping ("Agility Food"); any of them may be missing, and a
-- recipe without skill or level counts as one you can learn now. The
-- profession's own ranks ("Journeyman Cook") are listed too.
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

ns.professionRecipes.Fishing = {
    { name = "Apprentice Fishing", spell = 7620, cost = 100 },
    { name = "Journeyman Fishing", spell = 7731, skill = 50, level = 10, cost = 500 },
    { name = "Fish Bowl", spell = 1229745, skill = 20, cost = 100, category = "Camping" },
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
        return info.rank or 0
    end
    return nil
end

ns.ProfessionSkill = Skill -- for the minimap node lines (Gathering.lua)

-- Whether your skill and level are enough for a recipe now.
local function CanLearnNow(recipe, skill)
    local level = UnitLevel and UnitLevel("player") or 0
    return (recipe.skill or 0) <= skill and (recipe.level or 0) <= level
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
                local aNow, bNow = CanLearnNow(a, skill), CanLearnNow(b, skill)
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
-- one your skill is too low for, "(skill 50, level 10)" when both are asked
-- for and one is short.
local function RecipeLine(recipe, skill)
    local cost = recipe.cost and recipe.cost > 0 and GetMoneyString and GetMoneyString(recipe.cost, true)
    if not CanLearnNow(recipe, skill) then
        local needs = {}
        if recipe.skill then
            needs[#needs + 1] = "skill " .. recipe.skill
        end
        if recipe.level then
            needs[#needs + 1] = "level " .. recipe.level
        end
        return ("%s%s (%s)|r"):format(ns.grey.hex, recipe.name, table.concat(needs, ", "))
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

--------------------------------------------------------------------------------
-- Reagents: which recipes an item is used for
--------------------------------------------------------------------------------

-- Reagent itemID -> the recipes that use it: { { spell, profession, skill, recipe }, ... }.
-- spell is the craft's spell (whether you know it is asked of it), profession
-- the name as in SKILL_LINES, skill the profession skill it needs (Wowhead's
-- "learned at"), recipe the item that teaches it when a trainer does not. The recipe's name comes from its spell. quest and giver, for a
-- recipe item that is a quest reward, say where to get it; faction, for one
-- only a faction can get, makes it grey for the other.
ns.reagents = {
    -- Every cooking recipe up to 300 in Wowhead's Forever database, by what goes into it, generated
    -- from it. A recipe without a recipe item is the trainer's; one whose recipe item is only a quest
    -- reward names the quest, with the quest's faction when it has one. A recipe item that is a quest
    -- reward and also sold, as Strider Stew, counts as a plain recipe.
    [3173] = { -- Bear Meat
        { spell = 8607, profession = "Cooking", skill = 40, recipe = 6892 }, -- Smoked Bear Meat
        { spell = 3371, profession = "Cooking", skill = 60, recipe = 3679 }, -- Blood Sausage
    },
    [3730] = { -- Big Bear Meat
        { spell = 3397, profession = "Cooking", skill = 110, recipe = 3734 }, -- Big Bear Steak
        { spell = 1250151, profession = "Cooking", skill = 175, recipe = 250182 }, -- Bear Brisket
        { spell = 1250147, profession = "Cooking", skill = 275, recipe = 250178 }, -- Bear Bruscitti
    },
    [3172] = { -- Boar Intestines
        { spell = 3371, profession = "Cooking", skill = 60, recipe = 3679 }, -- Blood Sausage
    },
    [2677] = { -- Boar Ribs
        { spell = 2546, profession = "Cooking", skill = 80 }, -- Dry Pork Ribs
        { spell = 2548, profession = "Cooking", skill = 110, recipe = 2700 }, -- Succulent Pork Ribs
    },
    [3404] = { -- Buzzard Wing
        { spell = 4094, profession = "Cooking", skill = 175, recipe = 4609 }, -- Barbecued Buzzard Wing
        { spell = 1250143, profession = "Cooking", skill = 275, recipe = 250174 }, -- Soaring Pamplona
        { spell = 1225763, profession = "Cooking", skill = 280, recipe = 239021 }, -- Grand Lobster Banquet
    },
    [21024] = { -- Chimaerok Tenderloin
        { spell = 25659, profession = "Cooking", skill = 300, recipe = 21025,
          quest = 8586 }, -- Dirge's Kickin' Chimaerok Chops
    },
    [769] = { -- Chunk of Boar Meat
        { spell = 2540, profession = "Cooking", skill = 1 }, -- Roasted Boar Meat
        { spell = 1295834, profession = "Cooking", skill = 185, recipe = 274977 }, -- Plain Ol' Paletusk
    },
    [5503] = { -- Clam Meat
        { spell = 6499, profession = "Cooking", skill = 50 }, -- Boiled Clams
        { spell = 6501, profession = "Cooking", skill = 90, recipe = 5528 }, -- Clam Chowder
    },
    [2673] = { -- Coyote Meat
        { spell = 2541, profession = "Cooking", skill = 50 }, -- Coyote Steak
    },
    [2886] = { -- Crag Boar Rib
        { spell = 2795, profession = "Cooking", skill = 25, recipe = 2889 }, -- Beer Basted Boar Ribs
    },
    [2675] = { -- Crawler Claw
        { spell = 1270635, profession = "Cooking", skill = 35, recipe = 263513,
          quest = 93317 }, -- Pincer Bites
        { spell = 2545, profession = "Cooking", skill = 85, recipe = 2698 }, -- Cooked Crab Claw
    },
    [2674] = { -- Crawler Meat
        { spell = 2544, profession = "Cooking", skill = 75 }, -- Crab Cake
    },
    [1081] = { -- Crisp Spider Meat
        { spell = 2547, profession = "Cooking", skill = 100, recipe = 2699 }, -- Redridge Goulash
    },
    [2924] = { -- Crocolisk Meat
        { spell = 3370, profession = "Cooking", skill = 80, recipe = 3678 }, -- Crocolisk Steak
    },
    [13888] = { -- Darkclaw Lobster
        { spell = 18245, profession = "Cooking", skill = 275, recipe = 13947 }, -- Lobster Stew
        { spell = 1225763, profession = "Cooking", skill = 280, recipe = 239021 }, -- Grand Lobster Banquet
        { spell = 470359, profession = "Cooking", skill = 300, recipe = 232437 }, -- Darkclaw Bisque
    },
    [8150] = { -- Deeprock Salt
        { spell = 25659, profession = "Cooking", skill = 300, recipe = 21025,
          quest = 8586 }, -- Dirge's Kickin' Chimaerok Chops
    },
    [6522] = { -- Deviate Fish
        { spell = 8238, profession = "Cooking", skill = 85, recipe = 6661 }, -- Savory Deviate Delight
    },
    [5051] = { -- Dig Rat
        { spell = 6417, profession = "Cooking", skill = 90, recipe = 5487,
          quest = 862, faction = "Horde" }, -- Dig Rat Stew
    },
    [227813] = { -- Drinkable Stratholme Holy Water
        { spell = 470359, profession = "Cooking", skill = 300, recipe = 232437 }, -- Darkclaw Bisque
    },
    [239017] = { -- Exquisite Spices
        { spell = 1225763, profession = "Cooking", skill = 280, recipe = 239021 }, -- Grand Lobster Banquet
        { spell = 1225762, profession = "Cooking", skill = 280, recipe = 239021 }, -- Specklefin Feast
    },
    [3818] = { -- Fadeleaf
        { spell = 1249960, profession = "Cooking", skill = 180, recipe = 249882 }, -- Triage Tea
    },
    [4655] = { -- Giant Clam Meat
        { spell = 7213, profession = "Cooking", skill = 175, recipe = 6039 }, -- Giant Clam Scorcho
    },
    [12207] = { -- Giant Egg
        { spell = 1250155, profession = "Cooking", skill = 175, recipe = 250186 }, -- Giant Scrambled Eggs
        { spell = 15933, profession = "Cooking", skill = 225, recipe = 16110 }, -- Monster Omelet
        { spell = 1225760, profession = "Cooking", skill = 250, recipe = 238647 }, -- Sunrise Omelette
    },
    [9061] = { -- Goblin Rocket Fuel
        { spell = 25659, profession = "Cooking", skill = 300, recipe = 21025,
          quest = 8586 }, -- Dirge's Kickin' Chimaerok Chops
    },
    [3821] = { -- Goldthorn
        { spell = 13028, profession = "Cooking", skill = 175 }, -- Goldthorn Tea
    },
    [2251] = { -- Gooey Spider Leg
        { spell = 3377, profession = "Cooking", skill = 110, recipe = 3683 }, -- Gooey Spider Cake
    },
    [723] = { -- Goretusk Liver
        { spell = 2542, profession = "Cooking", skill = 50, recipe = 2697 }, -- Goretusk Liver Pie
    },
    [731] = { -- Goretusk Snout
        { spell = 2543, profession = "Cooking", skill = 75, recipe = 728 }, -- Westfall Stew
    },
    [12204] = { -- Heavy Kodo Meat
        { spell = 1262978, profession = "Cooking", skill = 140, recipe = 273102 }, -- Cookie's Feast
        { spell = 15910, profession = "Cooking", skill = 200, recipe = 12240 }, -- Heavy Kodo Stew
    },
    [17194] = { -- Holiday Spices
        { spell = 21143, profession = "Cooking", skill = 1, recipe = 17200 }, -- Gingerbread Cookie
        { spell = 21144, profession = "Cooking", skill = 35, recipe = 17201 }, -- Egg Nog
    },
    [17196] = { -- Holiday Spirits
        { spell = 21144, profession = "Cooking", skill = 35, recipe = 17201 }, -- Egg Nog
    },
    [239016] = { -- Holy Salts
        { spell = 1225759, profession = "Cooking", skill = 250, recipe = 238646 }, -- Filet o' Flank
        { spell = 1225758, profession = "Cooking", skill = 250, recipe = 238645 }, -- Prowler Steak
        { spell = 1225760, profession = "Cooking", skill = 250, recipe = 238647 }, -- Sunrise Omelette
    },
    [2692] = { -- Hot Spices
        { spell = 3372, profession = "Cooking", skill = 90, recipe = 3680 }, -- Murloc Fin Soup
        { spell = 6418, profession = "Cooking", skill = 100, recipe = 5488 }, -- Crispy Lizard Tail
        { spell = 3397, profession = "Cooking", skill = 110, recipe = 3734 }, -- Big Bear Steak
        { spell = 3377, profession = "Cooking", skill = 110, recipe = 3683 }, -- Gooey Spider Cake
        { spell = 2548, profession = "Cooking", skill = 110, recipe = 2700 }, -- Succulent Pork Ribs
        { spell = 3373, profession = "Cooking", skill = 120, recipe = 3681 }, -- Crocolisk Gumbo
        { spell = 6500, profession = "Cooking", skill = 125 }, -- Goblin Deviled Clams
        { spell = 3398, profession = "Cooking", skill = 125, recipe = 3735 }, -- Hot Lion Chops
        { spell = 1249965, profession = "Cooking", skill = 125, recipe = 249887 }, -- Mrrggl Smrrthle
        { spell = 3376, profession = "Cooking", skill = 130, recipe = 3682 }, -- Curiously Tasty Omelet
        { spell = 4094, profession = "Cooking", skill = 175, recipe = 4609 }, -- Barbecued Buzzard Wing
        { spell = 1250151, profession = "Cooking", skill = 175, recipe = 250182 }, -- Bear Brisket
        { spell = 15863, profession = "Cooking", skill = 175, recipe = 12232 }, -- Carrion Surprise
        { spell = 7213, profession = "Cooking", skill = 175, recipe = 6039 }, -- Giant Clam Scorcho
        { spell = 1250155, profession = "Cooking", skill = 175, recipe = 250186 }, -- Giant Scrambled Eggs
        { spell = 15856, profession = "Cooking", skill = 175, recipe = 12229 }, -- Hot Wolf Ribs
        { spell = 15855, profession = "Cooking", skill = 175, recipe = 12228 }, -- Roast Raptor
        { spell = 25954, profession = "Cooking", skill = 175, recipe = 21219 }, -- Sagefish Delight
        { spell = 1249966, profession = "Cooking", skill = 180, recipe = 249888 }, -- Calcified Smoothie
        { spell = 1250150, profession = "Cooking", skill = 180, recipe = 250181 }, -- Raging Raptor Ribs
        { spell = 1295805, profession = "Cooking", skill = 200, recipe = 274972 }, -- Briny Seafood Stew
        { spell = 15906, profession = "Cooking", skill = 200, recipe = 12239 }, -- Dragonbreath Chili
        { spell = 1250153, profession = "Cooking", skill = 225, recipe = 250184 }, -- Raptor Rouladen
        { spell = 1250142, profession = "Cooking", skill = 225, recipe = 250173 }, -- Savory Stag Sliders
        { spell = 15915, profession = "Cooking", skill = 225, recipe = 16111 }, -- Spiced Chili Crab
        { spell = 20626, profession = "Cooking", skill = 225, recipe = 16767 }, -- Undermine Clam Chowder
        { spell = 18242, profession = "Cooking", skill = 240, recipe = 13943 }, -- Hot Smoked Bass
        { spell = 18246, profession = "Cooking", skill = 275, recipe = 13948 }, -- Mightfish Steak
        { spell = 25659, profession = "Cooking", skill = 300, recipe = 21025,
          quest = 8586 }, -- Dirge's Kickin' Chimaerok Chops
    },
    [249796] = { -- Hyjal Berries
        { spell = 1294014, profession = "Cooking", skill = 275, recipe = 274415 }, -- Sweetpaw Jam
    },
    [1179] = { -- Ice Cold Milk
        { spell = 21144, profession = "Cooking", skill = 35, recipe = 17201 }, -- Egg Nog
        { spell = 6501, profession = "Cooking", skill = 90, recipe = 5528 }, -- Clam Chowder
        { spell = 1249958, profession = "Cooking", skill = 100, recipe = 249880 }, -- Royal Tea
        { spell = 1249964, profession = "Cooking", skill = 100, recipe = 249886 }, -- Slimy Smoothie
        { spell = 20626, profession = "Cooking", skill = 225, recipe = 16767 }, -- Undermine Clam Chowder
    },
    [5467] = { -- Kodo Meat
        { spell = 6414, profession = "Cooking", skill = 35, recipe = 5484 }, -- Roasted Kodo Meat
    },
    [5637] = { -- Large Fang
        { spell = 1249966, profession = "Cooking", skill = 180, recipe = 249888 }, -- Calcified Smoothie
    },
    [13893] = { -- Large Raw Mightfish
        { spell = 18246, profession = "Cooking", skill = 275, recipe = 13948 }, -- Mightfish Steak
    },
    [1015] = { -- Lean Wolf Flank
        { spell = 2549, profession = "Cooking", skill = 100, recipe = 2701 }, -- Seasoned Wolf Kabob
        { spell = 15853, profession = "Cooking", skill = 125, recipe = 12227 }, -- Lean Wolf Steak
    },
    [3357] = { -- Liferoot
        { spell = 1249959, profession = "Cooking", skill = 125, recipe = 249881 }, -- Root Tea
    },
    [3731] = { -- Lion Meat
        { spell = 3398, profession = "Cooking", skill = 125, recipe = 3735 }, -- Hot Lion Chops
        { spell = 3399, profession = "Cooking", skill = 150, recipe = 3736,
          quest = 564, faction = "Alliance" }, -- Tasty Lion Steak
    },
    [785] = { -- Mageroyal
        { spell = 1249958, profession = "Cooking", skill = 100, recipe = 249880 }, -- Royal Tea
    },
    [12223] = { -- Meaty Bat Wing
        { spell = 15935, profession = "Cooking", skill = 1, recipe = 12226 }, -- Crispy Bat Wing
        { spell = 1250144, profession = "Cooking", skill = 275, recipe = 250175 }, -- Bat Hachee
    },
    [1205] = { -- Melon Juice
        { spell = 1249965, profession = "Cooking", skill = 125, recipe = 249887 }, -- Mrrggl Smrrthle
        { spell = 1249959, profession = "Cooking", skill = 125, recipe = 249881 }, -- Root Tea
    },
    [2678] = { -- Mild Spices
        { spell = 15935, profession = "Cooking", skill = 1, recipe = 12226 }, -- Crispy Bat Wing
        { spell = 8604, profession = "Cooking", skill = 1 }, -- Herb Baked Egg
        { spell = 2539, profession = "Cooking", skill = 10 }, -- Spiced Wolf Meat
        { spell = 1250156, profession = "Cooking", skill = 25, recipe = 250187 }, -- Tasty Raptor Bites
        { spell = 1249963, profession = "Cooking", skill = 25, recipe = 249885 }, -- Venomous Smoothie
        { spell = 6414, profession = "Cooking", skill = 35, recipe = 5484 }, -- Roasted Kodo Meat
        { spell = 6415, profession = "Cooking", skill = 50, recipe = 5485 }, -- Fillet of Frenzy
        { spell = 2542, profession = "Cooking", skill = 50, recipe = 2697 }, -- Goretusk Liver Pie
        { spell = 7754, profession = "Cooking", skill = 50, recipe = 6329 }, -- Loch Frenzy Delight
        { spell = 1250157, profession = "Cooking", skill = 75, recipe = 250188 }, -- Breakfast Omelette
        { spell = 2544, profession = "Cooking", skill = 75 }, -- Crab Cake
        { spell = 1250154, profession = "Cooking", skill = 75, recipe = 250185,
          quest = 95697, faction = "Horde" }, -- Twice-Spiced Raptor Slice
        { spell = 3370, profession = "Cooking", skill = 80, recipe = 3678 }, -- Crocolisk Steak
        { spell = 2546, profession = "Cooking", skill = 80 }, -- Dry Pork Ribs
        { spell = 25704, profession = "Cooking", skill = 80, recipe = 21099 }, -- Smoked Sagefish
        { spell = 2545, profession = "Cooking", skill = 85, recipe = 2698 }, -- Cooked Crab Claw
        { spell = 8238, profession = "Cooking", skill = 85, recipe = 6661 }, -- Savory Deviate Delight
        { spell = 1252566, profession = "Cooking", skill = 85, recipe = 251526 }, -- Savory Whimsyfin Delight
        { spell = 6501, profession = "Cooking", skill = 90, recipe = 5528 }, -- Clam Chowder
        { spell = 2549, profession = "Cooking", skill = 100, recipe = 2701 }, -- Seasoned Wolf Kabob
        { spell = 1249964, profession = "Cooking", skill = 100, recipe = 249886 }, -- Slimy Smoothie
        { spell = 6419, profession = "Cooking", skill = 110, recipe = 5489 }, -- Lean Venison
        { spell = 15853, profession = "Cooking", skill = 125, recipe = 12227 }, -- Lean Wolf Steak
        { spell = 1295834, profession = "Cooking", skill = 185, recipe = 274977 }, -- Plain Ol' Paletusk
    },
    [1645] = { -- Moonberry Juice
        { spell = 1249967, profession = "Cooking", skill = 200, recipe = 249889 }, -- Spicy Smoothie
        { spell = 1249961, profession = "Cooking", skill = 200, recipe = 249883 }, -- Sunny Tea
    },
    [8766] = { -- Morning Glory Dew
        { spell = 1249962, profession = "Cooking", skill = 250, recipe = 249884 }, -- Sage's Tea
        { spell = 1249968, profession = "Cooking", skill = 250, recipe = 249890 }, -- Wicked Smoothie
    },
    [13465] = { -- Mountain Silversage
        { spell = 1249962, profession = "Cooking", skill = 250, recipe = 249884 }, -- Sage's Tea
    },
    [730] = { -- Murloc Eye
        { spell = 2543, profession = "Cooking", skill = 75, recipe = 728 }, -- Westfall Stew
        { spell = 1295805, profession = "Cooking", skill = 200, recipe = 274972 }, -- Briny Seafood Stew
    },
    [1468] = { -- Murloc Fin
        { spell = 3372, profession = "Cooking", skill = 90, recipe = 3680 }, -- Murloc Fin Soup
        { spell = 1249965, profession = "Cooking", skill = 125, recipe = 249887 }, -- Mrrggl Smrrthle
    },
    [12037] = { -- Mystery Meat
        { spell = 1262978, profession = "Cooking", skill = 140, recipe = 273102 }, -- Cookie's Feast
        { spell = 15863, profession = "Cooking", skill = 175, recipe = 12232 }, -- Carrion Surprise
        { spell = 15865, profession = "Cooking", skill = 175, recipe = 12233 }, -- Mystery Stew
        { spell = 15906, profession = "Cooking", skill = 200, recipe = 12239 }, -- Dragonbreath Chili
    },
    [2447] = { -- Peacebloom
        { spell = 1249957, profession = "Cooking", skill = 25, recipe = 249879 }, -- Peace Tea
    },
    [3685] = { -- Raptor Egg
        { spell = 1250156, profession = "Cooking", skill = 25, recipe = 250187 }, -- Tasty Raptor Bites
        { spell = 3376, profession = "Cooking", skill = 130, recipe = 3682 }, -- Curiously Tasty Omelet
    },
    [12184] = { -- Raptor Flesh
        { spell = 1250154, profession = "Cooking", skill = 75, recipe = 250185,
          quest = 95697, faction = "Horde" }, -- Twice-Spiced Raptor Slice
        { spell = 15855, profession = "Cooking", skill = 175, recipe = 12228 }, -- Roast Raptor
        { spell = 1250150, profession = "Cooking", skill = 180, recipe = 250181 }, -- Raging Raptor Ribs
        { spell = 1250153, profession = "Cooking", skill = 225, recipe = 250184 }, -- Raptor Rouladen
        { spell = 1250152, profession = "Cooking", skill = 275, recipe = 250183 }, -- Prehistoric Pulled Raptor
        { spell = 1225762, profession = "Cooking", skill = 280, recipe = 239021 }, -- Specklefin Feast
    },
    [6291] = { -- Raw Brilliant Smallfish
        { spell = 7751, profession = "Cooking", skill = 1, recipe = 6325 }, -- Brilliant Smallfish
    },
    [6308] = { -- Raw Bristle Whisker Catfish
        { spell = 7755, profession = "Cooking", skill = 100, recipe = 6330 }, -- Bristle Whisker Catfish
    },
    [13754] = { -- Raw Glossy Mightfish
        { spell = 18239, profession = "Cooking", skill = 225, recipe = 13940 }, -- Cooked Glossy Mightfish
    },
    [21153] = { -- Raw Greater Sagefish
        { spell = 25954, profession = "Cooking", skill = 175, recipe = 21219 }, -- Sagefish Delight
    },
    [6317] = { -- Raw Loch Frenzy
        { spell = 7754, profession = "Cooking", skill = 50, recipe = 6329 }, -- Loch Frenzy Delight
    },
    [6289] = { -- Raw Longjaw Mud Snapper
        { spell = 7753, profession = "Cooking", skill = 50, recipe = 6328 }, -- Longjaw Mud Snapper
    },
    [8365] = { -- Raw Mithril Head Trout
        { spell = 20916, profession = "Cooking", skill = 175, recipe = 17062 }, -- Mithril Headed Trout
    },
    [13759] = { -- Raw Nightfin Snapper
        { spell = 18243, profession = "Cooking", skill = 250, recipe = 13945 }, -- Nightfin Soup
    },
    [13890] = { -- Raw Plated Armorfish
        { spell = 1319313, profession = "Cooking", skill = 225, recipe = 286153 }, -- Plated Armorfish
    },
    [6361] = { -- Raw Rainbow Fin Albacore
        { spell = 7827, profession = "Cooking", skill = 50, recipe = 6368 }, -- Rainbow Fin Albacore
    },
    [13758] = { -- Raw Redgill
        { spell = 18241, profession = "Cooking", skill = 225, recipe = 13941 }, -- Filet of Redgill
        { spell = 470370, profession = "Cooking", skill = 300, recipe = 232443 }, -- Smoked Redgill
    },
    [6362] = { -- Raw Rockscale Cod
        { spell = 7828, profession = "Cooking", skill = 175, recipe = 6369 }, -- Rockscale Cod
        { spell = 1225762, profession = "Cooking", skill = 280, recipe = 239021 }, -- Specklefin Feast
    },
    [21071] = { -- Raw Sagefish
        { spell = 25704, profession = "Cooking", skill = 80, recipe = 21099 }, -- Smoked Sagefish
    },
    [6303] = { -- Raw Slitherskin Mackerel
        { spell = 7752, profession = "Cooking", skill = 1, recipe = 6326 }, -- Slitherskin Mackerel
    },
    [8959] = { -- Raw Spinefin Halibut
        { spell = 1247741, profession = "Cooking", skill = 210 }, -- Spinefin Halibut
    },
    [4603] = { -- Raw Spotted Yellowtail
        { spell = 18238, profession = "Cooking", skill = 225, recipe = 13939 }, -- Spotted Yellowtail
        { spell = 1225762, profession = "Cooking", skill = 280, recipe = 239021 }, -- Specklefin Feast
    },
    [13756] = { -- Raw Summer Bass
        { spell = 18242, profession = "Cooking", skill = 240, recipe = 13943 }, -- Hot Smoked Bass
    },
    [13760] = { -- Raw Sunscale Salmon
        { spell = 18244, profession = "Cooking", skill = 250, recipe = 13946 }, -- Poached Sunscale Salmon
    },
    [13889] = { -- Raw Whitescale Salmon
        { spell = 18247, profession = "Cooking", skill = 275, recipe = 13949 }, -- Baked Salmon
    },
    [13755] = { -- Raw Winter Squid
        { spell = 18240, profession = "Cooking", skill = 240, recipe = 13942 }, -- Grilled Squid
    },
    [12203] = { -- Red Wolf Meat
        { spell = 15856, profession = "Cooking", skill = 175, recipe = 12229 }, -- Hot Wolf Ribs
        { spell = 1225759, profession = "Cooking", skill = 250, recipe = 238646 }, -- Filet o' Flank
        { spell = 1250146, profession = "Cooking", skill = 275, recipe = 250177 }, -- Flank au Poivre
    },
    [159] = { -- Refreshing Spring Water
        { spell = 1249957, profession = "Cooking", skill = 25, recipe = 249879 }, -- Peace Tea
        { spell = 1249963, profession = "Cooking", skill = 25, recipe = 249885 }, -- Venomous Smoothie
        { spell = 6499, profession = "Cooking", skill = 50 }, -- Boiled Clams
        { spell = 9513, profession = "Cooking", skill = 60, recipe = 18160 }, -- Thistle Tea
        { spell = 13028, profession = "Cooking", skill = 175 }, -- Goldthorn Tea
        { spell = 15861, profession = "Cooking", skill = 175, recipe = 12231 }, -- Jungle Stew
        { spell = 15910, profession = "Cooking", skill = 200, recipe = 12240 }, -- Heavy Kodo Stew
        { spell = 18243, profession = "Cooking", skill = 250, recipe = 13945 }, -- Nightfin Soup
        { spell = 18245, profession = "Cooking", skill = 275, recipe = 13947 }, -- Lobster Stew
        { spell = 1263067, profession = "Cooking", skill = 300, recipe = 273115 }, -- Iron Oven
    },
    [2894] = { -- Rhapsody Malt
        { spell = 2795, profession = "Cooking", skill = 25, recipe = 2889 }, -- Beer Basted Boar Ribs
    },
    [18255] = { -- Runn Tum Tuber
        { spell = 22761, profession = "Cooking", skill = 275, recipe = 18267 }, -- Runn Tum Tuber Surprise
    },
    [20424] = { -- Sandworm Meat
        { spell = 24801, profession = "Cooking", skill = 285 }, -- Smoked Desert Dumplings
    },
    [5466] = { -- Scorpid Stinger
        { spell = 6413, profession = "Cooking", skill = 20, recipe = 5483 }, -- Scorpid Surprise
    },
    [4536] = { -- Shiny Red Apple
        { spell = 6416, profession = "Cooking", skill = 50, recipe = 5486 }, -- Strider Stew
        { spell = 15861, profession = "Cooking", skill = 175, recipe = 12231 }, -- Jungle Stew
    },
    [10284] = { -- Simple Flour
        { spell = 1270633, profession = "Cooking", skill = 25, recipe = 263511,
          quest = 92553 }, -- Skywall Souffle
        { spell = 1270635, profession = "Cooking", skill = 35, recipe = 263513,
          quest = 93317 }, -- Pincer Bites
        { spell = 1270632, profession = "Cooking", skill = 80 }, -- Critter Cookie
        { spell = 1263067, profession = "Cooking", skill = 300, recipe = 273115 }, -- Iron Oven
    },
    [4470] = { -- Simple Wood
        { spell = 1229737, profession = "Cooking", skill = 20 }, -- Basic Campfire
    },
    [2596] = { -- Skin of Dwarven Stout
        { spell = 15865, profession = "Cooking", skill = 175, recipe = 12233 }, -- Mystery Stew
    },
    [6889] = { -- Small Egg
        { spell = 21143, profession = "Cooking", skill = 1, recipe = 17200 }, -- Gingerbread Cookie
        { spell = 8604, profession = "Cooking", skill = 1 }, -- Herb Baked Egg
        { spell = 1270633, profession = "Cooking", skill = 25, recipe = 263511,
          quest = 92553 }, -- Skywall Souffle
        { spell = 21144, profession = "Cooking", skill = 35, recipe = 17201 }, -- Egg Nog
        { spell = 1250157, profession = "Cooking", skill = 75, recipe = 250188 }, -- Breakfast Omelette
    },
    [4402] = { -- Small Flame Sac
        { spell = 15906, profession = "Cooking", skill = 200, recipe = 12239 }, -- Dragonbreath Chili
        { spell = 1249967, profession = "Cooking", skill = 200, recipe = 249889 }, -- Spicy Smoothie
    },
    [5465] = { -- Small Spider Leg
        { spell = 6412, profession = "Cooking", skill = 10, recipe = 5482,
          quest = 4161, giver = "Zarrin in Dolanaar", faction = "Alliance" }, -- Kaldorei Spider Kabob
    },
    [1475] = { -- Small Venom Sac
        { spell = 1249963, profession = "Cooking", skill = 25, recipe = 249885 }, -- Venomous Smoothie
    },
    [5468] = { -- Soft Frenzy Flesh
        { spell = 6415, profession = "Cooking", skill = 50, recipe = 5485 }, -- Fillet of Frenzy
    },
    [3713] = { -- Soothing Spices
        { spell = 1262978, profession = "Cooking", skill = 140, recipe = 273102 }, -- Cookie's Feast
        { spell = 24418, profession = "Cooking", skill = 150, recipe = 20075 }, -- Heavy Crocolisk Stew
        { spell = 3399, profession = "Cooking", skill = 150, recipe = 3736,
          quest = 564, faction = "Alliance" }, -- Tasty Lion Steak
        { spell = 3400, profession = "Cooking", skill = 175, recipe = 3737,
          quest = 555, faction = "Alliance" }, -- Soothing Turtle Bisque
        { spell = 15910, profession = "Cooking", skill = 200, recipe = 12240 }, -- Heavy Kodo Stew
        { spell = 1249967, profession = "Cooking", skill = 200, recipe = 249889 }, -- Spicy Smoothie
        { spell = 18239, profession = "Cooking", skill = 225, recipe = 13940 }, -- Cooked Glossy Mightfish
        { spell = 15933, profession = "Cooking", skill = 225, recipe = 16110 }, -- Monster Omelet
        { spell = 1319313, profession = "Cooking", skill = 225, recipe = 286153 }, -- Plated Armorfish
        { spell = 22480, profession = "Cooking", skill = 225, recipe = 18046 }, -- Tender Wolf Steak
        { spell = 18240, profession = "Cooking", skill = 240, recipe = 13942 }, -- Grilled Squid
        { spell = 1249968, profession = "Cooking", skill = 250, recipe = 249890 }, -- Wicked Smoothie
        { spell = 18247, profession = "Cooking", skill = 275, recipe = 13949 }, -- Baked Salmon
        { spell = 1250144, profession = "Cooking", skill = 275, recipe = 250175 }, -- Bat Hachee
        { spell = 1250147, profession = "Cooking", skill = 275, recipe = 250178 }, -- Bear Bruscitti
        { spell = 1250158, profession = "Cooking", skill = 275, recipe = 250189 }, -- Clam Linguine
        { spell = 1250146, profession = "Cooking", skill = 275, recipe = 250177 }, -- Flank au Poivre
        { spell = 18246, profession = "Cooking", skill = 275, recipe = 13948 }, -- Mightfish Steak
        { spell = 1250152, profession = "Cooking", skill = 275, recipe = 250183 }, -- Prehistoric Pulled Raptor
        { spell = 22761, profession = "Cooking", skill = 275, recipe = 18267 }, -- Runn Tum Tuber Surprise
        { spell = 1250145, profession = "Cooking", skill = 275, recipe = 250176 }, -- Savory Turtle Stew
        { spell = 1250143, profession = "Cooking", skill = 275, recipe = 250174 }, -- Soaring Pamplona
        { spell = 1250148, profession = "Cooking", skill = 275, recipe = 250179 }, -- Steaming Stag Steak
        { spell = 1294014, profession = "Cooking", skill = 275, recipe = 274415 }, -- Sweetpaw Jam
        { spell = 1250149, profession = "Cooking", skill = 275, recipe = 250180 }, -- Swiftstrike Steak
        { spell = 24801, profession = "Cooking", skill = 285 }, -- Smoked Desert Dumplings
        { spell = 1263067, profession = "Cooking", skill = 300, recipe = 273115 }, -- Iron Oven
    },
    [3174] = { -- Spider Ichor
        { spell = 3371, profession = "Cooking", skill = 60, recipe = 3679 }, -- Blood Sausage
        { spell = 1249964, profession = "Cooking", skill = 100, recipe = 249886 }, -- Slimy Smoothie
    },
    [5471] = { -- Stag Meat
        { spell = 6419, profession = "Cooking", skill = 110, recipe = 5489 }, -- Lean Venison
        { spell = 1250142, profession = "Cooking", skill = 225, recipe = 250173 }, -- Savory Stag Sliders
        { spell = 1250148, profession = "Cooking", skill = 275, recipe = 250179 }, -- Steaming Stag Steak
    },
    [11291] = { -- Star Wood
        { spell = 1283400, profession = "Cooking", skill = 90, recipe = 273087 }, -- Journeyman Campfire
    },
    [5469] = { -- Strider Meat
        { spell = 6416, profession = "Cooking", skill = 50, recipe = 5486 }, -- Strider Stew
    },
    [729] = { -- Stringy Vulture Meat
        { spell = 2543, profession = "Cooking", skill = 75, recipe = 728 }, -- Westfall Stew
    },
    [2672] = { -- Stringy Wolf Meat
        { spell = 2538, profession = "Cooking", skill = 1 }, -- Charred Wolf Meat
        { spell = 2539, profession = "Cooking", skill = 10 }, -- Spiced Wolf Meat
    },
    [8838] = { -- Sungrass
        { spell = 1249961, profession = "Cooking", skill = 200, recipe = 249883 }, -- Sunny Tea
    },
    [1708] = { -- Sweet Nectar
        { spell = 1249966, profession = "Cooking", skill = 180, recipe = 249888 }, -- Calcified Smoothie
        { spell = 1249960, profession = "Cooking", skill = 180, recipe = 249882 }, -- Triage Tea
    },
    [2452] = { -- Swiftthistle
        { spell = 9513, profession = "Cooking", skill = 60, recipe = 18160 }, -- Thistle Tea
    },
    [5504] = { -- Tangy Clam Meat
        { spell = 6500, profession = "Cooking", skill = 125 }, -- Goblin Deviled Clams
    },
    [12206] = { -- Tender Crab Meat
        { spell = 1295805, profession = "Cooking", skill = 200, recipe = 274972 }, -- Briny Seafood Stew
        { spell = 15915, profession = "Cooking", skill = 225, recipe = 16111 }, -- Spiced Chili Crab
    },
    [3667] = { -- Tender Crocolisk Meat
        { spell = 3373, profession = "Cooking", skill = 120, recipe = 3681 }, -- Crocolisk Gumbo
        { spell = 24418, profession = "Cooking", skill = 150, recipe = 20075 }, -- Heavy Crocolisk Stew
    },
    [12208] = { -- Tender Wolf Meat
        { spell = 22480, profession = "Cooking", skill = 225, recipe = 18046 }, -- Tender Wolf Steak
    },
    [272941] = { -- Thick Logs
        { spell = 1291341, profession = "Cooking", skill = 200, recipe = 273101 }, -- Expert Campfire
    },
    [5470] = { -- Thunder Lizard Tail
        { spell = 6418, profession = "Cooking", skill = 100, recipe = 5488 }, -- Crispy Lizard Tail
    },
    [12202] = { -- Tiger Meat
        { spell = 15861, profession = "Cooking", skill = 175, recipe = 12231 }, -- Jungle Stew
        { spell = 1225758, profession = "Cooking", skill = 250, recipe = 238645 }, -- Prowler Steak
        { spell = 1250149, profession = "Cooking", skill = 275, recipe = 250180 }, -- Swiftstrike Steak
    },
    [1080] = { -- Tough Condor Meat
        { spell = 2547, profession = "Cooking", skill = 100, recipe = 2699 }, -- Redridge Goulash
    },
    [3712] = { -- Turtle Meat
        { spell = 3400, profession = "Cooking", skill = 175, recipe = 3737,
          quest = 555, faction = "Alliance" }, -- Soothing Turtle Bisque
        { spell = 1250145, profession = "Cooking", skill = 275, recipe = 250176 }, -- Savory Turtle Stew
        { spell = 1225763, profession = "Cooking", skill = 280, recipe = 239021 }, -- Grand Lobster Banquet
    },
    [251524] = { -- Whimsyfin
        { spell = 1252566, profession = "Cooking", skill = 85, recipe = 251526 }, -- Savory Whimsyfin Delight
    },
    [12205] = { -- White Spider Meat
        { spell = 21175, profession = "Cooking", skill = 200 }, -- Spider Sausage
    },
    [8146] = { -- Wicked Claw
        { spell = 1249968, profession = "Cooking", skill = 250, recipe = 249890 }, -- Wicked Smoothie
    },
    [7974] = { -- Zesty Clam Meat
        { spell = 20626, profession = "Cooking", skill = 225, recipe = 16767 }, -- Undermine Clam Chowder
        { spell = 1250158, profession = "Cooking", skill = 275, recipe = 250189 }, -- Clam Linguine
    },
}

local function SpellName(spellID)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    return name or ("spell #" .. spellID)
end

-- An ingredient as common as Mild Spices goes into dozens of recipes, so a
-- tooltip lists at most this many, the ones nearest your skill.
local MOST_USES = 8

-- The uses to list, by skill, and how many are left out: all of them when
-- they fit, else the MOST_USES whose skill is nearest yours (the lowest
-- without the profession).
local function NearestUses(uses, skill)
    if #uses <= MOST_USES then
        return uses, 0
    end
    local ranked = {}
    for i, use in ipairs(uses) do
        ranked[i] = use
    end
    table.sort(ranked, function(a, b)
        local da, db = math.abs((a.skill or 1) - (skill or 0)), math.abs((b.skill or 1) - (skill or 0))
        if da ~= db then
            return da < db
        end
        return (a.skill or 1) < (b.skill or 1)
    end)
    local shown = {}
    for i = 1, MOST_USES do
        shown[i] = ranked[i]
    end
    table.sort(shown, function(a, b)
        return (a.skill or 1) < (b.skill or 1)
    end)
    return shown, #uses - MOST_USES
end

-- Under the item: each profession that uses it as a header in Sink's colour, then its
-- recipes as "[50] Longjaw Mud Snapper (Recipe)", the skill it needs first
-- and where it is learned last: (Recipe), (Trainer) or (Quest). Green
-- when you know it, yellow when you do not but your skill would let you
-- learn it, red when it would not (or you lack the profession). Grey for one
-- only the other faction can get. A recipe from a quest you do not know yet
-- names the quest under it.
local function AddReagentLines(tooltip, data)
    if not (ns.db and ns.db.reagentTooltips ~= false) or not tooltip or not tooltip.AddLine then
        return
    end
    if tooltip.IsForbidden and tooltip:IsForbidden() then
        return
    end
    local uses = data and data.id and ns.reagents[data.id]
    if not uses then
        return
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local professions, byProfession = {}, {}
    for _, use in ipairs(uses) do
        if not byProfession[use.profession] then
            byProfession[use.profession] = {}
            professions[#professions + 1] = use.profession
        end
        table.insert(byProfession[use.profession], use)
    end
    for _, profession in ipairs(professions) do
        tooltip:AddLine(profession, ns.accent.r, ns.accent.g, ns.accent.b)
        local skill = Skill(profession)
        local shown, more = NearestUses(byProfession[profession], skill)
        for _, use in ipairs(shown) do
            -- Where it is learned, short and grey: a quest reward, a recipe item, or the trainer.
            local from = (use.quest and "Quest") or (use.recipe and "Recipe") or "Trainer"
            local text = ("[%d] %s %s(%s)|r"):format(use.skill or 1, SpellName(use.spell), ns.grey.hex, from)
            local color
            if use.faction and faction and use.faction ~= faction then
                color = ns.grey
            elseif Known(use) then
                color = ns.known
            elseif skill and skill >= (use.skill or 1) then
                color = ns.active
            else
                color = ns.missing
            end
            tooltip:AddLine(text, color.r, color.g, color.b)
            -- A quest reward: the quest in the yellow of quest links, and who gives it.
            if use.quest and color ~= ns.known and color ~= ns.grey then
                local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(use.quest)
                if not title or title == "" then
                    title = "quest #" .. use.quest
                    if C_QuestLog.RequestLoadQuestByID then
                        C_QuestLog.RequestLoadQuestByID(use.quest)
                    end
                end
                tooltip:AddLine(("    from |cffffff00%s|r%s"):format(title,
                    use.giver and (", " .. use.giver) or ""), ns.grey.r, ns.grey.g, ns.grey.b)
            end
        end
        if more > 0 then
            tooltip:AddLine(("+%d more"):format(more), ns.grey.r, ns.grey.g, ns.grey.b)
        end
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddReagentLines)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("SKILL_LINES_CHANGED")
pcall(frame.RegisterEvent, frame, "SPELLS_CHANGED") -- see Core.lua
frame:SetScript("OnEvent", function()
    ns.RefreshProfessionList()
end)
