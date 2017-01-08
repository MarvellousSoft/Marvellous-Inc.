local Color = require "classes.color.color"
local StepManager = require "classes.stepmanager"
local Mail = require "classes.tabs.email"
local OpenedMail = require "classes.opened_email"
local Info = require "classes.tabs.info"
local FX = require "classes.fx"

--[[ LoreManager
Used to handle all lore events.
Lore events are events that are triggered by completing puzzles. Checkout lore_events/README.md for more info.
]]

local lore = {}

-- Timer used for everything related to lore
local timer = Timer.new()
lore.timer = timer
-- Events triggered by completing puzzles
local events = {}
lore.done_events = {} -- list of finished events
-- Puzzles already completed
lore.puzzle_done = {}

-- Automatically adds all .lua's in classes/lore_events
function lore.init()
    local evts = love.filesystem.getDirectoryItems("lore_events")
    for _, file in ipairs(evts) do
        if #file > 4 and file:sub(-4) == '.lua' then
            file = file:sub(1, -5)
            events[file] = require("lore_events." .. file)
        end
    end
end

-- Used to remove events already done by the user (in a previous game)
function lore.set_done_events(done_events)
    lore.done_events = done_events
    for _, id in ipairs(done_events) do
        events[id] = nil
    end
end

-- Check for events that may trigger now
function lore.check_all()
    if not events then return end
    for id, evt in pairs(events) do
        local count_done = 0
        for _, puzzle in ipairs(evt.require_puzzles) do
            if lore.puzzle_done[puzzle] then
                count_done = count_done + 1
            end
        end
        local at_least = evt.require_puzzles.at_least or #evt.require_puzzles
        if count_done >= at_least then
            events[id] = nil
            table.insert(lore.done_events, id)
            timer:after(evt.wait or 0, evt.run)
        end
    end
end

-- Marks that a puzzle was completed
function lore.mark_completed(puzzle)
    StepManager.pause()
    if lore.puzzle_done[puzzle.id] then
        puzzle.already_completed()
    else
        lore.puzzle_done[puzzle.id] = true
        puzzle.first_completed()

        lore.check_all()
    end
end

-- Message to show when a puzzle was already completed before
function lore.already_completed()
    PopManager.new("Puzzle completed (again)",
        "You did what you had already done, and possibly killed some more test subjects.\n\nGreat.",
        Color.yellow(), {
            func = function()
                ROOM:disconnect()
            end,
            text = "Go back",
            clr = Color.black()
        })
end

-- Default level completed action
function lore.default_completed()
    PopManager.new("Puzzle completed",
        "You will be emailed your next task shortly.",
        Color.green(), {
            func = function()
                ROOM:disconnect()
            end,
            text = " ok ",
            clr = Color.black()
        })
end

function lore.update(dt)
    timer:update(dt)
end

return lore
