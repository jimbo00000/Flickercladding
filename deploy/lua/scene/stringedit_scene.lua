-- stringedit_scene.lua
-- Holds an instance of EditBuffer and displays its contents and state.
-- Draws the text, cursor, backdrop and error message layer.
-- Passes along input and handles scrolling.

require "util.glfont"
require "util.editbuffer"
local ffi = require "ffi"
local sf = require "util.shaderfunctions"
local mm = require "util.matrixmath"
local fbf = require "util.fbofunctions"

stringedit_scene = {}
stringedit_scene.__index = stringedit_scene

function stringedit_scene.new(...)
    local self = setmetatable({}, stringedit_scene)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

-- Takes named parameters: filename, contents
function stringedit_scene:init(source)
    self.vbos = {}
    self.vao = 0
    self.prog_cursor = 0
    self.glfont = nil
    self.editbuf = nil
    self.data_dir = nil
    self.lineh = 0
    self.scroll = 0
    self.fbo = nil
    self.fbw, self.fbh = 2048,1024
    self.textscale = .0008
    self.max_charw = 0

    if type(source.data_dir) == "string" then
        self.data_dir = source.data_dir
    end

    if type(source.contents) == "string" then
        self.editbuf = EditBuffer.new()
        self.editbuf:loadFromString(source.contents)
    elseif type(source.filename) == "string" then
        self.editbuf = EditBuffer.new()
        local fn = source.filename
        if self.data_dir then fn = self.data_dir .. '/' .. fn end
        self.editbuf:loadFromFile(fn)
    end

    self.draw_fbo = false
    self.visible_lines = 26 -- TODO: figure this out based on size

    self.vbos_quad = {}
    self.vao_quad = 0
    self.prog_quad = 0
    self.error_msgs = {}
end

local glIntv   = ffi.typeof('GLint[?]')
local glUintv  = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

--[[
    Cursor drawing
    self.program, self.vao, font dimensions to match GLFont.
]]
local cursor_vert = [[
#version 310 es

in vec4 vPosition;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    gl_Position = prmtx * mvmtx * vPosition;
}
]]

local cursor_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform vec4 uColor;
out vec4 fragColor;

void main()
{
    fragColor = uColor;
}
]]

function stringedit_scene:initCursorAttributes()
    -- Make sure font has been loaded to get these variables
    local x = self.max_charw
    local y = self.lineh
    local verts = glFloatv(6*3, {
        0,0,0,
        x,0,0,
        x,y,0,
        0,0,0,
        x,y,0,
        0,y,0,
        })

    local vpos_loc = gl.glGetAttribLocation(self.prog_cursor, "vPosition")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, vvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
end

function stringedit_scene:initGL_cursor()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog_cursor = sf.make_shader_from_source({
        vsrc = cursor_vert,
        fsrc = cursor_frag,
        })

    self:initCursorAttributes()
    gl.glBindVertexArray(0)
end

function stringedit_scene:exitGL_cursor()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog_cursor)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

function stringedit_scene:makeModelMatrix(m)
    mm.make_identity_matrix(m)
    mm.glh_translate(m, -1, 1, 0) -- align to upper left corner
    mm.glh_translate(m, 150*self.textscale, 0, 0) -- leave a gap for line numbers
    local s = self.textscale
    mm.glh_scale(m, s, -s, s)
    local aspect = self.fbw/self.fbh
    mm.glh_scale(m,1/aspect,1,1)
end

-- For editing visibility, put a backdrop behind the current line.
-- TODO: refactor this into a function called 3 times.
function stringedit_scene:renderCurrentLineBackdrop(view, proj)
    local m = {}
    self:makeModelMatrix(m)
    mm.glh_translate(m, 0, 0, -.0002) -- place behind text
    local cline = self.editbuf.curline
    local line = self.editbuf.lines[cline]
    if not line then return end
    mm.glh_scale(m,#line,1,1) -- cover under entire line

    mm.glh_translate(m, 0, (cline-1)*self.lineh, 0)
    mm.glh_translate(m, 0, -self.scroll * self.lineh, 0)

    gl.glEnable(GL.GL_BLEND)
    gl.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA);

    gl.glUseProgram(self.prog_cursor)
    local umv_loc = gl.glGetUniformLocation(self.prog_cursor, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog_cursor, "prmtx")
    local ucol_loc = gl.glGetUniformLocation(self.prog_cursor, "uColor")
    local color = {0.1,0.1,0.1,.75}
    gl.glUniform4f(ucol_loc, color[1], color[2], color[3], color[4])
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))
    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3*2)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)

    gl.glDisable(GL.GL_BLEND)
