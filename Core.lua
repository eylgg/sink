--------------------------------------------------------------------------------
-- Sink / Core.lua
--
-- Loads first: the saved variables (SinkDB) with their defaults, and what
-- the other files share through ns: the colours and marks, printing, the
-- version, and the helpers for values the game keeps secret.
--------------------------------------------------------------------------------

local ADDON_NAME, ns = ...

-- Saved-variable defaults.
ns.defaults = {
    -- QuestItems.lua
    questItemWarnings = true,  -- tooltip line, bag tint and tracker list for quest items that are safe to delete
    questItems = {},           -- rules added in game: [itemID] = questID

    -- Recipes.lua
    recipeTooltips = true,     -- vendor tooltips list their recipes with a check or a cross
    recipeVendors = {},        -- vendors added in game: [npcID] = { name = ..., recipes = { itemID, ... } }

    -- Errors.lua
    muteErrors = true,         -- hide "Not enough energy" and "not ready yet" errors, text and voice, when spamming

    -- MapPins.lua
    mapIcons = true,           -- icons with tooltips on the world map
    mapPins = {},              -- icons added in game: [uiMapID] = { { name = ..., x = ..., y = ... }, ... }
    showAllTrainers = false,   -- every profession trainer, not just the ones for your professions
    showAllClassTrainers = false, -- every class trainer, not just your class's
    showDungeons = true,       -- dungeon entrances, with their quests on the tooltip
    showFlightMasters = true,  -- flight masters, grey until discovered
    showClassTrainers = true,  -- the kinds of map icon, ns.PIN_KINDS in MapPins.lua: each can be switched off
    showProfessionTrainers = true,
    showWeaponMasters = true,
    showInnkeepers = true,
    showBankers = true,
    showAuctioneers = true,
    showStableMasters = true,
    showBooks = true,
    showQuestNPCs = true,
    showTravel = true,         -- zeppelins, boats and teleporters
    showEntrances = true,      -- cave and crypt entrances
    showEliteQuests = true,    -- elites that drop an item starting a quest, until that quest is done
    showRares = true,          -- rare mobs
    showOtherPins = true,      -- vendors and anything else
    knownFlightPaths = {},     -- flight paths seen at a flight master: [player GUID] = { [nodeID] = true }

    -- Weapons.lua
    weaponTooltips = true,     -- weapon master tooltips, map icon lines and reminders
    weaponMasters = {},        -- masters recorded from the trainer window: [npcID] = { name = ..., skills = { id, ... } }
    weaponLevels = {},         -- level a skill needs, as a trainer window showed it: [skillID] = level

    -- Professions.lua
    reagentTooltips = true,    -- reagent tooltips list the recipes that use them, with a check or a cross

    -- Trainers.lua

    -- Splits.lua
    splits = false,            -- record level times and show the splits window
    splitsShown = 5,           -- finished levels the splits window lists under the current one
    splitRuns = {},            -- /played when each level was reached: ["Name-Realm"] = { reached = { [level] = seconds } }
    -- splitsPoint: where the splits window was dragged to, { point, relativePoint, x, y }

    -- Tracker.lua
    tracker = true,            -- show the Sink tracker window
    trackerCollapsed = false,  -- the whole tracker folded to its title
    trackerTalents = true,     -- the Talents section is in the tracker, while you have points to spend
    trackerCurrentDungeon = true, -- the Current Dungeon section, while you are in a dungeon Sink knows
    trackerTracking = true,    -- the Tracking section is in the tracker, while a gathering tracking is off
    trackerQuestItems = true,  -- the Quest Items section is in the tracker, while there are some to delete
    trackerDungeons = true,    -- the Dungeons section is in the tracker
    trackerClassTraining = true, -- the Class Training section is in the tracker
    trackerWeaponSkills = true, -- the Weapon Skills section is in the tracker
    ignoredTraining = {},      -- skills kept out of the tracker's Class Training: [class][name] = true, all ranks
    ignoredDungeons = {},      -- dungeons kept out of the tracker's Dungeons: [player GUID] = { [instanceID] = true }
    trackerFolded = {},        -- sections folded to their header: [key] = true, key "dungeons", "classTraining", ...;
                               -- and dungeons folded to their name, key "dungeon" .. instance ID
    -- trackerPoint: where the tracker was dragged to, { point, relativePoint, x, y }
}

-- Sink's identity colour, used for everything it prints or draws: the chat
-- prefix, the sold-by line on recipe tooltips, vendor names in the recipe list,
-- the ring and tooltip title of each map icon. Change it here and everything
-- follows. Colours that carry meaning are not tied to it: green on and red
-- off, the yellow quest item warnings, the known and missing marks below.
--
-- This is oklch(0.558 0.146 230) in sRGB; the red channel lands just below
-- zero, so it is a hair outside sRGB and clamps to 0. As hex: #0081B8.
ns.accent = { r = 0.0, g = 0.505, b = 0.721 }

