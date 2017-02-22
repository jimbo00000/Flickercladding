--[[ font_test.lua

    A font rendering example, drawing 139 lines of lorem ipsum text.

    Uses the glfont class in util, which uses the bmfont module 
    to load font texture and glyphs. glfont handles rendering,
    trying to cache as much data as possible for rendering speed.
]]
font_test = {}
font_test.__index = font_test

function font_test.new(...)
    local self = setmetatable({}, font_test)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function font_test:init()
    self.glfont = nil
    self.dataDir = nil
    self.lines = {}
end


require("util.glfont")
local mm = require("util.matrixmath")

-- Since data files must be loaded from disk, we have to know
-- where to find them. Set the directory with this standard entry point.
function font_test:setDataDirectory(dir)
    self.dataDir = dir
end

function font_test:initGL()
    -- Load text file
    local filename = "loremipsumbreaks.txt"
    if self.dataDir then filename = self.dataDir .. "/" .. filename end
    local file = io.open(filename)
    if file then
        for line in file:lines() do
            table.insert(self.lines, line)
        end
    end

    local dir = "fonts"
    local fontname = "courier_512"
    if self.dataDir then dir = self.dataDir .. "/" .. dir end
    self.glfont = GLFont.new(fontname..'.fnt', fontname..'_0.raw')
    self.glfont:setDataDirectory(dir)
    self.glfont:initGL()
end

function font_test:exitGL()
    self.glfont:exitGL()
end

function font_test:render_for_one_eye(view, proj)
    local m = {}
    local s = .002
    mm.make_identity_matrix(m)
    mm.glh_translate(m, -2, 1.2, 0)
    mm.glh_scale(m, s, -s, s)
    mm.pre_multiply(m, view)

    local col = {1, 1, 1}
    local lineh = self.glfont.font.common.lineHeight
    for k,v in pairs(self.lines) do
        self.glfont:render_string(m, proj, col, v)
        mm.glh_translate(m, 0, lineh, 0)
    end
end

return font_test
