--[[ slideshow.lua

    A framework for a powerpoint-style slide: Title, list of
    bullet points that reveal one-by-one, and a copyright notice.
    Contains font rendering module and state.
]]

require("util.glfont")
local mm = require("util.matrixmath")
local ffi = require("ffi")

-- this is our Slideshow class
Slideshow = {}
Slideshow.__index = Slideshow

-- and its new function
function Slideshow.new(...)
    local self = setmetatable({}, Slideshow)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function Slideshow:init(strings)
    self.title = "Title"
    self.shown_lines = 0
    self.bullet_points = {
        "- 1",
        "- 2",
        "- 3",
    }

    if type(strings.title) == "string" then
        self.title = strings.title
    end

    if strings.bullets then
        self.bullet_points = strings.bullets
    end

    if strings.shown_lines then
        self.shown_lines = strings.shown_lines
    end

    self.codesnippet = strings.codesnippet
    self.background = strings.background

    self.copyright = "(c) Jim Susinno 2016"
end

function Slideshow:initGL(dataDir)
    local dir = "fonts"
    local fontname = "segoe_ui128"
    if dataDir then dir = dataDir .. "/" .. dir end
    self.glfont = GLFont.new(fontname..'.fnt', fontname..'_0.raw')
    self.glfont:setDataDirectory(dir)
    self.glfont:initGL()
end

function Slideshow:exitGL()
    self.glfont:exitGL()
end

function Slideshow:draw_text()
    local vp = ffi.new("int[4]")
    gl.glGetIntegerv(GL.GL_VIEWPORT, vp)
    local win_w,win_h = vp[2]-vp[0], vp[3]-vp[1]

    local p = {}

    local w,h = 1200,900
    local rw,rh = win_w/w, win_h/h
    if rw > rh then
        w,h = win_w/rh, win_h/rh
    elseif rw < rh then
        w,h = win_w/rw, win_h/rw
    end
    mm.glh_ortho(p, 0, w, h, 0, -1, 1)


    local title = self.title
    local bullet_points = self.bullet_points
    local col = {0,0,0}

    local m = {}
    mm.make_identity_matrix(m)
    mm.glh_translate(m, 90, 40, 0)
    self.glfont:render_string(m, p, col, title)

    mm.make_identity_matrix(m)
    local s = .68
    mm.glh_scale(m, s,s,s)
    local lineh = 170
    mm.glh_translate(m, 200, lineh, 0)

    for i=1,self.shown_lines do
        if bullet_points[i] then
            mm.glh_translate(m, 0, lineh, 0)
            self.glfont:render_string(m, p, col, bullet_points[i])
        end
    end

    if self.copyright then
        mm.make_identity_matrix(m)
        local gray = {.5,.5,.5}
        local s = .25
        mm.glh_translate(m, w-300, h-50, 0)
        mm.glh_scale(m, s,s,s)
        self.glfont:render_string(m, p, gray, self.copyright)
    end
end

function Slideshow:advance(delta)
    self.shown_lines = self.shown_lines + delta
    self.shown_lines = math.max(self.shown_lines, 0)
    self.shown_lines = math.min(self.shown_lines, #self.bullet_points)
end

function Slideshow:keypressed(ch)
    local func_table = {
        -- 262-265 are arrow keys in glfw
        [262] = function (x) self:advance(1) end,
        [263] = function (x) self:advance(-1) end,
        [264] = function (x) end,
        [265] = function (x) end,
    }
    local f = func_table[ch] if f then f() return true end
    return false
end