-- The same colour as a chat escape, and a helper that wraps text in it.
ns.accentHex = ("|cff%02x%02x%02x"):format(
    math.floor(ns.accent.r * 255 + 0.5), math.floor(ns.accent.g * 255 + 0.5), math.floor(ns.accent.b * 255 + 0.5))

function ns.Accent(text)
    return ns.accentHex .. tostring(text) .. "|r"
end

local PREFIX = ns.Accent("Sink") .. ": "

-- Marks and colours shared by the tooltip lines and lists. Known is a green
-- check with green text, missing a red cross with red text, and something that
-- does not apply to you is plain grey text with no mark. A quest in your log
-- is the one in between: a yellow waiting mark with yellow text.
ns.CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t"
ns.CROSS = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14|t"
ns.WAIT = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14:14|t"
ns.known = { r = 0.1, g = 1.0, b = 0.1, hex = "|cff1aff1a" }
ns.missing = { r = 1.0, g = 0.1, b = 0.1, hex = "|cffff1a1a" }
ns.grey = { r = 0.5, g = 0.5, b = 0.5, hex = "|cff808080" }
ns.active = { r = 1.0, g = 0.8, b = 0.0, hex = "|cffffcc00" }

-- Dungeon names, in the teal of the swirl on the game's Dungeon map icon
-- (its bright tones are about #4FA6AB), lifted a little to read on dark
-- backgrounds: #5CBEC4.
ns.dungeonColor = { r = 0.361, g = 0.745, b = 0.769, hex = "|cff5cbec4" }

-- Whether a value is one the game hides from addons. In combat and in
-- instances some unit data (GUIDs, names, tooltip text) comes as a secret
-- value: it can be passed along, but reading, comparing or joining it is an
-- error blamed on Sink. Check with this first and leave a secret one alone.
function ns.Secret(value)
    return (issecretvalue ~= nil and issecretvalue(value)) or (canaccessvalue ~= nil and not canaccessvalue(value))
end

-- The value, or nil when it is secret.
function ns.Readable(value)
    if ns.Secret(value) then
        return nil
    end
    return value
end

-- Your standing with a reputation faction, 1 (Hated) to 8 (Exalted), or nil.
local function Standing(factionID)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, data = pcall(C_Reputation.GetFactionDataByID, factionID)
        if ok and data and data.reaction then
            return data.reaction
        end
    end
    if GetFactionInfoByID then
        local ok, _, _, standing = pcall(GetFactionInfoByID, factionID)
        if ok then
            return standing
        end
    end
    return nil
end

-- What an NPC's reputation faction takes off their prices: 5% at Friendly,
-- 10% at Honored, 15% at Revered and 20% at Exalted.
local DISCOUNTS = { [5] = 0.05, [6] = 0.10, [7] = 0.15, [8] = 0.20 }

-- A price in copper after your discount with the NPC's faction; the price as
-- it is without a faction.
function ns.Discounted(copper, factionID)
    local discount = factionID and DISCOUNTS[Standing(factionID) or 0] or 0
    return math.floor(copper * (1 - discount) + 0.5)
end

-- The version from the TOC's "## Version" line, so it always matches the release.
function ns.Version()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getMetadata and getMetadata(ADDON_NAME, "Version") or "?"
end

function ns.Print(msg)
    print(PREFIX .. tostring(msg))
end

-- Merge defaults into the saved table without overwriting existing values.
local function InitSavedVariables()
    SinkDB = SinkDB or {}
    for key, value in pairs(ns.defaults) do
        if SinkDB[key] == nil then
            if type(value) == "table" then
                -- Give the saved table its own copy so edits never touch the defaults.
                local copy = {}
                for k, v in pairs(value) do
                    copy[k] = v
                end
                value = copy
            end
            SinkDB[key] = value
        end
    end
    SinkDB.classSkills = nil -- trainer windows were once recorded here; the lists are in Trainers.lua now
    SinkDB.trackerClassSkills = nil -- renamed trackerClassTraining
    -- Player frame centering was removed.
    SinkDB.enabled, SinkDB.offsetX, SinkDB.offsetY = nil, nil, nil
    -- Flight paths were once kept by "Name-Realm"; now by GUID, "Player-...".
    for key in pairs(SinkDB.knownFlightPaths or {}) do
        if not tostring(key):find("^Player%-") then
            SinkDB.knownFlightPaths[key] = nil
        end
    end
    ns.db = SinkDB
end

-- On the Forever beta, registering an event the client does not know throws and
-- aborts the rest of the file. Other files wrap anything not guaranteed to
-- exist in pcall.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, name)
    if name == ADDON_NAME then
        InitSavedVariables()
    end
end)
