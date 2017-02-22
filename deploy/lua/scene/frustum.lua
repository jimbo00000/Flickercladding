--[[ frustum.lua

    Creates a rectangular pyramid shape for demonstration
    of rendering with camera parameters.
]]
frustum = {}

frustum.__index = frustum

function frustum.new(...)
    local self = setmetatable({}, frustum)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function frustum:init()
    self.vbos = {}
    self.vao = 0
    self.prog = 0
end

local ffi = require("ffi")
local sf = require("util.shaderfunctions")

local glIntv = ffi.typeof('GLint[?]')
local glUintv = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local frustum_vert = [[
#version 310 es

in vec4 vPosition;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    gl_Position = prmtx * mvmtx * vPosition;
}
]]

local frustum_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

out vec4 fragColor;

void main()
{
    fragColor = vec4(vec3(.4), .4);
}
]]

function frustum:init_tri_attributes()
    local z = -2
    local verts = glFloatv(3*3*4, {
        0,0,0,
        -1,1,z,
        1,1,z,

        0,0,0,
        1,1,z,
        1,-1,z,

        0,0,0,
        1,-1,z,
        -1,-1,z,

        0,0,0,
        -1,-1,z,
        -1,1,z,
        })

    local vpos_loc = gl.glGetAttribLocation(self.prog, "vPosition")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, vvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
end

function frustum:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = frustum_vert,
        fsrc = frustum_frag,
        })

    self:init_tri_attributes()
    gl.glBindVertexArray(0)
end

function frustum:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

function frustum:render_for_one_eye(view, proj)
    gl.glEnable(GL.GL_BLEND)
    gl.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA)

    gl.glUseProgram(self.prog)
    local umv_loc = gl.glGetUniformLocation(self.prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog, "prmtx")
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3*4)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)

    gl.glDisable(GL.GL_BLEND)
end

return frustum
