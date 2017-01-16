--[[ simple_effect.lua

]]

simple_effect = {}

simple_effect.__index = simple_effect

function simple_effect.new(...)
    local self = setmetatable({}, simple_effect)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function simple_effect:init(params)
    self.vbos = {}
    self.vao = 0
    self.time = 0
    self.samplefac = 1
end

function simple_effect:setDataDirectory(dir)
    self.dataDir = dir
end

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")
local spf = require("effect.single_pass_filters")

local glIntv   = ffi.typeof('GLint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

--[[
    Standard vertex shader for quad over NDC [-1,1].
    Outputs texture coordinates in [0,1].
]]
local fullscreen_vert = [[
#version 300 es

in vec4 vPosition;
out vec2 uv;

void main()
{
    uv = .5 * (vPosition.xy + vec2(1.)); // map [-1,1] to [0,1]
    gl_Position = vec4(vPosition.xy, 0., 1.);
}
]]

local fullscreen_frag = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D tex;
in vec2 uv;
out vec4 fragColor;

void main()
{
    fragColor = texture(tex, uv);
}
]]


function simple_effect:make_quad_vbos()
    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    table.insert(self.vbos, vvbo)

    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    local verts = glFloatv(4*2, {
        -1,-1,
        1,-1,
        1,1,
        -1,1,
        })
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
end

function simple_effect:initGL(w,h)
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = fullscreen_vert,
        fsrc = fullscreen_frag,
        })

    self:make_quad_vbos()

    -- Re-use the VBO for each program
    local vpos_loc = gl.glGetAttribLocation(self.prog, "vPosition")
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glEnableVertexAttribArray(vpos_loc)

    self:resize_fbo(w,h)

    gl.glBindVertexArray(0)
end

function simple_effect:exitGL()
    for k,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}

    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

function simple_effect:resize_fbo(w,h)
    if self.fbo then fbf.deallocate_fbo(self.fbo) end
    self.fbo = fbf.allocate_fbo(w*self.samplefac, h*self.samplefac, true)
end

function simple_effect:bind_fbo()
    fbf.bind_fbo(self.fbo)
    gl.glViewport(0,0, self.fbo.w, self.fbo.h)
end

function simple_effect:draw(prog, w, h, srctex)
    gl.glUseProgram(prog)

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, srctex)
    local tx_loc = gl.glGetUniformLocation(prog, "tex")
    gl.glUniform1i(tx_loc, 0)

    -- If these uniforms are not present, we get location -1.
    -- Calling glUniform on that location doesn't hurt, apparently...
    local rx_loc = gl.glGetUniformLocation(prog, "ResolutionX")
    gl.glUniform1i(rx_loc, w)
    local ry_loc = gl.glGetUniformLocation(prog, "ResolutionY")
    gl.glUniform1i(ry_loc, h)

    local t_loc = gl.glGetUniformLocation(prog, "time")
    gl.glUniform1f(t_loc, self.time)

    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function simple_effect:unbind_fbo()
    fbf.unbind_fbo()
end

function simple_effect:present()
    gl.glDisable(GL.GL_DEPTH_TEST)
    -- Display last effect's output to screen(bind fbo 0)
    local f = self.fbo
    self:draw(self.prog, f.w, f.h, f.tex)
end

function simple_effect:timestep(absTime, dt)
    self.time = absTime
end

return simple_effect