end

function stringedit_scene:renderCursor(view, proj)
    local m = {}
    self:makeModelMatrix(m)
    mm.glh_translate(m, 0, 0, .0002) -- put cursor in front

    local ccol, cline = self.editbuf.curcol, self.editbuf.curline
    mm.glh_translate(m, ccol*self.max_charw, (cline-1)*self.lineh, 0)
    mm.glh_translate(m, 0, -self.scroll * self.lineh, 0)

    gl.glEnable(GL.GL_BLEND)
    gl.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA);

    gl.glUseProgram(self.prog_cursor)
    local umv_loc = gl.glGetUniformLocation(self.prog_cursor, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog_cursor, "prmtx")
    local ucol_loc = gl.glGetUniformLocation(self.prog_cursor, "uColor")
    local color = {1,0,0,.5}
    gl.glUniform4f(ucol_loc, color[1], color[2], color[3], color[4])
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))
    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3*2)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)

    gl.glDisable(GL.GL_BLEND)
end


local texquad_vert = [[
#version 310 es

in vec4 vPosition;
in vec4 vTexCoord;

uniform mat4 mvmtx;
uniform mat4 prmtx;

out vec3 vfTexCoord;

void main()
{
    vfTexCoord = vTexCoord.xyz;
    gl_Position = prmtx * mvmtx * vPosition;
}
]]


local texquad_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D sTex;

in vec3 vfTexCoord;
out vec4 fragColor;

void main()
{
    vec4 tcol = texture(sTex, vfTexCoord.xy);
    fragColor = vec4(tcol.xyz, .75);
}
]]

function stringedit_scene:initQuadAttributes()
    local x = 1
    local y = 1
    local verts = glFloatv(6*3, {
        0,0,0,
        x,0,0,
        x,y,0,
        0,0,0,
        x,y,0,
        0,y,0,
        })

    local vpos_loc = gl.glGetAttribLocation(self.prog_cursor, "vPosition")
    local vtex_loc = gl.glGetAttribLocation(self.prog_cursor, "vTexCoord")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos_quad, vvbo)

    local tvbo = glIntv(0)
    gl.glGenBuffers(1, tvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, tvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vtex_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos_quad, tvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vtex_loc)
end

function stringedit_scene:initGL_quad()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao_quad = vaoId[0]
    gl.glBindVertexArray(self.vao_quad)

    self.prog_quad = sf.make_shader_from_source({
        vsrc = texquad_vert,
        fsrc = texquad_frag,
        })

    self:initQuadAttributes()
    gl.glBindVertexArray(0)
end

function stringedit_scene:exitGL_quad()
    gl.glBindVertexArray(self.vao_quad)
    for _,v in pairs(self.vbos_quad) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos_quad = {}
    gl.glDeleteProgram(self.prog_quad)
    local vaoId = ffi.new("GLuint[1]", self.vao_quad)
    gl.glDeleteVertexArrays(1, vaoId)
end

function stringedit_scene:renderQuad(view, proj)
    gl.glUseProgram(self.prog_quad)
    local umv_loc = gl.glGetUniformLocation(self.prog_quad, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog_quad, "prmtx")
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))

    local utx_loc = gl.glGetUniformLocation(self.prog_quad, "sTex")
    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, self.fbo.tex)
    gl.glUniform1i(utx_loc, 0)
    
    gl.glBindVertexArray(self.vao_quad)
    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3*2)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end








function stringedit_scene:setDataDirectory(dir)
    self.data_dir = dir
end

