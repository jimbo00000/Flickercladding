--[[ clockface.lua

    A simple example of animation.

    The time is set in the timestep function and stored in a
    module-scoped variable. This variable is referenced during
    drawing to rotate the three hands of a stopwatch.

    The largest hand ticks once per second and completes a rotation
    after one minute. The middle hand completes one smooth rotation
    per second. The smallest hand rotates 10 times per second.

    This scene can be useful to check that the internal time functions
    are returning values consistent with wall clock time. 
]]
clockface = {}

clockface.__index = clockface

function clockface.new(...)
    local self = setmetatable({}, clockface)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function clockface:init()
    -- Object-internal state: hold a list of VBOs for deletion on exitGL
    self.vbos = {}
    self.vao = 0
    self.prog = 0
    self.absoluteTime = 0 -- Hold time here for drawing
end

--local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glUintv  = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local basic_vert = [[
#version 310 es

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


function clockface:init_tri_attributes()
    local verts = glFloatv(3*3, {
        -.1,0,0,
        .1,0,0,
        0,1,0,
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
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)

    local quads = glUintv(3, {
        0,1,2,
    })
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.GL_STATIC_DRAW)
    table.insert(self.vbos, qvbo)
end

function clockface:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    self:init_tri_attributes()
    gl.glBindVertexArray(0)
end

function clockface:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
    gl.glBindVertexArray(0)
end

function clockface:render_for_one_eye(view, proj)
    local umv_loc = gl.glGetUniformLocation(self.prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog, "prmtx")
    gl.glUseProgram(self.prog)
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    
    local m = {}
    mm.make_identity_matrix(m)
    mm.glh_rotate(m, 360*self.absoluteTime, 0,0,-1)
    mm.pre_multiply(m, view)

    local m10 = {}
    mm.make_identity_matrix(m10)
    mm.glh_translate(m10, 0,0,.02)
    local rotations10 = 10*self.absoluteTime
    mm.glh_rotate(m10, 360*rotations10, 0,0,-1)
    mm.glh_scale(m10, .5,.5,.5)
    mm.pre_multiply(m10, view)

    local m01= {}
    mm.make_identity_matrix(m01)
    mm.glh_translate(m01, 0,0,-.02)
    local rotations01 = .1*self.absoluteTime
    rotations01 = math.floor(rotations01*10)/60
    mm.glh_rotate(m01, 360*rotations01, 0,0,-1)
    mm.glh_scale(m01, 2,2,2)
    mm.pre_multiply(m01, view)

    gl.glBindVertexArray(self.vao)

    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))
    gl.glDrawElements(GL.GL_TRIANGLES, 3, GL.GL_UNSIGNED_INT, nil)
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m10))
    gl.glDrawElements(GL.GL_TRIANGLES, 3, GL.GL_UNSIGNED_INT, nil)
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m01))
    gl.glDrawElements(GL.GL_TRIANGLES, 3, GL.GL_UNSIGNED_INT, nil)

    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end

function clockface:timestep(absTime, dt)
    self.absoluteTime = absTime
end

return clockface
