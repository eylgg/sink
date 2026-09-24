--------------------------------------------------------------------------------
-- Sink / Splits.lua
--
-- Leveling splits: how long each level took this character, in /played time.
-- Off by default. The Splits tab of the options window turns it on, sets how
-- many levels the splits window shows, and lists every level recorded. While
-- it is on, a small movable window shows the current level's time ticking and
-- the times of the last few levels. Nothing else: no chat lines, no tooltips.
--
-- Time is /played, so time logged out never counts. The server answers
-- RequestTimePlayed with TIME_PLAYED_MSG: the total, and the time on the
-- current level, so total - levelTime is exactly when this level started.
-- That is asked when splits turn on or you log in, and again just after each
-- level up; in between the total is carried forward with GetTime().
-- Blizzard's chat frames print every answer, so for our own requests they
-- stop listening to that one event until it arrives; a /played you type
-- yourself prints as usual.
--
-- Levels are kept per character in SinkDB.splitRuns. A level's time needs
-- both its start and the next level's, so levels before splits were turned on
-- stay blank. Until the beta's saved-variables bug (README) is fixed they
-- last one session, but the current level's start is exact after every login
-- because it comes from the server.
--------------------------------------------------------------------------------

local _, ns = ...

local playedTotal, playedAt -- /played total, and GetTime() when the server said so
local expectedLevel         -- level just reached, in case UnitLevel lags the answer
local mutedFrames = {}      -- chat frames not listening while our request is out
local unmuteTimer
local window, ticker
local list                  -- the options page's list: { child, columns }

local function Enabled()
    return ns.db ~= nil and ns.db.splits == true
end

--------------------------------------------------------------------------------
-- This character's levels
--------------------------------------------------------------------------------

local function MyReached()
    local name = UnitName("player")
    local realm = (GetRealmName and GetRealmName() or ""):gsub("%s+", "")
    local key = name .. "-" .. realm
    ns.db.splitRuns = ns.db.splitRuns or {}
    local run = ns.db.splitRuns[key] or { reached = {} }
    ns.db.splitRuns[key] = run
    return run.reached
end

-- Seconds played now, or nil until the server has answered once.
local function PlayedNow()
    if not playedTotal then
        return nil
    end
    return playedTotal + (GetTime() - playedAt)
end

local function CurrentLevel()
    return math.max(UnitLevel("player") or 1, expectedLevel or 0)
end

-- Seconds a level took, the time so far on the current one, or nil.
local function LevelTime(reached, level)
    local from = reached[level]
    if not from then
        return nil
    end
    if level == CurrentLevel() then
        local now = PlayedNow()
        return now and (now - from)
    end
    local to = reached[level + 1]
    return to and (to - from)
end

local function Clock(seconds)
    seconds = math.floor(seconds + 0.5)
    local h = math.floor(seconds / 3600)
    local m = math.floor(seconds % 3600 / 60)
    local s = seconds % 60
    if h > 0 then
        return ("%d:%02d:%02d"):format(h, m, s)
    end
    return ("%d:%02d"):format(m, s)
end

--------------------------------------------------------------------------------
-- The splits window: the current level ticking, and the last few levels
--------------------------------------------------------------------------------

local ROW_HEIGHT = 14

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint()
    ns.db.splitsPoint = { point, relativePoint, x, y }
end

local function CreateWindow()
    local frame = CreateFrame("Frame", "SinkSplitsFrame", UIParent, "TooltipBackdropTemplate")
    frame:SetSize(120, ROW_HEIGHT + 12)
    local p = ns.db.splitsPoint
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, 120)
    end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame.levels = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.levels:SetPoint("TOPLEFT", 8, -6)
    frame.levels:SetJustifyH("LEFT")
    frame.levels:SetSpacing(2)
    frame.times = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.times:SetPoint("TOPRIGHT", -8, -6)
    frame.times:SetJustifyH("RIGHT")
    frame.times:SetSpacing(2)
    frame:Hide()
    return frame
end

