-- editbuffer.lua

--[[
    EditBuffer class
    Holds a list of character lines and editing state.
]]

EditBuffer = {}
EditBuffer.__index = EditBuffer

-- and its new function
function EditBuffer.new(...)
    local self = setmetatable({}, EditBuffer)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function EditBuffer:init()
    self.lines = {}
    self.curline = 1
    self.curcol = 0
end

function EditBuffer:addchar(ch)
    local line = self.lines[self.curline]
    if line then
        local c = self.curcol
        local p1 = string.sub(line, 1, c)
        local p2 = string.sub(line, c+1, string.len(line))
        self.lines[self.curline] = p1..ch..p2
        self.curcol = c + 1
    else
        self.lines[self.curline] = ch
    end
end

function EditBuffer:backspace()
    local line = self.lines[self.curline]
    if not line then return end
    local c = self.curcol
    if c>0 then
        local p1 = string.sub(line, 1, c-1)
        local p2 = string.sub(line, c+1, string.len(line))
        self.lines[self.curline] = p1..p2
        if #line > 0 then
            self.curcol = self.curcol - 1
        end
    else
        local l = self.curline
        if l > 1 then
            local s1 = self.lines[l-1]
            local s2 = self.lines[l]
            self.lines[l-1] = s1..s2

            -- Shuffle lines down
            local n = #self.lines
            for i=l+1,n do
                self.lines[i-1] = self.lines[i]
            end
            self.lines[n] = nil

            self.curcol = #s1
            self.curline = self.curline-1
        end
    end
end

function EditBuffer:enter()
    local line = self.lines[self.curline]
    if not line then return end

    -- Shuffle lines down
    for i=#self.lines,self.curline,-1 do
        self.lines[i+1] = self.lines[i]
    end

    local row = self.curline
    self.lines[row] = string.sub(line, 1, self.curcol)

    row = row + 1
    self.lines[row] = string.sub(line, self.curcol+1, #line)
    self.curline = row

    self.curcol = 0
end

function EditBuffer:cursormotion(dx, dy)
    self.curcol = self.curcol + dx
    self.curline = self.curline + dy

    -- Down past bottom
    self.curline = math.min(self.curline, #self.lines)

    -- Up past top
    self.curline = math.max(self.curline, 1)

    -- Down past the end of the now current line
    if dy ~= 0 then
        -- @TODO hold the curcol larger than current line
        self.curcol = math.min(self.curcol, #self.lines[self.curline])
    end

    -- Left past the beginning
    if self.curcol < 0 then
        if self.curline > 1 then
            self.curline = self.curline - 1
            self.curcol = #self.lines[self.curline]
        else
            self.curcol = math.max(self.curcol, 0)
        end
    end

    -- Right into an empty line
    if dx > 0 then
        if self.curcol > #self.lines[self.curline] and not self.lines[self.curline+1] then
            self.curcol = self.curcol - dx
            return
        end
    end
    
    -- Right past the end
    if self.curcol > #self.lines[self.curline] then
        if not self.lines[self.curline] then return end
        local num = #self.lines
        if self.curline <= num then
            self.curcol = 0
            self.curline = self.curline + 1
        end
    end
end

-- Load text file into buffer
function EditBuffer:loadfromfile(filename)
    self.lines = {}
    local file = io.open(filename)
    if file then
        for line in file:lines() do
            table.insert(self.lines, line)
        end
        file:close()
    else
        print("file "..filename.." not found.")
    end
end

function EditBuffer:savetofile(filename)
    --if not filename then return end
    local file = io.open(filename, "w")
    if file then
        for k,line in pairs(self.lines) do
            file:write(line)
            file:write("\n")
        end
        file:close()
    else
        print("file "..filename.." could not be opened.")
    end
end

-- http://lua-users.org/wiki/SplitJoin
function split_into_lines(str)
    local t = {}
    local function helper(line) table.insert(t, line) return "" end
    helper((str:gsub("(.-)\r?\n", helper)))
    return t
end

-- Load string into buffer
function EditBuffer:loadFromString(contents)
    self.lines = {}
    if not contents then return end
    for _,line in pairs(split_into_lines(contents)) do
        table.insert(self.lines, line)
    end
end

function EditBuffer:saveToString()
    local s = ''
    local newline = '\n'
    for k,line in pairs(self.lines) do
        s = s..line
        s = s..newline
    end
    return s
end
