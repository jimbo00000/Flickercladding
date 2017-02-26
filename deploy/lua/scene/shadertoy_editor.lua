-- shadertoy_editor.lua
-- A shadertoy implementation with built-in editor.
-- Takes key and (todo) mouse input, rebuilding shader when changed.

local ffi = require "ffi"
local mm = require "util.matrixmath"
local EditorLibrary = require "scene.stringedit_scene"

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
end

function shadertoy_editor:loadShaderFromDataFile()
    local shfilename = "fragshader.glsl"
    if self.data_dir then shfilename = self.data_dir .. '/' .. shfilename end
    local f = io.open(shfilename, "r")
    if not f then return end
    local content = f:read("*all")
    f:close()

    self.fragsrc = frag_body
    if content then
        self.fragsrc = content
        self.src_filename = shfilename
    end
end

function shadertoy_editor:setDataDirectory(dir)
    self.data_dir = dir

    self:loadShaderFromDataFile()
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

function shadertoy_editor:initQuadAttributes()
    local glIntv   = ffi.typeof('GLint[?]')
    local glUintv  = ffi.typeof('GLuint[?]')
    local glFloatv = ffi.typeof('GLfloat[?]')

    local verts = glFloatv(4*2, {
        -1,-1,
        1,-1,
        1,1,
        -1,1,
        })

    local vpos_loc = gl.glGetAttribLocation(self.prog, "vPosition")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, vvbo)

    gl.glEnableVertexAttribArray(vpos_loc)

    local quads = glUintv(3*2, {
        0,1,2,
        0,2,3,
    })
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.GL_STATIC_DRAW)
    table.insert(self.vbos, qvbo)
end

-- Local copies of functions from shaderutils
-- so we can get back the errors and insert them into the editor.
local function load_and_compile_shader_source(src, type)
    local glIntv = ffi.typeof('GLint[?]')
    local glCharv = ffi.typeof('GLchar[?]')
    local glConstCharpp = ffi.typeof('const GLchar *[1]')

    -- Version replacement for various GL implementations 
    if ffi.os == "OSX" then
        -- MacOS X's inadequate GL support
        src = string.gsub(src, "#version 300 es", "#version 410")
        src = string.gsub(src, "#version 310 es", "#version 410")
    elseif string.match(ffi.string(gl.glGetString(GL.GL_VENDOR)), "ATI") then
        -- AMD's strict standard compliance
        src = string.gsub(src, "#version 300 es", "#version 430")
        src = string.gsub(src, "#version 310 es", "#version 430")
    end
    
    local sourcep = glCharv(#src + 1)
    ffi.copy(sourcep, src)
    local sourcepp = glConstCharpp(sourcep)

    local shaderObject = gl.glCreateShader(type)
    local errorText = nil

    gl.glShaderSource(shaderObject, 1, sourcepp, NULL)
    gl.glCompileShader(shaderObject)

    local ill = glIntv(0)
    gl.glGetShaderiv(shaderObject, GL.GL_INFO_LOG_LENGTH, ill)
    if (ill[0] > 1) then
        local cw = glIntv(0)
        local logp = glCharv(ill[0] + 1)
        gl.glGetShaderInfoLog(shaderObject, ill[0], cw, logp)
        errorText = ffi.string(logp)
        gl.glDeleteShader(shaderObject)
        return 0, errorText
    end

    local success = glIntv(0)
    gl.glGetShaderiv(shaderObject, GL.GL_COMPILE_STATUS, success);
    assert(success[0] == GL.GL_TRUE)

    return shaderObject, errorText
end

local function make_shader_from_source(sources)
    local glIntv = ffi.typeof('GLint[?]')
    local glCharv = ffi.typeof('GLchar[?]')

    local program = gl.glCreateProgram()

    -- Deleted shaders, once attached, will be deleted when program is.
    if type(sources.vsrc) == "string" then
        local vs, err = load_and_compile_shader_source(sources.vsrc, GL.GL_VERTEX_SHADER)
        if err then return 0, err end
        gl.glAttachShader(program, vs)
        gl.glDeleteShader(vs)
    end
    if type(sources.fsrc) == "string" then
        local fs, err = load_and_compile_shader_source(sources.fsrc, GL.GL_FRAGMENT_SHADER)
        if err then return 0, err end
        gl.glAttachShader(program, fs)
        gl.glDeleteShader(fs)
    end

    gl.glLinkProgram(program)

    local ill = glIntv(0)
    gl.glGetProgramiv(program, GL.GL_INFO_LOG_LENGTH, ill)
    if (ill[0] > 1) then
        local cw = glIntv(0)
        local logp = glCharv(ill[0] + 1)
        gl.glGetProgramInfoLog(program, ill[0], cw, logp)
        return 0, ffi.string(logp)
    end

    gl.glUseProgram(0)
    return program
end



-- http://lua-users.org/wiki/SplitJoin
function split_into_lines(str)
    local t = {}
    local function helper(line) table.insert(t, line) return "" end
    helper((str:gsub("(.-)\r?\n", helper)))
    return t
end

-- Catch, parse, and display this error
-- overlaid on the editor's code
function shadertoy_editor:pushErrorMessages(err)
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

function shadertoy_editor:buildShader()
    gl.glDeleteProgram(self.prog)
    self.prog, err = make_shader_from_source({
        vsrc = basic_vert,
        fsrc = frag_header..self.fragsrc,
        })

    if self.Editor then
        self.Editor.error_msgs = {}
    end

    if err then
        self:pushErrorMessages(err)
    end
end

function shadertoy_editor:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self:buildShader()

    self:initQuadAttributes()
    gl.glBindVertexArray(0)
end

function shadertoy_editor:exitGL()
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
        gl.glDrawElements(GL.GL_TRIANGLES, 6, GL.GL_UNSIGNED_INT, nil)
        gl.glBindVertexArray(0)
        gl.glUseProgram(0)
    end

    if self.Editor then
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
end

function shadertoy_editor:timestep(absTime, dt)
    self.time = absTime
end

function shadertoy_editor:resizeViewport(w,h)
    self.win_w, self.win_h = w, h
end

function shadertoy_editor:keypressed(key, scancode, action, mods)
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
                    self:reloadShader()
                    self:saveShader()
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

function shadertoy_editor:reloadShader()
    if not self.Editor then return end

    self.fragsrc = self.Editor.editbuf:saveToString()
    self:buildShader()
    -- TODO: keep an undo stack of working shader,string tuples
end

function shadertoy_editor:saveShader()
    if not self.Editor then return end
    self.Editor.editbuf:savetofile(self.src_filename)
end

return shadertoy_editor
