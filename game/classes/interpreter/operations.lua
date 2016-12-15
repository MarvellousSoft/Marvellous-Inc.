local op = {}

--[[ Number class holds a number... Or what can become one. ]]

Number = Class {}

function Number:init(num, indir)
    self.num = num
    self.indir = indir
end

local function number_eval(mem, indir, orig)
    if indir == 0 then return orig end
    return mem:get(number_eval(mem, indir - 1, orig))
end

-- returns nil if something invalid happened
function Number:evaluate()
    return number_eval(Util.findId("code_tab").memory, self.indir, self.num)
end

local function valid_num(x) return type(x) == 'number' and x >= -999 and x <= 999 end


-- Returns a new Number created from string s, or nil if it is invalid
function Number.create(s)
    if s:match("%a") or not s:match("%d") then return end
    if not s:match("[%[%]]") then return valid_num(tonumber(s)) and Number(tonumber(s), 0) end
    if s:match("[%[%]0-9]+") ~= s then return end
    local lvl, bak = 0, 0
    local pref_ok, suff_start = false, false
    for i = 1, #s do
        if s:sub(i, i):match("%d") then pref_ok = true end
        if s:sub(i, i) == ']' and not suff_start then
            suff_start = true
            bak = lvl
        end
        if (pref_ok and s:sub(i, i) == '[') or (not pref_ok and s:sub(i, i) == ']') then return end
        if suff_start and s:sub(i, i) ~= ']' then return end
        if s:sub(i, i) == '[' then lvl = lvl + 1 end
        if s:sub(i, i) == ']' then bak = bak - 1 end
    end
    if bak ~= 0 or not suff_start then return end
    local num = tonumber(s:sub(lvl + 1, #s - lvl))
    if num < -999 or num > 999 then return end
    return Number(num, lvl)
end

--[[
Operations are classes that have the following fields:
execute - function that executes the operation, and returns the label of the next operation to be executed, or nil
]]

Walk = Class {}

local function walk_check(t)
    if #t > 3 then return end
    if #t == 1 then return Walk() end
    local nums, alps = 0, 0
    for i = 2, #t do
        if t[i]:match("%a+") ~= t[i] and not Number.create(t[i]) then
            return
        else
            nums = nums + (Number.create(t[i]) and 1 or 0)
            alps = alps + (t[i]:match("%a+") == t[i] and 1 or 0)
        end
    end
    if nums > 1 or alps > 1 then return end
    local w = Walk()
    local accepted = {north = "north", west = "west", east = "east", south = "south",
    up = "north", down = "south", left = "west", right = "east"}
    for i = 2, #t do
        if Number.create(t[i]) then
            w.x = Number.create(t[i])
            if w.x.indir == 0 and w.x.num <= 0 then
                return
            end
        else
            if not accepted[t[i]] then
                return
            else
                w.dir = accepted[t[i]]
            end
        end
    end
    return w
end

function Walk.create(t)
    return walk_check(t) or "Wrong 'walk' parameters"
end

function Walk:execute()
    if not self.x then StepManager:walk(nil, self.dir) return end
    local y = self.x:evaluate()
    -- invalid! is an invalid label (because of the '!')
    if type(y) ~= 'number' then return y end
    if y < 0 then return "Trying to walk " .. y .. " steps" end
    if y == 0 then return end
    StepManager:walk(y, self.dir)
end

Turn = Class {
    init = function(self, dir)
        self.dir = dir
    end,
    execute = function(self)
        if self.dir == "counter" or self.dir == "clock" then
            StepManager[self.dir](StepManager)
        else
            StepManager:turn(self.dir)
        end
    end
}

local function turn_check(t)
    if #t ~= 2 then return end
    local accepted = {counter = "counter", clock = "clock", north = "north", west = "west", east = "east", south = "south",
    up = "north", down = "south", left = "west", right = "east"}
    if not accepted[t[2]] then return end
    return Turn(accepted[t[2]])
end

function Turn.create(t)
    return turn_check(t) or "Wrong 'turn' parameters"
end


Nop = Class {
    init = function(self) end,
    execute = function(self) end,
    type = "NOP"
}

-- check wheter s is a valid label, and in that case returns it
local function valid_label(s)
    if s:match("%w+") == s then return s end
end

-- Jmp --
Jmp = Class {
    init = function(self, lab) self.lab = lab end,
    execute = function(self) return self.lab end
}

function Jmp.create(t)
    if #t ~= 2 then return end
    return valid_label(t[2]) and Jmp(t[2])
end

-- checks whether s is a valid register, and in that case returns it
local function valid_register(s)
    local v = Number.create(s)
    if not v then return end
    if v.indir == 0 and (v.num < 0 or v.num >= Util.findId("memory").slots) then return end
    return v
end

-- Used by all OP dst val commands
local function dst_val_check(t)
    if #t ~= 3 then return end
    return valid_register(t[2]), Number.create(t[3])
end

-- Mov --
Mov = Class {}

function Mov.create(t)
    local m = Mov()
    m.dst, m.val = dst_val_check(t)
    if m.dst and m.val then return m end
    return "Incorrect 'mov' parameters"
end

function Mov:execute()
    local dst = self.dst:evaluate()
    local val = self.val:evaluate()
    if type(dst) ~= 'number' then return dst end
    if type(val) ~= 'number' then return val end
    return Util.findId("memory"):set(dst, val)
end

-- Limits the values in the range -999 .. 999, wraping automatically
local function mod(val)
    val = val + 999
    if val < 0 then val = 999 - val end
    val = val % 1999
    return val - 999
end

-- Add --
Add = Class {}

function Add.create(t)
    local a = Add()
    a.dst, a.val = dst_val_check(t)
    if a.dst and a.val then return a end
    return "Incorrect 'add' parameters"
end

function Add:execute()
    local dst = self.dst:evaluate()
    local val = self.val:evaluate()
    if type(dst) ~= 'number' then return dst end
    if type(val) ~= 'number' then return val end
    local mem = Util.findId("memory")
    local prev = mem:get(dst)
    if type(prev) ~= 'number' then return prev end
    return mem:set(dst, mod(prev + val))
end

-- Sub --
Sub = Class {}

function Sub.create(t)
    local a = Sub()
    a.dst, a.val = dst_val_check(t)
    if a.dst and a.val then return a end
    return "Incorrect 'sub' parameters"
end

function Sub:execute()
    local dst = self.dst:evaluate()
    local val = self.val:evaluate()
    if type(dst) ~= 'number' then return dst end
    if type(val) ~= 'number' then return val end
    local mem = Util.findId("memory")
    local prev = mem:get(dst)
    if type(prev) ~= 'number' then return prev end
    return mem:set(dst, mod(prev - val))
end

-- init for jgt jlt jge jle
local function vvl_init(self, v1, v2, lab)
    self.v1 = v1
    self.v2 = v2
    self.lab = lab
end

local function vvl_execute(self)
    local a, b = self.v1:evaluate(), self.v2:evaluate()
    if type(a) ~= 'number' then return a end
    if type(b) ~= 'number' then return b end
    if self.comp(a, b) then return self.lab end
end

-- Used by all val1 val2 lab operations
local function vvl_check(t, class)
    if #t ~= 4 then return end
    local v1, v2, lab = Number.create(t[2]), Number.create(t[3]), valid_label(t[4])
    if v1 and v2 and lab then return class(v1, v2, lab) end
end

-- Jgt - Jump greater than --
Jgt = Class {init = vvl_init, comp = function(a, b) return a > b end, execute = vvl_execute}
-- Jge - Jump greater or equal --
Jge = Class {init = vvl_init, comp = function(a, b) return a >= b end, execute = vvl_execute}
-- Jlt - Jump lesser than --
Jlt = Class {init = vvl_init, comp = function(a, b) return a < b end, execute = vvl_execute}
-- Jle - Jump lesser or equal --
Jle = Class {init = vvl_init, comp = function(a, b) return a <= b end, execute = vvl_execute}
-- Jle - Jump lesser or equal --
Jeq = Class {init = vvl_init, comp = function(a, b) return a == b end, execute = vvl_execute}
-- Jle - Jump lesser or equal --
Jne = Class {init = vvl_init, comp = function(a, b) return a ~= b end, execute = vvl_execute}

-- Read --
Read = Class{}

function Read:create(t)
    if #t > 3 or #t <= 1 then return end
    local obj = self()
    local accepted = {north = "north", west = "west", east = "east", south = "south",
    up = "north", down = "south", left = "west", right = "east"}
    if t[3] and not accepted[t[3]] then return end
    obj.reg, obj.dir = valid_register(t[2]), accepted[t[3]]
    if obj.reg then return obj end
end

function Read:execute()
    if self.dir then StepManager:turn(self.dir) end
    local console = ROOM:next_block()
    if not console or console.tp ~= "console" then return "Trying to read from non-console" end
    local nx = console:input()
    if not nx then return "No more input on console" end
    return Util.findId("memory"):set(self.reg:evaluate(), nx)
end

-- Write --
Write = Class{}

function Write:create(t)
    if #t > 3 or #t <= 1 then return end
    local obj = self()
    local accepted = {north = "north", west = "west", east = "east", south = "south",
    up = "north", down = "south", left = "west", right = "east"}
    if t[3] and not accepted[t[3]] then return end
    obj.num, obj.dir = Number.create(t[2]), accepted[t[3]]
    if obj.num then return obj end
end

function Write:execute()
    if self.dir then StepManager:turn(self.dir) end
    local console = ROOM:next_block()
    if not console or console.tp ~= "console" then return "Trying to write to non-console" end
    local val = self.num:evaluate()
    if type(val) ~= 'number' then return val end
    return console:write(val)
end

local DIR_CONV = {
    north = NORTH, up = NORTH,
    east = EAST, right = EAST,
    south = SOUTH, down = SOUTH,
    west = WEST, left = WEST
}

-- Pickup
Pickup = Class{
    init = Turn.init
}

function Pickup.create(t)
    if #t > 2 then return end
    local accepted = {north = "north", west = "west", east = "east", south = "south",
    up = "north", down = "south", left = "west", right = "east"}
    if t[2] and not accepted[t[2]] then return end
    return Pickup(accepted[t[2]])
end

function Pickup:execute()
    if ROOM.bot.inv then return "Not enough free hands" end
    if not ROOM:next_block(DIR_CONV[self.dir]).pickable then return "Unpickable object" end
    if self.dir then
        StepManager:turn(self.dir)
    end
    StepManager:pickup()
end

Drop = Class{
    init = Turn.init
}

function Drop.create(t)
    if #t > 2 then return end
    local accepted = {north = "north", west = "west", east = "east", south = "south",
    up = "north", down = "south", left = "west", right = "east"}
    if t[2] and not accepted[t[2]] then return end
    return Drop(accepted[t[2]])
end

function Drop:execute()
    if not ROOM.bot.inv then return "There is nothing left to drop but my self esteem" end
    if ROOM:blocked(DIR_CONV[self.dir]) then return "Dropping obstructed by object" end
    if self.dir then
        StepManager:turn(self.dir)
    end
    StepManager:drop()
end

function op.read(t)
    if #t == 0 then return Nop() end
    if t[1] == 'walk' then
        return Walk.create(t)
    elseif t[1] == 'turn' then
        return Turn.create(t)
    elseif t[1] == 'nop' then
        if #t ~= 1 then return "Incorrect # of 'nop' parameters"  end
        return Nop()
    elseif t[1] == 'jmp' then
        return Jmp.create(t)
    elseif t[1] == 'mov' then
        return Mov.create(t)
    elseif t[1] == 'add' then
        return Add.create(t)
    elseif t[1] == 'sub' then
        return Sub.create(t)
    elseif t[1] == 'jgt' then
        return vvl_check(t, Jgt)
    elseif t[1] == 'jge' then
        return vvl_check(t, Jge)
    elseif t[1] == 'jlt' then
        return vvl_check(t, Jlt)
    elseif t[1] == 'jle' then
        return vvl_check(t, Jle)
    elseif t[1] == 'jeq' then
        return vvl_check(t, Jeq)
    elseif t[1] == 'jne' then
        return vvl_check(t, Jne)
    elseif t[1] == 'read' then
        return Read:create(t)
    elseif t[1] == 'write' then
        return Write:create(t)
    elseif t[1] == 'pickup' then
        return Pickup.create(t)
    elseif t[1] == 'drop' then
        return Drop.create(t)
    end
end

return op
