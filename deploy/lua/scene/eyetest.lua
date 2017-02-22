--[[ eyetest.lua

    A series of lines of text decreasing in size.
]]
eyetest = {}
eyetest.__index = eyetest

function eyetest.new(...)
    local self = setmetatable({}, eyetest)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function eyetest:init()
    self.glfont = nil
    self.dataDir = nil
    self.lines = {}
end

require("util.glfont")
local mm = require("util.matrixmath")

function eyetest:setDataDirectory(dir)
    self.dataDir = dir
end

function eyetest:initGL()
    for i=1,32 do
        local str = ''
        local a = i + 5
        local n = (a/8)*math.pow((1/.85), a)
        for j=1,n do
            local c = 65+j-1
            local c = 25*math.random() + 65
            str = str..string.char(c)
        end
        table.insert(self.lines, str)
    end

    local dir = "fonts"
    if self.dataDir then dir = self.dataDir .. "/" .. dir end
    self.glfont = GLFont.new('courier_512.fnt', 'courier_512_0.raw')
    self.glfont:setDataDirectory(dir)
    self.glfont:initGL()
end

function eyetest:exitGL()
    self.glfont:exitGL()
    self.lines = nil
    -- NOTE: memory leak here
end

function eyetest:render_for_one_eye(view, proj)
    local m = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
    local s = .01
    mm.glh_translate(m, -2, 2, 0)
    mm.glh_scale(m, s, -s, s)
    mm.pre_multiply(m, view)

    local col = {1, 1, 1}
    local lh = 90
    local f = self.glfont
    for k,v in pairs(self.lines) do
        local wid = f:get_string_width(v)
        local xt = 10 - wid/2
        mm.glh_translate(m, xt, 0, 0)
        self.glfont:render_string(m, proj, col, v)
        mm.glh_translate(m, -xt, 0, 0)
        mm.glh_translate(m, 0, lh, 0)
        local x = .8
        mm.glh_scale(m, x, x, x)
    end
end

return eyetest
