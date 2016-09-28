-- Ripped from https://github.com/gideros/BMFont

-- check if string1 starts with string2
local function startsWith(string1, string2)
   return string1:sub(1, #string2) == string2
end

-- create table from a bmfont line
local function lineToTable(line)
    local result = {}
    for pair in line:gmatch("%a+=[-%d]+") do
        local key = pair:match("%a+")
        local value = pair:match("[-%d]+")
        result[key] = tonumber(value)
    end
    return result
end

-- this is our BMFont class
BMFont = {}
BMFont.__index = BMFont

-- and its new function
function BMFont.new(...)
    local self = setmetatable({}, BMFont)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function BMFont:init(fontfile, imagefile, filtering)
    -- load font texture
    --self.texture = Texture.new(imagefile, filtering)

    -- read glyphs from font.txt and store them in chars table
    self.chars = {}
    file = io.open(fontfile, "rt")
    if not file then print("File not found: "..fontfile) return end
    for line in file:lines() do
        if startsWith(line, "char ") then
            local char = lineToTable(line)
            self.chars[char.id] = char
        end
    end
    io.close(file)
end

function BMFont:getcharquad(ch, x, y, tw, th)
    if not ch then return nil, nil, nil end
    local char = self.chars[ch]
    if not char then return nil, nil, nil end

    local cx, cy = char.x, char.y
    local cw, ch = char.width, char.height
    local ox, oy = char.xoffset, char.yoffset

    local v = {
        x   +ox, y   +oy,
        x+cw+ox, y   +oy,
        x+cw+ox, y+ch+oy,
        x   +ox, y+ch+oy,
    }

    local t = {
         cx    /tw,  cy    /th,
        (cx+cw)/tw,  cy    /th,
        (cx+cw)/tw, (cy+ch)/th,
         cx    /tw, (cy+ch)/th,
    }

    return v, t, char.xadvance
end