local function UpdateWindow()
    if not window or not window:IsShown() then
        return
    end
    local reached = MyReached()
    local current = CurrentLevel()
    local count = ns.db.splitsShown or 5
    local levels, times = {}, {}
    for level = current, math.max(1, current - count), -1 do
        local time = LevelTime(reached, level)
        local color = level == current and ns.accentHex or ""
        levels[#levels + 1] = color .. "Level " .. level .. (color ~= "" and "|r" or "")
        if time then
            times[#times + 1] = color .. Clock(time) .. (color ~= "" and "|r" or "")
        else
            times[#times + 1] = ns.grey.hex .. "-|r"
        end
    end
    window.levels:SetText(table.concat(levels, "\n"))
    window.times:SetText(table.concat(times, "\n"))
    window:SetHeight(math.max(window.levels:GetStringHeight(), ROW_HEIGHT) + 12)
end

--------------------------------------------------------------------------------
-- The list on the options window's Splits tab
--------------------------------------------------------------------------------

-- Builds the list at y on the page and returns the height it takes: a
-- scrolling frame of three columns, level, time on it, and /played when reached.
function ns.BuildSplitsList(page, y)
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -y)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(self, width)
        child:SetWidth(width)
    end)

    local columns = {}
    local function column(point, x, justify, heading)
        local text = child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("TOP" .. point, x, 0)
        text:SetJustifyH(justify)
        text:SetSpacing(3)
        columns[#columns + 1] = { text = text, heading = heading }
        return text
    end
    column("LEFT", 4, "LEFT", "Level")
    column("LEFT", 110, "RIGHT", "Time"):SetWidth(90)
    column("RIGHT", -4, "RIGHT", "Reached at")
    list = { child = child, columns = columns }
    ns.RefreshSplitsList()
    return 0 -- it fills the rest of the page
end

function ns.RefreshSplitsList()
    if not list or not list.child:IsVisible() then
        return
    end
    local reached = MyReached()
    local rows = { {}, {}, {} }
    for i, column in ipairs(list.columns) do
        rows[i][1] = NORMAL_FONT_COLOR_CODE .. column.heading .. "|r"
    end
    local current = CurrentLevel()
    for level = 1, current do
        local time = LevelTime(reached, level)
        local color = level == current and ns.accentHex or (time and "" or ns.grey.hex)
        local close = color ~= "" and "|r" or ""
        rows[1][#rows[1] + 1] = color .. level .. close
        rows[2][#rows[2] + 1] = color .. (time and Clock(time) or "-") .. close
        rows[3][#rows[3] + 1] = color .. (reached[level] and Clock(reached[level]) or "-") .. close
    end
    for i, column in ipairs(list.columns) do
        column.text:SetText(table.concat(rows[i], "\n"))
    end
    list.child:SetHeight(list.columns[1].text:GetStringHeight() + 4)
end

--------------------------------------------------------------------------------
-- /played, without the chat lines
--------------------------------------------------------------------------------

local function Unmute()
    if unmuteTimer then
        unmuteTimer:Cancel()
        unmuteTimer = nil
    end
    for frame in pairs(mutedFrames) do
        pcall(frame.RegisterEvent, frame, "TIME_PLAYED_MSG")
    end
    wipe(mutedFrames)
end

local function RequestPlayed()
    if not Enabled() or not RequestTimePlayed then
        return
    end
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local frame = _G["ChatFrame" .. i]
        if frame and frame:IsEventRegistered("TIME_PLAYED_MSG") then
            frame:UnregisterEvent("TIME_PLAYED_MSG")
            mutedFrames[frame] = true
        end
    end
    -- If the answer never comes, the chat frames still get the event back.
    if unmuteTimer then
        unmuteTimer:Cancel()
    end
    unmuteTimer = C_Timer.NewTimer(10, Unmute)
    RequestTimePlayed()
end

local function Refresh()
    UpdateWindow()
    ns.RefreshSplitsList()
end

local function OnTimePlayed(total, levelTime)
    -- Every frame's handler for this event has run by the next frame.
    C_Timer.After(0, Unmute)
    if not Enabled() or not (total and levelTime) or ns.Secret(total) or ns.Secret(levelTime) then
        return
    end
    playedTotal, playedAt = total, GetTime()
    MyReached()[CurrentLevel()] = total - levelTime
    Refresh()
end

local function OnLevelUp(level)
    expectedLevel = tonumber(level)
    if not Enabled() then
        return
    end
    local now = PlayedNow()
    if now and expectedLevel then
        MyReached()[expectedLevel] = now -- the server's answer below corrects it
    end
    Refresh()
    C_Timer.After(2, RequestPlayed)
end

-- Show or hide everything for the current setting. Options.lua calls it when
-- "splits" or "splitsShown" changes.
function ns.ApplySplits()
    if not ns.db then
        return
    end
    if Enabled() then
        window = window or CreateWindow()
        window:Show()
        if not ticker then
            ticker = C_Timer.NewTicker(1, Refresh)
        end
        if not playedTotal then
            RequestPlayed()
        end
    else
        if window then
            window:Hide()
        end
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
    end
    Refresh()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
pcall(frame.RegisterEvent, frame, "TIME_PLAYED_MSG")
frame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if not ns.db then
        return
    end
    if event == "PLAYER_LOGIN" then
        if Enabled() then
            window = CreateWindow()
            window:Show()
            ticker = C_Timer.NewTicker(1, Refresh)
            -- The server can drop a request sent while the world is still loading.
            C_Timer.After(3, RequestPlayed)
        end
    elseif event == "TIME_PLAYED_MSG" then
        OnTimePlayed(arg1, arg2)
    elseif event == "PLAYER_LEVEL_UP" then
        OnLevelUp(arg1)
    end
end)
