--[[ origin.lua

    A basic representation of a coordinate frame.
]]
origin = {}

origin.__index = origin

function origin.new(...)
    local self = setmetatable({}, origin)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function origin:init()
    self.vbos = {}
    self.vao = 0
    self.prog = 0
end

--local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glUintv  = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local basic_vert = [[
#version 330

in vec4 vPosition;
in vec4 vColor;

out vec3 vfColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    vfColor = vColor.xyz;
    gl_Position = prmtx * mvmtx * vPosition;
}
]]

local basic_frag = [[
#version 330

in vec3 vfColor;
out vec4 fragColor;

void main()
{
    fragColor = vec4(vfColor, 1.0);
}
]]

function origin:init_origin_attributes()
    local verts = glFloatv(3*6, {
        0,0,0,
        .1,0,0,
        0,0,0,
        0,.1,0,
        0,0,0,
        0,0,.1,
        })
    local cols = glFloatv(3*6, {
        0,0,0,
        1,0,0,
        0,0,0,
        0,1,0,
        0,0,0,
        0,0,1,
        })

    local vpos_loc = gl.glGetAttribLocation(self.prog, "vPosition")
    local vcol_loc = gl.glGetAttribLocation(self.prog, "vColor")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, vvbo)

    local cvbo = glIntv(0)
    gl.glGenBuffers(1, cvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(cols), cols, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)
end

function origin:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    self:init_origin_attributes()
    gl.glBindVertexArray(0)
end

function origin:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

function origin:render_for_one_eye(mview, proj)
    local umv_loc = gl.glGetUniformLocation(self.prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog, "prmtx")
    gl.glUseProgram(self.prog)
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    
    --gl.glLineWidth(2)
    local m = {}
    for i=1,16 do m[i] = mview[i] end
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))
    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_LINES, 0, 6*3)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

return origin