function stringedit_scene:initGL()
    local dir = "fonts"
    if self.data_dir then dir = self.data_dir .. "/" .. dir end
    self.glfont = GLFont.new('courier_512.fnt', 'courier_512_0.raw')
    self.glfont:setDataDirectory(dir)
    self.glfont:initGL()
    self.max_charw = self.glfont:get_max_char_width()
    self.lineh = self.glfont.font.common.lineHeight

    self:initGL_cursor()
    self:initGL_quad()

    self.fbo = fbf.allocate_fbo(self.fbw, self.fbh)

    local vpdims = ffi.new("int[2]")
    gl.glGetIntegerv(GL.GL_MAX_VIEWPORT_DIMS, vpdims)
    print("Max vpdims: ", vpdims[0], vpdims[1])
end

function stringedit_scene:exitGL()
    self.glfont:exitGL()
    self:exitGL_cursor()
    self:exitGL_quad()
    fbf.deallocate_fbo(self.fbo)
end

function stringedit_scene:renderToFbo()
    -- Set the bound FBO back when done
    local boundfbo = ffi.new("int[1]")
    gl.glGetIntegerv(GL.GL_FRAMEBUFFER_BINDING, boundfbo)

    fbf.bind_fbo(self.fbo)

    -- Set the viewport back when we're done
    local vpdims = ffi.new("int[4]")
    gl.glGetIntegerv(GL.GL_VIEWPORT, vpdims)

    gl.glViewport(0,0, self.fbw, self.fbh)

    local l = .2
    gl.glClearColor(l, l, l, 0)
    gl.glClear(GL.GL_COLOR_BUFFER_BIT + GL.GL_DEPTH_BUFFER_BIT)

    local aspect = self.fbw/self.fbh
    local orth = {}
    mm.glh_ortho(orth, -aspect,aspect,-1,1,-1,1)
    local id = {}
    mm.make_identity_matrix(id)
    self:renderText(id, orth)
    local cm = {}
    mm.make_identity_matrix(cm)
    self:renderCursor(cm, orth)
    self:renderErrors(cm, orth)

    -- Set the viewport back when we're done
    gl.glViewport(vpdims[0], vpdims[1], vpdims[2], vpdims[3])

    -- Set the FBO back when done
    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, boundfbo[0])
end

function stringedit_scene:renderText(view, proj)
    local m = {}
    self:makeModelMatrix(m)

    local linenum_color = {.7, .7, .7}
    local text_color = {1, 1, 1}
    local numlines = math.min(self.visible_lines, #self.editbuf.lines)
    for i=1,numlines do
        local k = i + self.scroll
        local v = self.editbuf.lines[k]
        self.glfont:render_string(m, proj, text_color, v)

        -- Line numbers
        local linenum_str = tostring(k)
        local mn = {}
        for i=1,16 do mn[i] = m[i] end
        mm.glh_translate(mn, -40-59*string.len(linenum_str), 0, 0)
        self.glfont:render_string(mn, proj, linenum_color, linenum_str)

        mm.glh_translate(m, 0, self.lineh, 0)
    end
end

-- Draws a translucent quad under error text for visibility
-- Started as copy-paste of cursor drawing func
function stringedit_scene:renderErrorBackdrop(view, proj)
    for k,v in pairs(self.error_msgs) do
        local m = {}
        self:makeModelMatrix(m)
        mm.glh_translate(m, 0, 0, .0002) -- put cursor in front
        mm.glh_scale(m,#v,1,1) -- cover under entire message

        local ccol, cline = 0, k+1
        mm.glh_translate(m, ccol*self.max_charw, (cline-1)*self.lineh, 0)
        mm.glh_translate(m, 0, -self.scroll * self.lineh, 0)

        gl.glEnable(GL.GL_BLEND)
        gl.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA);

        gl.glUseProgram(self.prog_cursor)
        local umv_loc = gl.glGetUniformLocation(self.prog_cursor, "mvmtx")
        local upr_loc = gl.glGetUniformLocation(self.prog_cursor, "prmtx")
        local ucol_loc = gl.glGetUniformLocation(self.prog_cursor, "uColor")
        local color = {.1,.1,.1,.7}
        gl.glUniform4f(ucol_loc, color[1], color[2], color[3], color[4])
        gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
        gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))
        gl.glBindVertexArray(self.vao)
        gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3*2)
        gl.glBindVertexArray(0)
        gl.glUseProgram(0)

        gl.glDisable(GL.GL_BLEND)
    end
