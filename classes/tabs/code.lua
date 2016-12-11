require "classes.primitive"
local Color = require "classes.color.color"
require "classes.tabs.tab"
local Parser = require "classes.interpreter.parser"
-- CODE TAB CLASS--

CodeTab = Class{
    __includes = {Tab},

    init = function(self, eps, dy)
        Tab.init(self, eps, dy)


        self.color = Color.new(0, 0, 10)

        -- Font stuff
        self.font = FONTS.fira(18)
        self.font_h = self.font:getHeight()

        -- Lines stuff
        self.line_h = math.ceil(1.1 * self.font_h)
        self.max_char = 30 -- maximum number of chars in a line
        self.line_cur = 1 -- current number of lines
        self.line_number = 20 -- maximum number of lines
        self.h = self.line_number * self.line_h
        self.lines = {}
        for i = 1, self.line_number do self.lines[i] = "" end

        -- Cursor stuff
        -- i - line number
        -- p - position in line -- may be one more than size of string
        self.cursor = {i = 1, p = 1}
        self.cursor2 = nil

        self.cursor_mult = 1
        self.cursor_timer = Timer.new()

        self.tp = "code_tab"
        self:setId "code_tab"

        Parser.parseLine("hey dude123 213a 123  ")
    end
}

function CodeTab:activate()
    love.keyboard.setKeyRepeat(true)
    self.cursor_timer.after(1, function()
        self.cursor_timer.tween(.1, self, {cursor_mult = 0}, 'out-linear')
        self.cursor_timer.every(1.3, function() self.cursor_timer.tween(.1, self, {cursor_mult = 0}, 'out-linear') end)
    end)
    self.cursor_timer.every(1.3, function() self.cursor_timer.tween(.1, self, {cursor_mult = 1}, 'in-linear') end)
end

function CodeTab:deactivate()
    love.keyboard.setKeyRepeat(false)
    self.cursor_timer.clear()
end

function CodeTab:update(dt)
    self.cursor_timer.update(dt)
end

function CodeTab:draw()
    Color.set(self.color)
    love.graphics.rectangle("fill", self.pos.x, self.pos.y, self.w, self.h)

    -- Draw lines
    Color.set(Color.green())
    love.graphics.setFont(self.font)
    for i = 0, self.line_number - 1 do
        love.graphics.print(string.format("%2d: %s", i + 1, self.lines[i + 1]), self.pos.x + 3, self.pos.y + i * self.line_h + (self.line_h - self.font_h) / 2)
    end

    -- Draw vertical line
    local c = Color.green()
    c.l = c.l / 2
    Color.set(c)
    -- line number + vertical line size
    local dx = self.font:getWidth("20:") + 5
    love.graphics.setLineWidth(.5)
    love.graphics.line(self.pos.x + dx, self.pos.y, self.pos.x + dx, self.pos.y + self.h)

    -- Draw cursor
    c.a = 150 * self.cursor_mult
    --print(self.cursor_mult)
    Color.set(c)
    local w = self.font:getWidth("a")
    local cu = self.cursor
    love.graphics.rectangle("fill", self.pos.x + dx - 2 + w * cu.p, self.pos.y + (cu.i - 1) * self.line_h + (self.line_h - self.font_h) / 2, w, self.font_h)
    c.a = 80
    Color.set(c)
    local c1, c2 = self.cursor, self.cursor2 or self.cursor
    if c1.i > c2.i or (c1.i == c2.i and c1.p > c2.p) then
        c1, c2 = c2, c1
    end
    cu = {i = c1.i, p = c1.p}
    while cu.i ~= c2.i or cu.p ~= c2.p do
        love.graphics.rectangle("fill", self.pos.x + dx - 2 + w * cu.p, self.pos.y + (cu.i - 1) * self.line_h + (self.line_h - self.font_h) / 2, w, self.font_h)
        cu.p = cu.p + 1
        if cu.p == #self.lines[cu.i] + 2 then
            cu.p = 1
            cu.i = cu.i + 1
        end
    end

    if self.exec_line then
        Color.set(Color.white())
        love.graphics.rectangle("fill", self.pos.x, self.pos.y + (self.exec_line - 1) * self.line_h, 10, 10)
    end
end

-- Delete the substring s[l..r] from string s
local function processDelete(s, l, r)
    r = r or l
    local pref = l == 1 and "" or s:sub(1, l - 1)
    local suf = r == #s and "" or s:sub(r + 1)
    return pref .. suf
end

-- Adds string c before the j-th character in s
local function processAdd(s, j, c)
    local pref = j == 1 and "" or s:sub(1, j - 1)
    local suf = s:sub(j)
    return pref .. c .. suf
end

