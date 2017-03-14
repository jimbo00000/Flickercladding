-- shadertoy_editor.lua
-- A minimal shadertoy implementation with built-in editor.
-- Loads shader(toy)s from file and saves.
-- Takes key input, rebuilding shader on every keypress.
-- The editor displays error messages on the relevant line in src.

local ffi = require "ffi"
local mm = require "util.matrixmath"
local sf2 = require "util.shaderfunctions2"
local EditorLibrary = require "scene.stringedit_scene"
require "util.glfont"

shadertoy_editor = {}
shadertoy_editor.__index = shadertoy_editor

function shadertoy_editor.new(...)
    local self = setmetatable({}, shadertoy_editor)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

-- Input: uv  vec2  screen position in [0,1]
-- Output: fragColor vec4  pixel color 
local frag_body = [[
uniform float time;
void main()
{
    vec2 col = uv;
    col.y = 1.-col.y;
    //col.x *= 3.*sin(100.*col.x);
    col.x *= 2.*tan(30.*col.x);
    fragColor = vec4(col, .5*(sin(7.*time) + 1.), 1.);
}
]]

local frag_body_backdrop = [[
void main() { fragColor = vec4(0.,0.,0.,.5); }
]]

function shadertoy_editor:init()
    self.time = 0
    self.Editor = nil
    self.win_w = 400
    self.win_h = 300

    self.vao = 0
    self.vbos = {}
    self.prog = 0
    self.fragsrc = frag_body

    self.update_every_key = true

    self.show_filename_buffer = true
    self.filename_buffer = "sh1"
    self.glfont = nil
end

function shadertoy_editor:setDataDirectory(dir)
    self.data_dir = dir
end

local basic_vert = [[
#version 300 es

in vec2 vPosition;

out vec2 uv;

void main()
{
    uv = .5*vPosition + vec2(.5);
    gl_Position = vec4(vPosition, 0., 1.);
}
]]

-- The standard shader header.
local frag_header = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec2 uv;
out vec4 fragColor;
#line 1
]]

function shadertoy_editor:initTriAttributes()
    local glIntv   = ffi.typeof('GLint[?]')
    local glFloatv = ffi.typeof('GLfloat[?]')

    -- One big tri to avoid some overdraw on the seam
    local verts = glFloatv(3*2, {
        -1,-1,
        3,-1,
        -1,3,
        })

    local vpos_loc = gl.glGetAttribLocation(self.prog, "vPosition")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, vvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
end

-- Recompile the current shader, updating error messages.
function shadertoy_editor:buildShader()
    gl.glDeleteProgram(self.prog)
    if self.Editor then
        self.Editor.error_msgs = {}
    end

    self.prog, err = sf2.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = frag_header..self.fragsrc,
        })
    if err then
        self:pushGlslErrorMessages(err)
    end
end

function shadertoy_editor:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self:buildShader() -- Error messages get piped to editor

    self.prog_backdrop = sf2.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = frag_header..frag_body_backdrop,
        })

    self:initTriAttributes()
    gl.glBindVertexArray(0)

    local dir = "fonts"
    if self.data_dir then dir = self.data_dir .. "/" .. dir end
    self.glfont = GLFont.new('courier_512.fnt', 'courier_512_0.raw')
    self.glfont:setDataDirectory(dir)
    self.glfont:initGL()
end

function shadertoy_editor:exitGL()
    self.glfont:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

function shadertoy_editor:render_for_one_eye(view, proj)
    if self.prog ~= 0 then
        gl.glUseProgram(self.prog)

        local uan_loc = gl.glGetUniformLocation(self.prog, "time")
        gl.glUniform1f(uan_loc, self.time)

        gl.glBindVertexArray(self.vao)
        gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3)
        gl.glBindVertexArray(0)
        gl.glUseProgram(0)
    end

    if self.Editor then
        self:renderEditor(view, proj)
    end

    if self.show_filename_buffer then
        self:renderFilenameBuffer(view, proj)
    end
end

function shadertoy_editor:timestep(absTime, dt)
    self.time = absTime
end

function shadertoy_editor:resizeViewport(w,h)
    self.win_w, self.win_h = w, h
end


--
-- Editor Concerns below
--

-- http://lua-users.org/wiki/SplitJoin
function split_into_lines(str)
    local t = {}
    local function helper(line) table.insert(t, line) return "" end
    helper((str:gsub("(.-)\r?\n", helper)))
    return t
end

-- Catch, parse, and display this list of error messages
-- overlaid on the editor's code under their respective lines.
function shadertoy_editor:pushGlslErrorMessages(err)
    -- Sample errors:
    -- Intel: [ERROR: 0:4: 'vec2' : syntax error syntax error]
    if not self.Editor then return end
    local lines = split_into_lines(err)
    if #lines == 0 then return end

    for _,v in pairs(lines) do
        if #v > 1 then
            -- Strip off digit, non-digit, digit, non-digit
            local linestr = string.match(v, "%d+[^%d]?%d+[^%d]?")
            if linestr then
                -- Get last digit sequence in that string
                for match in string.gmatch(linestr, "%d+") do
                    linestr = match
                end

                local linenum = tonumber(linestr)
                -- TODO concatenate or stack lines
                -- TODO wrap error lines in display
                self.Editor.error_msgs[tonumber(linenum)] = v
            end
        end
    end
    -- Lua out of memory errors?
    collectgarbage()
