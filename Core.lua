--------------------------------------------------------------------------------
-- Sink / Core.lua
--
-- Keeps PlayerFrame horizontally centered on screen in World of Warcraft: Forever.
-- Off by default: nothing is moved until "/sink on" or the checkbox in the
-- options panel enables it, and that choice is saved.
--
-- Forever (interface 16001, game type "camelot") runs the Retail/Mainline UI, so
-- PlayerFrame is an Edit Mode "system" frame. Edit Mode re-anchors it whenever a
-- layout is applied: at login, on a layout switch, when Edit Mode closes, on a UI
-- scale change, and so on. It does that through a Lua wrapper
-- (EditModeSystemMixin:SetPointOverride), which is why
-- hooksecurefunc(PlayerFrame, "SetPoint") fires after every Blizzard reposition.
-- Each time it fires we put the frame back where we want it.
--
-- Rules this file follows:
--   * PlayerFrame is a protected frame. Never touch it in combat; retry on
--     PLAYER_REGEN_ENABLED instead.
--   * Stay out of the way while Edit Mode is open so the frame can still be
--     dragged there. Re-center when Edit Mode closes ("EditMode.Exit").
--   * Guard against our own SetPoint re-entering the hook ("applying").
--------------------------------------------------------------------------------

local ADDON_NAME, ns = ...

-- Saved-variable defaults. Offsets are in UIParent units, the same units Edit
-- Mode shows in its own position fields.
ns.defaults = {
    enabled = false, -- opt in with /sink on; nothing moves until then
    offsetX = 0,    -- horizontal offset from the center of the screen (negative = left)
    offsetY = 250,  -- height of the frame's bottom edge above the bottom of the screen

    -- QuestItems.lua
    questItemWarnings = true,  -- tooltip line, notice and popup for quest items that are safe to delete
    questItems = {},           -- rules added in game: [itemID] = questID

    -- Recipes.lua
    recipeTooltips = true,     -- vendor tooltips list their recipes with a check or a cross
    recipeVendors = {},        -- vendors added in game: [npcID] = { name = ..., recipes = { itemID, ... } }

    -- Errors.lua
    muteErrors = true,         -- hide "Not enough energy" and "not ready yet" errors, text and voice, when spamming

    -- MapPins.lua
    mapIcons = true,           -- icons with tooltips on the world map
    mapPins = {},              -- icons added in game: [uiMapID] = { { name = ..., x = ..., y = ... }, ... }
}

-- Sink's identity colour, used for everything it prints or draws: the chat
-- prefix, the "Sink:" lines on tooltips, vendor names in the recipe list, the
-- ring around each map icon. Change it here and everything follows. Colours
-- that carry meaning are not tied to it: green on and red off, the yellow quest
-- item warnings, the check and cross marks.
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
local applying = false          -- true while we are the one calling SetPoint
local pendingAfterCombat = false
local hooked = false

function ns.Print(msg)
    print(PREFIX .. tostring(msg))
end

local function IsEditModeActive()
    local manager = EditModeManagerFrame
    return manager ~= nil and manager.IsEditModeActive ~= nil and manager:IsEditModeActive()
end

local function FrameScale()
    local scale = PlayerFrame:GetScale()
    if not scale or scale <= 0 then
        return 1
    end
    return scale
end

-- Put PlayerFrame at the configured spot. Safe to call at any time.
function ns.Center()
    local db = ns.db
    if not db or not db.enabled or not PlayerFrame then
        return
    end
    if IsEditModeActive() then
        return
    end
    if InCombatLockdown() then
        pendingAfterCombat = true
        return
    end

    -- SetPoint offsets are in the frame's own (scaled) units. Convert from
    -- UIParent units the same way Edit Mode's ApplySystemAnchor does.
    local scale = FrameScale()

    applying = true
    PlayerFrame:ClearAllPoints()
    PlayerFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", db.offsetX / scale, db.offsetY / scale)
    applying = false
end

-- Put PlayerFrame back where the active Edit Mode layout says it belongs. Used
-- when the addon is switched off. It reads the anchor Edit Mode stored on the
-- frame; opening and closing Edit Mode, or /reload, does the same thing.
function ns.RestoreEditModePosition()
    if not PlayerFrame or InCombatLockdown() or IsEditModeActive() then
        return
    end
    local info = PlayerFrame.systemInfo and PlayerFrame.systemInfo.anchorInfo
    if not info then
        return
    end

    local scale = FrameScale()

    applying = true
    PlayerFrame:ClearAllPoints()
    PlayerFrame:SetPoint(info.point, info.relativeTo, info.relativePoint, info.offsetX / scale, info.offsetY / scale)
    applying = false
end

-- Run fn on the next frame so we act after whatever Blizzard code is mid-way.
local function Later(fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, fn)
    else
        fn()
    end
end

local function InstallHooks()
    if hooked or not PlayerFrame then
        return
    end
    hooked = true

    -- Fires after every Blizzard call to PlayerFrame:SetPoint (Edit Mode's
    -- ApplySystemAnchor, scale changes, ...). Our own call is skipped via "applying".
    hooksecurefunc(PlayerFrame, "SetPoint", function()
        if not applying then
            ns.Center()
        end
    end)

    -- Edit Mode closed: the frame may have been dragged there, so re-center.
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            Later(ns.Center)
        end, ns)
    end
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
    ns.db = SinkDB
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- On the Forever beta, registering an event the client does not know throws and
-- aborts the rest of the file. Wrap anything not guaranteed to exist in pcall.
pcall(frame.RegisterEvent, frame, "EDIT_MODE_LAYOUTS_UPDATED")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitSavedVariables()
        end
    elseif event == "PLAYER_LOGIN" then
        InstallHooks()
        if ns.SetupOptions then
            ns.SetupOptions()
        end
        ns.Center()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.Center()
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        -- Edit Mode handles this event too; wait a frame so it goes first.
        Later(ns.Center)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingAfterCombat then
            pendingAfterCombat = false
            ns.Center()
        end
    end
end)
