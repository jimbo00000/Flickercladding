-- pointsvs_editor.lua
-- The points_vs scene with editor functionality attached.
-- TODO: refactor it all out.

local ffi = require "ffi"
local mm = require "util.matrixmath"
local sf2 = require "util.shaderfunctions2"
local EditorLibrary = require "scene.stringedit_scene"
require "util.glfont"

pointsvs_editor = {}
pointsvs_editor.__index = pointsvs_editor

function pointsvs_editor.new(...)
    local self = setmetatable({}, pointsvs_editor)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

local vert_body = [[
uniform float time;
uniform int numParticles;
uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    int index = gl_VertexID;
    float t = float(index) / float(numParticles);
   
    // Simply calculate a position in time
    vec4 position = vec4(vec3(0.),1.);
    vec3 p0 = vec3(0.);
    vec3 p1 = vec3(1.);
    position.xyz = mix(p0, p1, t);
    position.z += 0.03 * sin(time + 32.*t);

    vfColor = mix(vec3(1.,0.,0.), vec3(0.,1.,0.), t);
    gl_Position = prmtx * mvmtx * position;
}
]]

local frag_body_backdrop = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec2 uv;
out vec4 fragColor;
void main() { fragColor = vec4(0.,0.,0.,.5); }
]]

function pointsvs_editor:init()
    self.time = 0
    self.Editor = nil
    self.win_w = 400
    self.win_h = 300

    self.vao = 0
    self.prog = 0
    self.vertsrc = vert_body
    self.npts = 128

    self.update_every_key = true

    self.show_filename_buffer = true
    self.filename_buffer = "sh1"
    self.glfont = nil
end

function pointsvs_editor:setDataDirectory(dir)
    self.data_dir = dir
end

local vert_header = [[
#version 310 es

out vec3 vfColor;
#line 1
]]

local basic_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec3 vfColor;
out vec4 fragColor;

void main()
{
    fragColor = vec4(vfColor, 1.0);
}
]]

-- Recompile the current shader, updating error messages.
function pointsvs_editor:buildShader()
    gl.glDeleteProgram(self.prog)
    if self.Editor then
        self.Editor.error_msgs = {}
    end

    self.prog, err = sf2.make_shader_from_source({
        vsrc = vert_header..self.vertsrc,
        fsrc = basic_frag,
        })
    if err then
        self:pushGlslErrorMessages(err)
    end
end

function pointsvs_editor:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self:buildShader() -- Error messages get piped to editor

    self.prog_backdrop = sf2.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = frag_body_backdrop,
        })

    gl.glBindVertexArray(0)

    local dir = "fonts"
    if self.data_dir then dir = self.data_dir .. "/" .. dir end
    self.glfont = GLFont.new('courier_512.fnt', 'courier_512_0.raw')
    self.glfont:setDataDirectory(dir)
    self.glfont:initGL()
end

function pointsvs_editor:exitGL()
    self.glfont:exitGL()
    gl.glBindVertexArray(self.vao)
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

function pointsvs_editor:render_for_one_eye(view, proj)
    if self.prog ~= 0 then
        --gl.glPointSize(5)
        gl.glUseProgram(self.prog)

        local ut_loc = gl.glGetUniformLocation(self.prog, "time")
        gl.glUniform1f(ut_loc, self.time)
        local un_loc = gl.glGetUniformLocation(self.prog, "numParticles")
        gl.glUniform1i(un_loc, self.npts)

        local umv_loc = gl.glGetUniformLocation(self.prog, "mvmtx")
        local upr_loc = gl.glGetUniformLocation(self.prog, "prmtx")

        local glFloatv = ffi.typeof('GLfloat[?]')
        gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))
        gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
        gl.glBindVertexArray(self.vao)
        gl.glDrawArrays(GL.GL_POINTS, 0, self.npts)
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

function pointsvs_editor:timestep(absTime, dt)
    self.time = absTime
end

function pointsvs_editor:resizeViewport(w,h)
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
function pointsvs_editor:pushGlslErrorMessages(err)
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

function pointsvs_editor:renderEditor(view, proj)
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

function pointsvs_editor:renderFilenameBuffer(view, proj)
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

function pointsvs_editor:keypressed(key, scancode, action, mods)
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

function pointsvs_editor:charkeypressed(ch)
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

function pointsvs_editor:onwheel(x,y)
    if self.Editor then
        self.Editor:onwheel(x,y)
    end
end

function pointsvs_editor:toggleEditor()
    if self.Editor == nil then
        self.Editor = EditorLibrary.new({
            contents = self.vertsrc
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

function pointsvs_editor:toggleFilenameBuffer()
    self.show_filename_buffer = not self.show_filename_buffer
end

function pointsvs_editor:reloadShader()
    if not self.Editor then return end

    self.vertsrc = self.Editor.editbuf:saveToString()
    self:buildShader()
    -- TODO: keep an undo stack of working shader,string tuples
end

function pointsvs_editor:saveShader()
    if not self.Editor then return end
    self.Editor.editbuf:saveToFile(self.src_filename)
end

return pointsvs_editor