end

function shadertoy_editor:renderEditor(view, proj)
    local id = {}
    mm.make_identity_matrix(id)
    local mv = {}
    local aspect = self.win_w / self.win_h
    mm.make_scale_matrix(mv,1/aspect,1,1)
    local s = .9
    mm.glh_scale(mv,s,s,s)
    mm.glh_translate(mv,.3,0,0)

    gl.glDisable(GL.GL_DEPTH_TEST)
    self.Editor:render_for_one_eye(mv,id)
    gl.glEnable(GL.GL_DEPTH_TEST)
end

function shadertoy_editor:renderFilenameBuffer(view, proj)
    gl.glDisable(GL.GL_DEPTH_TEST)
    gl.glEnable(GL.GL_BLEND)
    gl.glUseProgram(self.prog_backdrop)
    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)

    local col = {1, 1, 1}

    local m = {}
    mm.make_identity_matrix(m)
    mm.glh_scale(m,.5,.5,.5)
    mm.glh_translate(m, 20,120,0)
    local m2 = {}
    for i=1,16 do m2[i] = m[i] end

    local p = {}
    mm.glh_ortho(p, 0, self.win_w, self.win_h, 0, -1, 1)

    mm.glh_translate(m2, 280,0,0)
    self.glfont:render_string(m2, p, col, "Load from file:")
    mm.glh_translate(m2, 0,80,0)
    self.glfont:render_string(m2, p, col, self.filename_buffer)
end

function shadertoy_editor:keypressed(key, scancode, action, mods)
    if key == 258 then -- Tab
        self:toggleFilenameBuffer()
    end

    if self.show_filename_buffer then
        if key == 259 then -- Backspace
            self.filename_buffer = string.sub(self.filename_buffer, 1, #self.filename_buffer-1)
        elseif key == 257 then -- Enter
            local fn = self.filename_buffer

            -- Add suffix automatically
            -- http://lua-users.org/wiki/StringRecipes
            function string.ends(String,End)
               return End=='' or string.sub(String,-string.len(End))==End
            end
            if not string.ends(fn,'.glsl') then fn = fn..'.glsl' end
            self.filename_buffer = fn -- reassign

            print("LOAD: ",fn, self.data_dir)

            self.Editor = EditorLibrary.new({
                filename = "shaders/"..fn,
                data_dir = self.data_dir
                })
            if self.Editor then
                self.Editor:initGL()
                self:reloadShader()
                self.show_filename_buffer = false
            end   
        end
        return
    end

    if key == 96 then
        self:toggleEditor()
        return true
    end

    if self.Editor then
        if mods ~= 0 then
            if action == 1 then -- press
                if key == 257 then -- Enter
                    self:reloadShader()
                    return true
                end
            end
        end

        -- On save, reload the scene
        if mods == 2 then -- ctrl held
            if action == 1 then -- press
                if key == string.byte('S') then
                    print("SAVE: ",self.filename_buffer, self.data_dir)
                    local fn = self.data_dir..'/'.."shaders/"..self.filename_buffer
                    if self.Editor then
                        self.Editor.editbuf:saveToFile(fn)
                    end
                    return true
                end
            end
        end

        self.Editor:keypressed(key, scancode, action, mods)
        -- TODO: do we need this twice with glfw's charkeypressed?
        if self.update_every_key then
            self:reloadShader()
        end

        return true
    end
end

function shadertoy_editor:charkeypressed(ch)
    if self.show_filename_buffer then
        self.filename_buffer = self.filename_buffer..ch
        return
    end

    if string.byte(ch) == 96 then
        self:toggleEditor()
        return true
    end

    if self.Editor then
        self.Editor:charkeypressed(ch)
        -- TODO: do we need this twice with glfw's keypressed?
        if self.update_every_key then
            self:reloadShader()
        end
    end

    return true
end

function shadertoy_editor:onwheel(x,y)
    if self.Editor then
        self.Editor:onwheel(x,y)
    end
end

function shadertoy_editor:toggleEditor()
    if self.Editor == nil then
        self.Editor = EditorLibrary.new({
            contents = self.fragsrc
            })
        if self.Editor then
            if self.Editor.setDataDirectory then self.Editor:setDataDirectory(self.data_dir) end
            self.Editor:initGL()
        end    
    else
        self.Editor:exitGL()
        self.Editor = nil
    end
end

function shadertoy_editor:toggleFilenameBuffer()
    self.show_filename_buffer = not self.show_filename_buffer
end

function shadertoy_editor:reloadShader()
    if not self.Editor then return end

    self.fragsrc = self.Editor.editbuf:saveToString()
    self:buildShader()
    -- TODO: keep an undo stack of working shader,string tuples
end

function shadertoy_editor:saveShader()
    if not self.Editor then return end
    self.Editor.editbuf:saveToFile(self.src_filename)
end

return shadertoy_editor
