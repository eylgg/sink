--------------------------------------------------------------------------------
-- Sink / Errors.lua
--
-- Hides the errors that repeat on every press when you spam an ability: "Not
-- enough energy", "Not enough mana", "Ability is not ready yet" and the like.
-- Both the red text at the top of the screen and the voice line go. On by
-- default; "/sink errors off" or the checkbox in the options window turns it off.
--
-- Why this exists on Forever: the Mainline client never shows these message
-- types at all, they sit in UIErrorsFrame's BLACK_LISTED_MESSAGE_TYPES table,
-- and a blacklisted type gets neither text nor sound. Forever replaces that
-- table with a single entry
-- (Blizzard_UIErrorsFrame/Camelot/UIErrorsFrameOverrides.lua) to bring the
-- Classic messages and voices back, and only throttles "Not enough mana", so
-- energy and rage users get the worst of it.
--
-- How: UIErrorsFrame:SetMessageTypeEnabled(type, false) is Blizzard's own
-- switch for putting a type back on that blacklist. Turning the mute off puts
-- each type back the way it was. Nothing else about the frame is touched.
--------------------------------------------------------------------------------

local _, ns = ...

-- Message types to mute, by the LE_GAME_ERR_* constant Blizzard's frame uses.
-- The list follows Blizzard's own Mainline blacklist: every "Not enough ..."
-- resource error plus the two cooldown errors. "Out of range" and "facing the
-- wrong way" are left alone, they tell you something the action bar does not.
-- Names the client does not know are skipped, so the Retail-only resources are
-- harmless here.
ns.mutedErrors = {
    -- not enough of a resource
    "LE_GAME_ERR_OUT_OF_MANA", "LE_GAME_ERR_OUT_OF_RAGE", "LE_GAME_ERR_OUT_OF_ENERGY",
    "LE_GAME_ERR_OUT_OF_FOCUS", "LE_GAME_ERR_OUT_OF_HEALTH", "LE_GAME_ERR_OUT_OF_COMBO_POINTS",
    "LE_GAME_ERR_OUT_OF_POWER_DISPLAY", "LE_GAME_ERR_OUT_OF_RUNES", "LE_GAME_ERR_OUT_OF_RUNIC_POWER",
    "LE_GAME_ERR_OUT_OF_SOUL_SHARDS", "LE_GAME_ERR_OUT_OF_LUNAR_POWER", "LE_GAME_ERR_OUT_OF_HOLY_POWER",
    "LE_GAME_ERR_OUT_OF_CHI", "LE_GAME_ERR_OUT_OF_PAIN", "LE_GAME_ERR_OUT_OF_ARCANE_CHARGES",
    "LE_GAME_ERR_OUT_OF_INSANITY", "LE_GAME_ERR_OUT_OF_FURY", "LE_GAME_ERR_OUT_OF_MAELSTROM",
    "LE_GAME_ERR_OUT_OF_ESSENCE",
    -- still on cooldown
    "LE_GAME_ERR_ABILITY_COOLDOWN", "LE_GAME_ERR_SPELL_COOLDOWN",
}

local muted = {}     -- messageType -> LE_GAME_ERR_* name
local restore = nil  -- while the mute is on: messageType -> blacklist state to put back when it goes off
local mutedCount = 0 -- errors hidden this session
local frame = CreateFrame("Frame")

for _, name in ipairs(ns.mutedErrors) do
    if _G[name] ~= nil then
        muted[_G[name]] = name
    end
end

local function Enabled()
    return ns.db ~= nil and ns.db.muteErrors ~= false
end

local function Available()
    return UIErrorsFrame ~= nil and UIErrorsFrame.SetMessageTypeEnabled ~= nil
end

-- Blacklist every muted type while the mute is on; put each one back to what
-- it was when the mute goes off. Safe to call any time.
local function Apply()
    if not Available() or not ns.db then
        return
    end
    if Enabled() and not restore then
        restore = {}
        for messageType in pairs(muted) do
            restore[messageType] = BLACK_LISTED_MESSAGE_TYPES ~= nil and BLACK_LISTED_MESSAGE_TYPES[messageType] == true
            UIErrorsFrame:SetMessageTypeEnabled(messageType, false)
        end
    elseif not Enabled() and restore then
        for messageType, wasBlacklisted in pairs(restore) do
            UIErrorsFrame:SetMessageTypeEnabled(messageType, not wasBlacklisted)
        end
        restore = nil
    end
end
ns.ApplyErrorMute = Apply

--------------------------------------------------------------------------------
-- /sink errors ...
--------------------------------------------------------------------------------

local function SetEnabled(value)
    if ns.SetOption then
        ns.SetOption("muteErrors", value) -- through the options window, so its checkbox follows
    else
        ns.db.muteErrors = value
        Apply()
    end
end

local function Status()
    if not Available() then
        ns.Print("ability errors: this client has no UIErrorsFrame:SetMessageTypeEnabled, so nothing is muted.")
        return
    end
    ns.Print(("ability errors are %s | %d hidden this session"):format(
        Enabled() and "|cffff0000muted|r" or "|cff00ff00shown|r", mutedCount))
end

-- The text the client shows for a message type, for "/sink errors list".
local function MessageText(messageType, name)
    if GetGameMessageInfo then
        local stringID = GetGameMessageInfo(messageType)
        local text = stringID and _G[stringID]
        if type(text) == "string" then
            return text
        end
    end
    return name
end

local function List()
    ns.Print("muted ability errors (no text, no voice)")
    for _, name in ipairs(ns.mutedErrors) do
        local messageType = _G[name]
        if messageType ~= nil then
            print(("  %s (%s)"):format(MessageText(messageType, name), name))
        end
    end
end

local function ErrorsHelp()
    ns.Print("ability error commands")
    print("  /sink errors                    status")
    print("  /sink errors on | off | toggle  hide or show these errors")
    print("  /sink errors list               the messages that are muted")
end

function ns.ErrorsCommand(arg)
    if not ns.db then
        return
    end
    local sub = (arg or ""):match("^(%S*)"):lower()

    if sub == "" or sub == "status" then
        Status()
    elseif sub == "on" or sub == "off" then
        SetEnabled(sub == "on")
        Status()
    elseif sub == "toggle" then
        SetEnabled(not Enabled())
        Status()
    elseif sub == "list" then
        List()
    else
        ErrorsHelp()
    end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UI_ERROR_MESSAGE") -- only to count what the mute hides
frame:SetScript("OnEvent", function(_, event, messageType)
    if event == "UI_ERROR_MESSAGE" then
        if restore and muted[messageType] then
            mutedCount = mutedCount + 1
        end
    elseif event == "PLAYER_LOGIN" then
        Apply()
    end
end)