end

function stringedit_scene:renderErrorText(view, proj)
    local errcol = {.9,.4,.1}
    local s = self.textscale
    for k,v in pairs(self.error_msgs) do
        local emat = {}
        self:makeModelMatrix(emat)

        mm.glh_translate(emat, 0, (k - self.scroll)*self.lineh, 0)
        self.glfont:render_string(emat, proj, errcol, v)
    end
end

-- Draw line-tagged messages as overlay
function stringedit_scene:renderErrors(view, proj)
    self:renderErrorBackdrop(view, proj)
    self:renderErrorText(view, proj)
end

function stringedit_scene:render_for_one_eye(view, proj)
    if self.draw_fbo then
        self:renderToFbo()

        local m = {}
        mm.make_identity_matrix(m)
        local s = 2
        mm.glh_scale(m, s, s, s)

        local aspect = self.fbo.w / self.fbo.h
        mm.glh_scale(m, aspect, 1, 1)

        mm.glh_translate(m, -.5, -.5, 0)

        gl.glEnable(GL.GL_BLEND)
        gl.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA);

        self:renderQuad(m, proj)

        gl.glDisable(GL.GL_BLEND)
    else
        -- Floating text in space
        self:renderCurrentLineBackdrop(view, proj)
        self:renderText(view, proj)
        self:renderCursor(view, proj)
        self:renderErrors(view, proj)
    end
    
    -- Do this every once in a while to save memory
    self.glfont:deleteoldstrings()
end

function stringedit_scene:timestep(absTime, dt)
end

function stringedit_scene:keypressed(key, scancode, action, mods)
    if mods == 2 then -- ctrl held
        if action == 1 then -- press
            if key == string.byte('F') then
                self.draw_fbo = not self.draw_fbo
                return true
            end
        end
    end

    if mods == 3 then -- ctrl,shift held
        if action == 1 then -- press
            local incr = 1.2
            if key == string.byte('=') then
                self.textscale = self.textscale * incr
                return true
            elseif key == string.byte('-') then
                self.textscale = self.textscale / incr
                return true
            end
        end
    end

    local scrollAmt = 10
    local ch = key
    local func_table = {
        [259] = function (x) -- Backspace
            self.editbuf:onBackspace()
        end,
        [257] = function (x) -- Enter
            self.editbuf:onEnter()
        end,
        [262] = function (x) -- Right
            self.editbuf:cursorMotion(1,0)
        end,
        [263] = function (x) -- Left
            self.editbuf:cursorMotion(-1,0)
        end,
        [264] = function (x) -- Down
            self.editbuf:cursorMotion(0,1)
            if self.scroll + self.visible_lines < self.editbuf.curline then
                self.scroll = self.editbuf.curline - self.visible_lines
                self.scroll = math.max(0, self.scroll)
            end
        end,
        [265] = function (x) -- Up
            self.editbuf:cursorMotion(0,-1)
            if self.scroll >= self.editbuf.curline then
                self.scroll = self.editbuf.curline - 1
            end
        end,
        [266] = function (x) -- Page Up
            self.scroll = self.scroll - scrollAmt
            self.scroll = math.max(self.scroll, 0)
            self.editbuf:cursorMotion(0,-scrollAmt)
        end,
        [267] = function (x) -- Page Down
            self.scroll = self.scroll + scrollAmt
            self.scroll = math.min(self.scroll, #self.editbuf.lines - self.visible_lines)
            self.editbuf:cursorMotion(0,scrollAmt)
        end,
    }
    local f = func_table[ch]
    if f then
        f()
        return true
    end

    return false
end

function stringedit_scene:charkeypressed(ch)
    self.editbuf:addChar(ch)
    return true
end

function stringedit_scene:onwheel(x,y)
    local scrollAmt = 10

    y = math.floor(-5*y)
    self.editbuf:cursorMotion(0,y)

    if self.scroll + self.visible_lines < self.editbuf.curline then
        self.scroll = self.editbuf.curline - self.visible_lines
        self.scroll = math.max(0, self.scroll)
    end

    if self.scroll >= self.editbuf.curline then
        self.scroll = self.editbuf.curline - 1
    end
end

return stringedit_scene