local function deleteInterval(self, c, c2)
    if c.i == c2.i then
        local mn = math.min(c.p, c2.p)
        self.lines[c.i] = processDelete(self.lines[c.i], mn, c.p + c2.p - mn - 1)
        c.p = mn
    else
        local a, b = c, c2
        if a.i > b.i then a, b = b, a end
        if a.p - 1 + #self.lines[b.i] - b.p + 1 > self.max_char then return end
        local pref = a.p == 1 and "" or self.lines[a.i]:sub(1, a.p - 1)
        local suf = b.p == #self.lines[b.i] + 1 and "" or self.lines[b.i]:sub(b.p)
        self.lines[a.i] = pref .. suf

        local rem = b.i - a.i
        for i = a.i + 1, self.line_number - rem do
            self.lines[i] = self.lines[i + rem]
        end
        for i = self.line_number - rem + 1, self.line_number do
            self.lines[i] = ""
        end

        self.cursor = a
        self.line_cur = self.line_cur - rem
    end
    self.cursor2 = nil
end

local change_cursor = {up = true, down = true, left = true, right = true, home = true, ["end"] = true}

function CodeTab:keyPressed(key)
    if self.lock then return end
    local c = self.cursor
    if change_cursor[key] then
        if love.keyboard.isDown("lshift", "rshift") then
            self.cursor2 = self.cursor2 or {i = c.i, p = c.p}
        else
            self.cursor2 = nil
        end
    end
    if key == 'escape' then self.cursor2 = nil end
    local c2 = self.cursor2
    if not c2 and key == 'backspace' then
        if c.p == 1 and c.i == 1 then return end
        if c.p == 1 then
            if #self.lines[c.i - 1] + #self.lines[c.i] > self.max_char then return end
            c.p = #self.lines[c.i - 1] + 1
            self.lines[c.i - 1] = self.lines[c.i - 1] .. self.lines[c.i]
            for i = c.i, self.line_number - 1 do self.lines[i] = self.lines[i + 1] end
            self.lines[self.line_number] = ""
            self.line_cur = self.line_cur - 1
            c.i = c.i - 1
        else
            c.p = c.p - 1
            self.lines[c.i] = processDelete(self.lines[c.i], c.p)
        end

    elseif not c2 and key == 'delete' then
        if c.p == #self.lines[c.i] + 1 and c.i == self.line_cur then return end
        if c.p == #self.lines[c.i] + 1 then 
            if #self.lines[c.i] + #self.lines[c.i + 1] > self.max_char then return end
            self.line_cur = self.line_cur - 1
            self.lines[c.i] = self.lines[c.i]  .. self.lines[c.i + 1]
            for i = c.i + 1, self.line_number - 1 do
                self.lines[i] = self.lines[i + 1]
            end
            self.lines[self.line_number] = ""
        else
            self.lines[c.i] = processDelete(self.lines[c.i], c.p)
        end

    elseif c2 and (key == 'delete' or key == 'backspace') then
        deleteInterval(self, c, c2)

    elseif key == 'return' then
        if self.line_cur == self.line_number then return end
        self.line_cur = self.line_cur + 1
        for i = self.line_number, c.i + 2, -1 do
            self.lines[i] = self.lines[i - 1]
        end
        self.lines[c.i + 1] = c.p == #self.lines[c.i] + 1 and "" or self.lines[c.i]:sub(c.p)
        self.lines[c.i] = c.p == 1 and "" or self.lines[c.i]:sub(1, c.p - 1)
        c.p = 1
        c.i = c.i + 1
    elseif key == 'left' then
        if c.p > 1 then c.p = c.p - 1 end

    elseif key == 'right' then
        if c.p < #self.lines[c.i] + 1 then c.p = c.p + 1 end

    elseif key == 'up' then
        if c.i > 1 then
            c.i = c.i - 1
            if c.p > #self.lines[c.i] + 1 then
                c.p = #self.lines[c.i] + 1
            end
        end

    elseif key == 'down' then
        if c.i < self.line_cur then
            c.i = c.i + 1
            if c.p > #self.lines[c.i] + 1 then
                c.p = #self.lines[c.i] + 1
            end
        else
            c.p = #self.lines[c.i] + 1
        end

    elseif key == 'home' then
        c.p = 1

    elseif key == 'end' then
        c.p = #self.lines[c.i] + 1

    elseif key == 'tab' then
        if #self.lines[c.i] + 2 > self.max_char then return end
        self.lines[c.i] = processAdd(self.lines[c.i], c.p, "  ")
        c.p = c.p + 2

    end
end

function CodeTab:textInput(t)
    if self.lock then return end
    -- First, should check if it is valid
    local c = self.cursor
    if #t + #self.lines[c.i] > self.max_char or
       #t > 1 or not t:match("[a-zA-Z0-9: ]")
        then return end
    if self.cursor2 then deleteInterval(self, c, self.cursor2) end
    t = t:lower()
    self.lines[c.i] = processAdd(self.lines[c.i], c.p, t)
    c.p = c.p + 1
end

function CodeTab:mousePressed(x, y, but)
    if self.lock then return end
    if but ~= 1 or not Util.pointInRect(x, y, self) then return end
    local dx = self.font:getWidth("20:") + 5
    if x < self.pos.x + dx - 2 then return end
    local w = self.font:getWidth("a")
    local i = math.floor((y - self.pos.y) / self.line_h) + 1
    local p = math.max(1, math.floor((x - self.pos.x - dx + 2) / w))
    if i > self.line_cur then return end
    self.cursor.i = i
    self.cursor.p = math.min(p, #self.lines[self.cursor.i] + 1)
end
