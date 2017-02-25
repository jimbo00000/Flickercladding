-- key_check.lua

key_check = {}
key_check.__index = key_check

function key_check.new(...)
    local self = setmetatable({}, key_check)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

require("util.glfont")
local mm = require("util.matrixmath")

function key_check:init()
    self.dataDir = nil
    self.glfont = nil
    self.win_w = 400
    self.win_h = 300
    self.keys_down = {}
end

function key_check:setDataDirectory(dir)
    self.dataDir = dir
end

function key_check:initGL()
    dir = "fonts"
    if self.dataDir then dir = self.dataDir .. "/" .. dir end
    self.glfont = GLFont.new('courier_512.fnt', 'courier_512_0.raw')
    self.glfont:setDataDirectory(dir)
    self.glfont:initGL()
end

function key_check:exitGL()
    self.glfont:exitGL()
end

function key_check:resizeViewport(w,h)
    self.win_w, self.win_h = w, h
end

function key_check:render_for_one_eye(view, proj)
    local col = {1, 1, 1}

    local m = {}
    mm.make_identity_matrix(m)
    mm.glh_scale(m,.5,.5,.5)
    mm.glh_translate(m, 20,120,0)

    local p = {}
    mm.glh_ortho(p, 0, self.win_w, self.win_h, 0, -1, 1)
    gl.glDisable(GL.GL_DEPTH_TEST)

    for k,_ in pairs(self.keys_down) do
        local str = tostring(k)
        if k > 32 and k < string.byte('z') then
            str = str..' '..string.char(k)
        end
        self.glfont:render_string(m, p, col, str)
        mm.glh_translate(m, 0,80,0)
    end
end

function key_check:keypressed(key, scancode, action, mods)
    if action == 1 then
        self.keys_down[key] = true
    elseif action == 0 then
        self.keys_down[key] = nil
    end
end

function key_check:keyreleased(key, scancode, action, mods)
    -- An elegant way around a poor design decision?
    self:keypressed(key, scancode, action, mods)
end

function key_check:charkeypressed(ch)
end

return key_check
